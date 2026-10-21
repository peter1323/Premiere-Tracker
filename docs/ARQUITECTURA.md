# Arquitectura de Premiere Tracker

Guía para entender el código. Está pensada para alguien que abre el proyecto
por primera vez: explica cómo se organiza, qué hace cada carpeta y cómo fluyen
los datos. Los comentarios del propio código van en español y profundizan en
cada pieza; aquí se da la visión general.

---

## 1. ¿Qué hace la app?

Aplicación de escritorio (Flutter/Windows) para llevar el seguimiento de
**series, películas y lectura de mangas/manhwas/novelas**:

- **Buscar** títulos en varias bases de datos y ver su ficha.
- **Favoritos** y **Vistos** (leídos, en el caso de los mangas).
- **Calendario** de estrenos (solo series y películas; nunca mangas).
- **Notas** personales (dónde te quedaste, datos sueltos).
- **Usuarios locales** con PIN, tema (claro/oscuro) e idioma (español/inglés).
- **Copia de seguridad**: exportar/importar todo a un `.json`.

Todo se guarda en el propio equipo (sin servidor ni base de datos externa).

---

## 2. Patrón MVC

El código sigue un MVC estricto. La regla es: **la vista no toca la lógica ni
los datos; solo dibuja y delega en su controlador.**

```
lib/
├── main.dart               → Vista raíz: arranque, tema, idioma y estructura
├── l10n/app_strings.dart   → Todos los textos por idioma (es/en)
├── models/                 → MODELO: qué datos guardamos (sin lógica de red)
├── services/               → SERVICIO: hablar con las APIs y con el disco
├── controllers/            → CONTROLADOR: la lógica de cada pantalla
└── views/                  → VISTA: la interfaz (widgets + dibujo)
    └── widgets/            → Widgets reutilizables compartidos entre vistas
```

### Los tres roles

| Capa | Carpeta | Responsabilidad | Ejemplo |
|------|---------|-----------------|---------|
| **Modelo** | `models/` | Representar los datos. Solo campos y conversiones JSON↔objeto. | `SerieModel`, `MangaModel`, `FavoritoModel` |
| **Servicio** | `services/` | Obtener datos: llamadas HTTP a APIs, leer/guardar en disco, caché, límites de peticiones. **Nunca dibuja.** | `TmdbService`, `ClaveService`, `AnilistService`, `AlmacenamientoService`, `AvisosService` (avisos de Android), `EnlaceService` (abrir enlaces) |
| **Controlador** | `controllers/` | La lógica de una pantalla: pedir datos al servicio, guardar el estado y avisar a la vista con `notifyListeners()`. **Nunca dibuja.** | `DetalleController`, `AppController` |
| **Vista** | `views/` | Dibuja la interfaz y reacciona a los cambios del controlador. **Nunca hace llamadas de red.** | `DetalleView`, `FavoritosView` |

---

## 3. Cómo fluyen los datos (el paquete `provider`)

La app usa `provider` para conectar vistas y controladores. Un controlador es
un `ChangeNotifier`: guarda el estado y, cuando cambia, llama a
`notifyListeners()` y **todas las vistas que lo escuchan se redibujan solas**.

Flujo típico de una pantalla:

```
Vista (p. ej. DetalleView)
   │  1. pide datos:  control.cargar()
   ▼
Controlador (DetalleController)
   │  2. consulta el servicio:  TmdbService.obtenerSerie(...)
   ▼
Servicio (TmdbService)  ──HTTP──►  API externa (TMDB)
   │  3. devuelve un Modelo (SerieModel)
   ▼
Controlador guarda el estado y llama a notifyListeners()
   │
   ▼
Vista se redibuja con los datos nuevos
```

Hay dos tipos de controladores según su duración:

- **Globales** (creados en `main.dart`, duran toda la sesión):
  `AppController` (usuario actual, tema, idioma, favoritos) y
  `UsuariosController` (lista de usuarios y validación del PIN).
- **De pantalla** (creados con `ChangeNotifierProvider(create: ...)` en cada
  vista): `DetalleController`, `PersonaController`, `MangaDetalleController`,
  `AjustesController`, `InicioController`, etc. Se destruyen al cerrar su
  pantalla (por eso sus métodos async comprueban `_destruido` antes de avisar).

> **Importante:** `main.dart` envuelve las 7 pantallas en un `IndexedStack`,
> así que esas vistas y sus controladores **no se destruyen** al cambiar de
> sección (se conserva el estado). En cambio, las fichas que se abren con
> `Navigator.push` (serie, película, persona, manga) **sí se destruyen** al
> volver atrás.

---

## 4. Las 7 pantallas

| Índice | Sección | Vista | Controlador | Qué hace |
|--------|---------|-------|-------------|----------|
| 0 | Inicio | `inicio_view` | `inicio_controller` | Buscador general (TMDB + TVMaze + AniList). |
| 1 | Lectura | `mangas_view` | `mangas_controller` | Busca mangas/manhwas/novelas (AniList). |
| 2 | Calendario | `calendario_view` | `calendario_controller` | Estrenos por día/semana/mes (solo series y películas). |
| 3 | Favoritos | `lista_guardada_view` | `lista_guardada_controller` | Lo guardado, con filtro Todo/Series/Películas/Manga/Novelas. |
| 4 | Vistos | `lista_guardada_view` | `lista_guardada_controller` | Lo ya visto/leído, con los mismos filtros. |
| 5 | Notas | `notas_view` | `notas_controller` | Notas personales. |
| 6 | Ajustes | `ajustes_view` | `ajustes_controller` | Idioma, tema, copia de seguridad, gestión de usuarios. |

Antes de entrar a la app está la **pantalla de usuarios** (`usuarios_view` +
`usuarios_controller`), donde se elige usuario y se valida el PIN.

---

## 5. De dónde vienen los datos (las APIs)

Cada tipo de contenido usa su fuente. **AniList y MangaDex son públicas y no
necesitan clave; TMDB sí necesita una clave (guardada en la app
desde la pantalla de usuarios); TVMaze no.**

| Fuente | Para qué | ¿Clave? |
|--------|----------|---------|
| **TMDB** (`tmdb_service`) | Series, películas, personas, reparto, episodios. Fuente principal. | Sí, guardada en la app (`clave_service`) |
| **TVMaze** (`tvmaze_service`) | Series alternativas (en inglés) y episodios. Tiene límite de peticiones. | No |
| **AniList** (`anilist_service`) | Mangas, manhwas, manhuas y novelas (GraphQL). | No |
| **MangaDex** (`mangadex_service`) | Último capítulo por idioma y sinopsis en español de los mangas. | No |

Dos servicios auxiliares componen los anteriores:

- **`busqueda_service`**: orquesta TMDB + TVMaze a la vez (en paralelo y
  anti-fallos: si una falla, la otra sigue).
- **`almacenamiento_service`**: lee/graba los usuarios y sus datos en el equipo.
- **`copia_seguridad_service`**: exporta/importa favoritos, vistos y notas a un
  `.json` (funciona sobre cualquier lista, por eso los mangas se exportan sin
  cambios).

### Detalles que conviene saber

- **Timeouts**: toda petición HTTP tiene un `timeout` de 10 s para no colgar la
  app si no hay internet.
- **Caché**: TVMaze, AniList y MangaDex guardan resultados en memoria para no
  repetir peticiones.
- **Límites de peticiones**: TVMaze (20 cada 10 s) y MangaDex (4 por segundo)
  respetan su cuota con un control de ventana; se espera si hace falta.
- **La clave de TMDB la escribe cada usuario en la app** (pantalla de
  usuarios) y se guarda en el dispositivo; nunca va en el código ni se
  muestra completa. Si falta, la app arranca igualmente y muestra un aviso.

---

## 6. Dónde se guardan los datos

No hay servidor: todo vive en el equipo mediante `shared_preferences`
(almacenamiento clave-valor del sistema operativo). Bajo la clave `usuarios`
se guarda un JSON con todos los usuarios y, dentro de cada uno, sus favoritos,
vistos y notas.

- `almacenamiento_service.dart` escribe y lee ese JSON (con cola de escrituras
  para no pisarse).
- `usuario_model.dart` sabe convertir ese JSON ↔ objeto.
- La **copia de seguridad** es un `.json` aparte que el usuario elige exportar
  a un archivo y puede importar en otro equipo.

---

## 7. Tema e idioma

- **Tema** (claro/oscuro): lo decide cada usuario; se guarda por usuario. Antes
  de entrar (pantalla de usuarios) se aplica el último tema usado (tema global).
- **Idioma** (español/inglés): cada usuario tiene el suyo.
- Todos los textos pasan por `t('clave', idioma)` de `app_strings.dart`. **Nunca**
  se escribe texto suelto en las vistas: si quieres añadir un texto, va como
  clave en `app_strings.dart` (en ambas secciones, `es` y `en`).

---

## 8. Cómo añadir una funcionalidad nueva (ejemplo: una pantalla)

1. **Modelo** (si hace falta guardar datos nuevos): crea o amplía un archivo en
   `models/`. Solo campos y `fromJson`/`toJson`.
2. **Servicio** (si vienen de una API): crea/amplía un archivo en `services/`
   con `http`, `timeout` y, si aplica, caché. Devuelve modelos.
3. **Controlador**: crea un `ChangeNotifier` en `controllers/` con la lógica y
   `notifyListeners()`. Si es de pantalla y tiene `await`, comprueba
   `if (_destruido) return;` antes de avisar.
4. **Vista**: crea el widget en `views/`, con `ChangeNotifierProvider(create: ...)`
   que cree su controlador. La vista solo dibuja y llama a métodos del controlador.
5. **Textos**: añade las claves nuevas a `app_strings.dart` (es y en).
6. **Menú**: si es una sección nueva, añádela a `menu_lateral.dart` y al
   `IndexedStack` de `main.dart`.

### Convenciones del proyecto

- Comentarios y resúmenes **en español** y breves.
- Textos de usuario **solo** en `app_strings.dart` (nada hardcodeado en vistas).
- La clave de TMDB nunca en el código: la guarda cada usuario en la app.
- El **calendario es solo para series y películas** (no se toca para mangas).
- Forma de verificar que todo va bien:
  `flutter analyze; if ($?) { flutter test }; if ($?) { flutter test integration_test/recorrido_app_test.dart -d windows }`
  (debe terminar sin errores).

---

## 9. Escape y navegación

La tecla **Escape funciona como «volver atrás»** en toda la app: cierra la ficha
o el diálogo abierto. Está implementada en `main.dart` con `_EscapeParaVolver`,
que escucha Escape a nivel de `MaterialApp` y hace `maybePop()` al navigator
(raíz guardado en `_claveNavegador`). Si el foco está en un campo de texto, se
ignora para no perder lo que se escribe.

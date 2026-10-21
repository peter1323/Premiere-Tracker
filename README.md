<p align="center">
  <img src="assets/icon/premiere_tracker_icon.png" width="128" alt="Icono de Premiere Tracker">
</p>

<h1 align="center">Premiere Tracker</h1>

Aplicación multiplataforma para Windows y Android desarrollada con Flutter y Dart en Android Studio. Sirve para buscar películas, series y personas, ver cuándo se estrenan las películas y cuándo salen las temporadas y los episodios de las series (incluidas las que emiten semana a semana), buscar mangas, manhwas, manhuas y novelas con su ficha y sus últimos capítulos, y llevar un seguimiento personal: favoritos, vistos/leídos y notas de dónde se dejó cada cosa.

## Funcionalidades

- **Usuarios locales con PIN**: cada usuario tiene su propio perfil con un PIN de 4 dígitos cifrado con SHA-256 (nunca en texto plano) y sus propios favoritos, vistos, notas, tema e idioma. Se entra automáticamente al escribir los 4 dígitos; si el PIN está mal se avisa y se limpia el campo, y **tras dos fallos aparece una pista con los dos primeros dígitos**. Desde el propio diálogo de acceso también se puede **cambiar el PIN** (validando antes el actual). El tema elegido se recuerda también en la pantalla de usuarios.
- **Clave TMDB configurable**: la clave de TMDB se introduce desde la propia app (pantalla de usuarios → «Clave TMDB», con botón para obtenerla) y se guarda en el dispositivo; por eso las versiones compiladas (`.exe` y APK) **no llevan ninguna clave embebida** y cada persona usa la suya.
- **Búsqueda global anti-fallos**: una sola caja busca **series, películas y personas a la vez** (en paralelo, con tiempos de espera de 10 s). Si una API falla, la otra sigue funcionando y se muestra un aviso claro; si fallan las dos, se avisa de "Sin conexión o servicios no disponibles". Los resultados aparecen en tarjetas con botones de favorito ❤️ y visto 👁️.
- **Próximamente**: en Inicio, mientras no se busca nada, aparecen los estrenos de tus favoritos de hoy a 6 días vista (episodios y películas), y al pulsarlos se abre su ficha.
- **Avisos de estreno (Android)**: notificación del móvil a las 10:00 del día de cada estreno de tus favoritos ("Hoy se estrena · T1E4 · …"), aunque la app esté cerrada. Se reprograman al abrir la app.
- **Selector de fuente TMDB | TVMaze**: en las series se puede cambiar entre las dos fuentes; se enlazan entre sí mediante el ID de IMDb. Si una fuente no está disponible, su opción queda desactivada.
- **Detalle de series y películas**: póster, sinopsis, estado (en emisión, finalizada, cancelada...), fecha de estreno, géneros, puntuación, temporadas desplegables con sus episodios (número, título y fecha), el próximo episodio destacado, **dónde verlo** en España (plataformas de streaming con su logo; datos de JustWatch vía TMDB) y el **reparto con cada actor pulsable** (abre su ficha). Incluye los botones "Añadir a favoritos" y "Añadir a vistos".
- **Fichas de persona**: foto, biografía y créditos (series y películas en las que ha participado), con enlaces a las webs de las APIs.
- **Lectura (mangas, manhwas, manhuas y novelas)**: buscador sobre AniList con dos pestañas — **Manga / Manhwa / Manhua** y **Novelas** — lanzando las dos búsquedas en paralelo con una sola escritura. La ficha incluye portada, estado (con capítulos y tomos marcados como «?» si aún no hay total), puntuación, formato, país, fecha de inicio, **autores**, géneros, **sinopsis en español** cuando MangaDex la tiene (si no, la de AniList) y el **último capítulo publicado por idioma** (español de España, español latino e inglés) consultado a MangaDex con límite de peticiones y caché. Tiene botones de **favorito** y **marcar como leído**; los mangas guardados se abren desde Favoritos/Vistos recargando la ficha completa desde AniList.
- **Calendario** con cuatro vistas y pestañas Series / Películas:
  - **Día** y **Semana**: flechas para cambiar de periodo y botón morado "Hoy". En Windows, rejilla por horas; en Android, lista de estrenos por día (con su hora), más legible en vertical y en horizontal.
  - **Mes**: rejilla con los estrenos de cada día, y selector de mes y año (de 2 años atrás a 6 años adelante).
  - **Año**: rejilla de los 12 meses con el número de estrenos de cada uno; al pulsar un mes se abre su vista Mes.
  - Los datos se cargan solo del periodo visible, respetando el límite de peticiones de TVMaze (20 cada 10 segundos, con caché en memoria).
- **Favoritos**: lista con buscador por nombre y filtro Todo / Series / Películas / Manga / Manhwa / Manhua / Novelas.
- **Vistos**: misma búsqueda y filtro que favoritos, con el botón 👁️ para apuntar qué ya has visto (para los mangas se usa como **leídos**).
- **Notas**: tabla de tres columnas (**Título | Última vista | Más datos**) para recordar dónde se dejó cada serie o película; solo el título es obligatorio, con buscador, edición y borrado; las notas recientes aparecen primero.
- **Ajustes**: idioma (español / inglés), tema (claro / oscuro), copia de seguridad (exportar e importar **favoritos, vistos y notas** a un `.json` —incluidos los mangas y novelas guardados—, compatible con copias antiguas que solo tenían favoritos), gestión de usuarios (cambiar nombre, cambiar PIN y borrar usuario) y créditos.
- **Interfaz**: navegación lateral fija en Windows e inferior en móvil (Inicio, Lectura, Calendario, Favoritos, Vistos, Notas y Ajustes), barra superior con interruptor de tema y menú de usuario, diseño Material 3 con tema claro y oscuro adaptable al redimensionar (vertical y horizontal), y en Windows la ventana **arranca maximizada**.

## Tecnologías

- **Flutter / Dart** (Windows y Android)
- **provider** – estado global (MVC con `ChangeNotifier`)
- **http** – peticiones a las APIs
- **shared_preferences** – almacenamiento local en formato JSON
- **crypto** – cifrado SHA-256 de los PIN
- **file_picker** – exportar / importar copias de seguridad
- **url_launcher** – enlaces a las webs de las APIs y a "dónde verlo"
- **flutter_local_notifications** + **timezone** – avisos de estreno en Android
- **calendar_view** (fijado a 2.0.0) – vistas de Día y Semana del calendario (Mes y Año son personalizadas)

## APIs usadas

- **TMDB** (https://api.themoviedb.org/3): películas, series y personas. Requiere API key.
- **TVMaze** (https://api.tvmaze.com): solo series, sin API key. Límite de unas 20 peticiones cada 10 segundos; la app respeta ese límite y guarda resultados en caché.
- **AniList** (https://graphql.anilist.co): mangas, manhwas, manhuas y novelas, sin API key.
- **MangaDex** (https://api.mangadex.org): últimos capítulos por idioma y sinopsis en español, sin API key. Límite de 5 peticiones por segundo; la app lo respeta y guarda resultados en caché.

## Arquitectura (MVC)

La app sigue el patrón Modelo-Vista-Controlador:

```
lib/
  main.dart            → Punto de entrada y temas
  l10n/                → Textos por idioma (español e inglés)
  models/              → Clases de datos con fromJson y toJson
  services/            → Conexión con APIs, almacenamiento local y copia de seguridad
  controllers/         → Lógica de cada pantalla (ChangeNotifier + provider)
  views/               → Pantallas (solo muestran datos y llaman al controlador)
    widgets/           → Widgets reutilizables sin lógica propia
assets/images/         → Logo de TMDB y demás imágenes
assets/icon/           → Icono de la app (para este README)
```

Cada vista tiene su controlador con el mismo nombre (`usuarios_view.dart` ↔ `usuarios_controller.dart`, etc.), más el `app_controller.dart` para el estado global (usuario actual, tema, idioma, favoritos, vistos y notas).

## Cómo ejecutarlo

1. **Consigue tu API key de TMDB** (gratis):
   - Crea una cuenta en https://www.themoviedb.org/
   - Ve a *Settings → API* y solicita una clave (tipo "Developer").
2. **Instala las dependencias**:
   ```bash
   flutter pub get
   ```
3. **Ejecuta la app**:
   ```bash
   flutter run -d windows
   ```
   (En Android, con el móvil conectado: `flutter run -d android`.)
4. **Introduce tu clave TMDB en la app**: en la pantalla de usuarios, sección «Clave TMDB» (hay un botón para obtenerla si aún no la tienes). Se guarda en el dispositivo y ya no hace falta configurar nada más.

   > Nota: para compilar en Windows puede ser necesario activar el *Modo de desarrollador* de Windows (*Configuración → Sistema → Para programadores*).

Si la API key falta o es incorrecta, la app muestra un aviso claro en lugar de cerrarse.

## Cómo compilar el .exe

```bash
flutter clean
flutter pub get
flutter build windows --release
```

El ejecutable se genera en:

```
build\windows\x64\runner\Release\premiere_tracker.exe
```

(El nombre visible de la ventana, «Premiere Tracker», se cambia en `windows/runner/main.cpp`; no se debe renombrar el `.exe` con `OUTPUT_NAME` en CMake, porque `flutter run` y el botón ▶ de Android Studio buscan `premiere_tracker.exe`.)

Para usar la app en otro ordenador hay que copiar la **carpeta completa `Release`** (el `.exe`, los archivos `.dll` y la carpeta `data`), no solo el `.exe`.

## Cómo compilar el APK (Android)

```bash
flutter clean
flutter pub get
flutter build apk --release
```

El APK se genera en:

```
build\app\outputs\apk\release\Premiere-Tracker.apk
```

Se instala en el móvil copiando el archivo o con `flutter install`. **El APK no lleva ninguna clave TMDB embebida**: cada persona que lo instale debe introducir su propia clave en la app (pantalla de usuarios → «Clave TMDB»).

## Icono de la app

En Windows, el icono (exe y barra de títulos) sale de `windows/runner/resources/app_icon.ico`. Para cambiarlo, sustituye ese archivo por un `.ico` multiresolución (16–256 px) y vuelve a compilar. En Android, el icono se genera con flutter_launcher_icons a partir de `tool/app_icon_256.png`. Si el Explorador de Windows se queda con el icono antiguo, refresca su caché con:

```bash
ie4uinit -show
```

## Créditos

- Este producto usa la API de TMDB pero no está respaldado ni certificado por TMDB.
- Datos de series proporcionados por [TVMaze](https://www.tvmaze.com).
- Datos de mangas, manhwas, manhuas y novelas proporcionados por [AniList](https://anilist.co) y [MangaDex](https://mangadex.org).

## Licencia

Copyright (c) 2026 peter1323. Todos los derechos reservados.

Este código es público solo para consulta. No está permitido copiarlo, modificarlo, distribuirlo ni usarlo en proyectos propios, ya sea total o parcialmente, sin permiso expreso del autor.

Consulta el archivo [LICENSE](LICENSE).

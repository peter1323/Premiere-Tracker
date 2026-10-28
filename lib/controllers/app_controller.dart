// CONTROLADOR GLOBAL: el estado de toda la app. Se crea una sola vez en
// main.dart y vive mientras la app está abierta. Guarda el usuario actual,
// su tema, su idioma y sus listas (favoritos, vistos, notas), y las guarda
// en el equipo con AlmacenamientoService. Todas las pantallas lo escuchan
// con context.watch<AppController>() para reaccionar a cambios de usuario,
// tema o idioma.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/favorito_model.dart';
import '../models/manga_model.dart';
import '../models/nota_model.dart';
import '../models/pelicula_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
import '../models/usuario_model.dart';
import '../services/almacenamiento_service.dart';
import '../services/anilist_service.dart';
import '../services/tmdb_service.dart';
import '../services/tvmaze_service.dart';

/// Estado global de la app: usuario actual, tema, idioma y favoritos.
class AppController extends ChangeNotifier {
  UsuarioModel? _usuarioActual;

  UsuarioModel? get usuarioActual => _usuarioActual;

  /// true cuando hay un usuario dentro (ha validado su PIN).
  bool get hayUsuario => _usuarioActual != null;

  /// Idioma actual ('es' o 'en').
  String get idioma => _usuarioActual?.idioma ?? 'es';

  /// Tema actual (claro u oscuro). Sin sesión se usa el tema global
  /// (el último que se usó), para que la pantalla de usuarios también
  /// respete el modo oscuro.
  ThemeMode get modoTema => (_usuarioActual?.tema ?? _temaGlobal) == 'oscuro'
      ? ThemeMode.dark
      : ThemeMode.light;

  bool get esOscuro => modoTema == ThemeMode.dark;

  String get nombreUsuario => _usuarioActual?.nombre ?? '';

  // Último tema usado: se aplica en la pantalla de usuarios (sin sesión).
  String _temaGlobal = 'oscuro'; // oscuro por defecto al instalar

  /// Carga el tema global guardado al arrancar (pantalla de usuarios).
  Future<void> cargarTemaInicial() async {
    try {
      final tema = await AlmacenamientoService.cargarTemaGlobal();
      _temaGlobal = tema;
      if (_usuarioActual == null) notifyListeners();
    } catch (e) {
      // Sin preferencias disponibles: se mantiene el tema oscuro por defecto
      debugPrint('Error cargando tema global: $e');
    }
  }

  /// Inicial del usuario para el círculo de la barra superior.
  String get inicial {
    final nombre = nombreUsuario.trim();
    return nombre.isEmpty ? '?' : nombre[0].toUpperCase();
  }

  List<FavoritoModel> get favoritos => _usuarioActual?.favoritos ?? const [];

  /// Series y películas marcadas como vistas por el usuario actual.
  List<FavoritoModel> get vistos => _usuarioActual?.vistos ?? const [];

  /// Notas personales del usuario actual (dónde lo dejó visto...).
  List<NotaModel> get notas => _usuarioActual?.notas ?? const [];

  /// Entra con el usuario que ya ha validado su PIN.
  void establecerUsuario(UsuarioModel usuario) {
    _usuarioActual = usuario;
    _temaGlobal = usuario.tema; // la pantalla de usuarios sigue su tema
    notifyListeners();
  }

  /// Sale del usuario y vuelve a la pantalla de usuarios.
  void cerrarSesion() {
    _usuarioActual = null;
    notifyListeners();
  }

  /// Cierra la aplicación. En escritorio termina el proceso; en móvil
  /// (Android/iOS) no se debe matar el proceso, así que se pide al
  /// sistema que cierre la app (Apple rechaza las apps que se cierran
  /// solas con exit()).
  void cerrarAplicacion() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop(); // comportamiento correcto en móvil
    } else {
      exit(0); // cierra el proceso de la app (Windows/Linux)
    }
  }

  /// Alterna entre modo claro y oscuro.
  Future<void> cambiarTema() => cambiarTemaA(esOscuro ? 'claro' : 'oscuro');

  /// Cambia el tema a un valor concreto ('claro' u 'oscuro').
  Future<void> cambiarTemaA(String tema) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    _usuarioActual = usuario.copyWith(tema: tema);
    await _persistir();
    // También como tema global: al cerrar sesión o arrancar, la
    // pantalla de usuarios se queda en el último modo usado.
    _temaGlobal = tema;
    await AlmacenamientoService.guardarTemaGlobal(tema);
  }

  /// ¿Están activadas las notificaciones de estreno? (por defecto, sí)
  bool get avisosActivados => _usuarioActual?.avisos ?? true;

  /// Activa o desactiva las notificaciones de estreno (Ajustes).
  Future<void> cambiarAvisos(bool activados) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    _usuarioActual = usuario.copyWith(avisos: activados);
    await _persistir();
  }

  /// Cambia el idioma ('es' o 'en').
  Future<void> cambiarIdioma(String idioma) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    _usuarioActual = usuario.copyWith(idioma: idioma);
    await _persistir();
  }

  /// Título normalizado para comparar aunque la obra venga de otra
  /// fuente (TMDB y TVMaze dan ids distintos a la misma serie).
  static String _tituloNormalizado(String titulo) =>
      titulo.trim().toLowerCase();

  /// Posición de la obra en la lista (-1 si no está). Primero por id
  /// exacto y, si no, por título+tipo: la misma obra agregada desde TMDB
  /// y TVMaze tiene ids distintos en cada fuente.
  static int _indice(
    List<FavoritoModel> lista,
    String fuente,
    String tipo,
    int id,
    String? titulo,
  ) {
    final i = lista.indexWhere(
      (f) => f.fuente == fuente && f.tipo == tipo && f.id == id,
    );
    if (i >= 0 || titulo == null || titulo.isEmpty) return i;
    final normalizado = _tituloNormalizado(titulo);
    return lista.indexWhere(
      (f) => f.tipo == tipo && _tituloNormalizado(f.titulo) == normalizado,
    );
  }

  /// La entrada guardada de [item] en [lista], o null si no está.
  static FavoritoModel? _encontrar(
    List<FavoritoModel> lista,
    FavoritoModel item,
  ) {
    final i = _indice(lista, item.fuente, item.tipo, item.id, item.titulo);
    return i < 0 ? null : lista[i];
  }

  /// ¿Está la obra en la lista?
  static bool _contiene(
    List<FavoritoModel> lista,
    String fuente,
    String tipo,
    int id,
    String? titulo,
  ) => _indice(lista, fuente, tipo, id, titulo) >= 0;

  /// Añade la obra si no está; la quita si ya estaba (también si estaba
  /// desde la otra fuente, en lugar de crear una entrada duplicada).
  static List<FavoritoModel> _alternar(
    List<FavoritoModel> lista,
    FavoritoModel item,
  ) {
    final nuevaLista = List<FavoritoModel>.from(lista);
    final i = _indice(nuevaLista, item.fuente, item.tipo, item.id, item.titulo);
    if (i >= 0) {
      nuevaLista.removeAt(i);
    } else {
      nuevaLista.add(item);
    }
    return nuevaLista;
  }

  /// Título original para guardar: null si la fuente no lo da (TVMaze;
  /// completarDatos lo busca en TMDB) y '' si es igual que el título.
  static String? _original(String original, String titulo) =>
      original.isEmpty ? null : TmdbRefs.originalDistinto(original, titulo);

  static FavoritoModel _deSerie(SerieModel serie) => FavoritoModel(
    tipo: 'serie',
    fuente: serie.fuente,
    id: serie.id,
    imdbId: serie.imdbId,
    titulo: serie.titulo,
    tituloOriginal: _original(serie.tituloOriginal, serie.titulo),
    anio: serie.anio,
    posterUrl: serie.posterUrl,
    fechaEstreno: serie.fechaEstreno,
    estado: FavoritoModel.estadoDeApi(serie.estado),
  );

  static FavoritoModel _dePelicula(PeliculaModel pelicula) => FavoritoModel(
    tipo: 'pelicula',
    fuente: 'tmdb',
    id: pelicula.id,
    titulo: pelicula.titulo,
    tituloOriginal: _original(pelicula.tituloOriginal, pelicula.titulo),
    anio: pelicula.anio,
    posterUrl: pelicula.posterUrl,
    fechaEstreno: pelicula.fechaEstreno,
    estado: FavoritoModel.estadoDeApi(pelicula.estado),
  );

  /// Convierte un manga de AniList en el favorito genérico que guarda la
  /// app: fuente 'anilist' y tipo 'manga' o 'novela' según su formato.
  static FavoritoModel _deManga(MangaModel manga) => FavoritoModel(
    tipo: manga.formato == 'NOVEL' ? 'novela' : 'manga',
    fuente: 'anilist',
    id: manga.id,
    titulo: manga.titulo,
    anio: manga.fechaInicio.length >= 4
        ? int.tryParse(manga.fechaInicio.substring(0, 4))
        : null,
    posterUrl: manga.portada.isEmpty ? null : manga.portada,
    fechaEstreno: manga.fechaInicio,
    estado: FavoritoModel.estadoDeApi(manga.estado),
  );

  /// Persona (actriz, actor...) como favorito: lo mínimo para pintar la
  /// lista sin llamadas a la API (nombre y foto); la ficha se recarga.
  static FavoritoModel _dePersona(PersonaModel persona) => FavoritoModel(
    tipo: 'persona',
    fuente: persona.fuente,
    id: persona.id,
    titulo: persona.nombre,
    posterUrl: persona.fotoUrl,
  );

  /// Aplica un cambio a la lista de favoritos o de vistos y lo guarda.
  Future<void> _cambiarLista(
    bool vistos,
    List<FavoritoModel> Function(List<FavoritoModel>) cambio,
  ) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    _usuarioActual = vistos
        ? usuario.copyWith(vistos: cambio(usuario.vistos))
        : usuario.copyWith(favoritos: cambio(usuario.favoritos));
    await _persistir();
  }

  // ===== Favoritos =====

  /// ¿Está esta obra en favoritos del usuario actual?
  bool esFavorito(String fuente, String tipo, int id, {String? titulo}) =>
      _contiene(favoritos, fuente, tipo, id, titulo);

  Future<void> alternarFavoritoDeSerie(SerieModel serie) =>
      alternarFavorito(_deSerie(serie));

  Future<void> alternarFavoritoDePelicula(PeliculaModel pelicula) =>
      alternarFavorito(_dePelicula(pelicula));

  Future<void> alternarFavoritoDeManga(MangaModel manga) =>
      alternarFavorito(_deManga(manga));

  Future<void> alternarFavoritoDePersona(PersonaModel persona) =>
      alternarFavorito(_dePersona(persona));

  /// Añade el favorito si no existe; lo quita si ya estaba.
  Future<void> alternarFavorito(FavoritoModel favorito) => _cambiarLista(
    false,
    (l) => _alternar(l, _conValoracionDe(vistos, favorito)),
  );

  /// Quita un favorito por su identificador único ('fuente-tipo-id').
  Future<void> quitarFavorito(String idUnico) => _cambiarLista(
    false,
    (l) => l.where((f) => f.idUnico != idUnico).toList(),
  );

  // ===== Vistos (marcados como vistos, o leídos en los mangas) =====

  /// ¿Está esta obra marcada como vista?
  bool esVisto(String fuente, String tipo, int id, {String? titulo}) =>
      _contiene(vistos, fuente, tipo, id, titulo);

  Future<void> alternarVistoDeSerie(SerieModel serie) =>
      alternarVisto(_deSerie(serie));

  Future<void> alternarVistoDePelicula(PeliculaModel pelicula) =>
      alternarVisto(_dePelicula(pelicula));

  Future<void> alternarVistoDeManga(MangaModel manga) =>
      alternarVisto(_deManga(manga));

  /// Marca como vista si no lo estaba; la quita de vistos si ya lo era.
  Future<void> alternarVisto(FavoritoModel visto) => _cambiarLista(
    true,
    (l) => _alternar(l, _conValoracionDe(favoritos, visto)),
  );

  /// Quita un visto por su identificador único ('fuente-tipo-id').
  Future<void> quitarVisto(String idUnico) =>
      _cambiarLista(true, (l) => l.where((v) => v.idUnico != idUnico).toList());

  // ===== Estado (de la base de datos) y nota personal =====

  /// La entrada guardada de esta obra (en Favoritos o, si no, en Vistos),
  /// con su estado y nota; null si no está guardada.
  FavoritoModel? guardado(String fuente, String tipo, int id, String titulo) {
    final item = FavoritoModel(
      tipo: tipo,
      fuente: fuente,
      id: id,
      titulo: titulo,
    );
    return _encontrar(favoritos, item) ?? _encontrar(vistos, item);
  }

  /// Cambia la nota personal de [item] (null = sin puntuar) en las dos
  /// listas donde esté guardado, para que Favoritos y Vistos coincidan.
  Future<void> cambiarNota(FavoritoModel item, int? nota) => _cambiarGuardados(
    (f) => _encontrar([f], item) == null
        ? f
        : f.conValoracion(estado: f.estado, puntuacion: nota),
  );

  /// Apunta los datos que da la base de datos para [item] al abrir su
  /// ficha: el estado y la fecha de estreno (null = no cambiar). No guarda
  /// nada si no ha cambiado.
  Future<void> actualizarDesdeFicha(
    FavoritoModel item, {
    String? estado,
    String? fechaEstreno,
  }) => _cambiarGuardados(
    (f) => _encontrar([f], item) == null
        ? f
        : f.conValoracion(
            estado: estado ?? f.estado,
            puntuacion: f.puntuacion,
            fechaEstreno: fechaEstreno,
          ),
  );

  // Obras ya consultadas en esta sesión (no se repiten)
  final Set<String> _consultadas = {};

  /// Completa en segundo plano, una vez por sesión: el estado de lo
  /// guardado sin estado (lo añadido desde la búsqueda no lo trae) y la
  /// fecha de estreno de las películas (antes se guardaba la del primer
  /// país del mundo, no la de España) y el título original de lo que no lo
  /// tenga (para el Calendario). Se guarda una sola vez al final.
  // shortcut: el estado de series y mangas ya apuntado solo se refresca al
  // abrir la ficha; si hiciera falta al día sin abrirla, consultarlo aquí.
  Future<void> completarDatos() async {
    final porConsultar = [
      for (final f in [...favoritos, ...vistos])
        if ((f.estado == null && f.tipo != 'persona' ||
                f.tipo == 'pelicula' ||
                f.tituloOriginal == null && _tituloEnTmdb(f)) &&
            _consultadas.add(f.idUnico))
          f,
    ];
    if (porConsultar.isEmpty) return;
    final datos = await Future.wait(porConsultar.map(_consultarDatos));
    final nuevos = {
      for (var i = 0; i < porConsultar.length; i++)
        if (datos[i] != null) porConsultar[i].idUnico: datos[i]!,
    };
    await _cambiarGuardados((f) {
      final d = nuevos[f.idUnico];
      return d == null
          ? f
          : f.conValoracion(
              estado: d.estado ?? f.estado,
              puntuacion: f.puntuacion,
              fechaEstreno: d.fecha,
              tituloOriginal: d.original,
            );
    });
  }

  /// ¿Se puede pedir a TMDB el título original de [f]? (series y películas
  /// de TMDB; TVMaze no lo da)
  static bool _tituloEnTmdb(FavoritoModel f) =>
      f.fuente == 'tmdb' && (f.tipo == 'serie' || f.tipo == 'pelicula');

  /// Estado (de la app), fecha de estreno y título original de una obra
  /// guardada según su base de datos; null si no hay conexión. La fecha solo
  /// en películas y el título original solo en lo que viene de TMDB.
  static Future<({String? estado, String? fecha, String? original})?>
  _consultarDatos(FavoritoModel f) async {
    try {
      if (f.tipo == 'pelicula') {
        final p = await TmdbService.obtenerPelicula(
          f.id,
          'es-ES',
          conCreditos: false,
        );
        return (
          estado: FavoritoModel.estadoDeApi(p.estado),
          fecha: p.fechaEstreno,
          original: TmdbRefs.originalDistinto(p.tituloOriginal, f.titulo),
        );
      }
      if (_tituloEnTmdb(f)) {
        final s = await TmdbService.obtenerSerie(
          f.id,
          'es-ES',
          conReparto: false,
        );
        return (
          estado: FavoritoModel.estadoDeApi(s.estado),
          fecha: null,
          original: TmdbRefs.originalDistinto(s.tituloOriginal, f.titulo),
        );
      }
      final estadoApi = switch (f.fuente) {
        'tvmaze' => (await TvmazeService.obtenerSerie(f.id))?.estado,
        _ => (await AnilistService.cargarManga(f.id)).estado,
      };
      return (
        estado: estadoApi == null ? null : FavoritoModel.estadoDeApi(estadoApi),
        fecha: null,
        original: null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Aplica [cambio] a cada entrada de Favoritos y Vistos y guarda, solo
  /// si alguna cambió de verdad.
  Future<void> _cambiarGuardados(
    FavoritoModel Function(FavoritoModel) cambio,
  ) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    var cambiado = false;
    List<FavoritoModel> aplicar(List<FavoritoModel> lista) => lista.map((f) {
      final nuevo = cambio(f);
      cambiado |=
          nuevo.estado != f.estado ||
          nuevo.puntuacion != f.puntuacion ||
          nuevo.fechaEstreno != f.fechaEstreno ||
          nuevo.tituloOriginal != f.tituloOriginal;
      return nuevo;
    }).toList();
    final favoritos = aplicar(usuario.favoritos);
    final vistos = aplicar(usuario.vistos);
    if (!cambiado) return;
    _usuarioActual = usuario.copyWith(favoritos: favoritos, vistos: vistos);
    await _persistir();
  }

  /// [item] con el estado y la puntuación que ya tenga en [otraLista]
  /// (p. ej. al marcar como visto algo de Favoritos ya valorado).
  static FavoritoModel _conValoracionDe(
    List<FavoritoModel> otraLista,
    FavoritoModel item,
  ) {
    final previo = _encontrar(otraLista, item);
    return previo == null
        ? item
        : item.conValoracion(
            estado: previo.estado,
            puntuacion: previo.puntuacion,
          );
  }

  // ===== Importar copia de seguridad =====

  /// Añade de golpe los favoritos, vistos y notas de una copia, sin
  /// duplicar (misma obra aunque venga de otra fuente; notas por id). Se guarda
  /// UNA sola vez en disco, aunque la copia traiga cientos de elementos.
  Future<void> importar(
    List<FavoritoModel> favoritosNuevos,
    List<FavoritoModel> vistosNuevos,
    List<NotaModel> notasNuevas,
  ) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    List<FavoritoModel> unir(
      List<FavoritoModel> actuales,
      List<FavoritoModel> nuevos,
    ) {
      // Misma regla que el corazón: la misma obra desde otra fuente
      // (mismo título y tipo) cuenta como repetida.
      final lista = [...actuales];
      for (final f in nuevos) {
        if (!_contiene(lista, f.fuente, f.tipo, f.id, f.titulo)) lista.add(f);
      }
      return lista;
    }

    final idsNotas = usuario.notas.map((n) => n.id).toSet();
    _usuarioActual = usuario.copyWith(
      favoritos: unir(usuario.favoritos, favoritosNuevos),
      vistos: unir(usuario.vistos, vistosNuevos),
      notas: [
        ...notasNuevas.where((n) => idsNotas.add(n.id)),
        ...usuario.notas,
      ],
    );
    await _persistir();
  }

  // ===== Notas (dónde se dejó cada serie o película) =====

  /// Añade una nota nueva al principio de la lista.
  Future<void> agregarNota(NotaModel nota) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    final nuevaLista = [nota, ...usuario.notas];
    _usuarioActual = usuario.copyWith(notas: nuevaLista);
    await _persistir();
  }

  /// Actualiza una nota existente (misma id).
  Future<void> editarNota(NotaModel nota) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    final nuevaLista = List<NotaModel>.from(usuario.notas);
    final i = nuevaLista.indexWhere((n) => n.id == nota.id);
    if (i < 0) return;
    nuevaLista[i] = nota;
    _usuarioActual = usuario.copyWith(notas: nuevaLista);
    await _persistir();
  }

  /// Quita una nota por su id interna.
  Future<void> quitarNota(String id) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    final nuevaLista = usuario.notas.where((n) => n.id != id).toList();
    _usuarioActual = usuario.copyWith(notas: nuevaLista);
    await _persistir();
  }

  /// Guarda el usuario actual en el almacenamiento local y avisa a las vistas.
  Future<void> _persistir() async {
    final usuario = _usuarioActual;
    if (usuario != null) {
      await AlmacenamientoService.actualizarUsuario(usuario);
    }
    notifyListeners();
  }
}

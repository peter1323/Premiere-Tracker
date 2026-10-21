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
import '../models/serie_model.dart';
import '../models/usuario_model.dart';
import '../services/almacenamiento_service.dart';

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

  /// ¿Está la obra en la lista? Además del id exacto, se compara por
  /// título+tipo: la misma obra agregada desde TMDB y TVMaze tiene ids
  /// distintos en cada fuente.
  static bool _contiene(
    List<FavoritoModel> lista,
    String fuente,
    String tipo,
    int id,
    String? titulo,
  ) {
    if (lista.any((f) => f.fuente == fuente && f.tipo == tipo && f.id == id)) {
      return true;
    }
    if (titulo == null || titulo.isEmpty) return false;
    final normalizado = _tituloNormalizado(titulo);
    return lista.any(
      (f) => f.tipo == tipo && _tituloNormalizado(f.titulo) == normalizado,
    );
  }

  /// Añade la obra si no está; la quita si ya estaba. Si la misma obra
  /// está desde la otra fuente (mismo título y tipo), se quita en lugar
  /// de crear una entrada duplicada.
  static List<FavoritoModel> _alternar(
    List<FavoritoModel> lista,
    FavoritoModel item,
  ) {
    final nuevaLista = List<FavoritoModel>.from(lista);
    var i = nuevaLista.indexWhere((f) => f.idUnico == item.idUnico);
    if (i < 0) {
      final normalizado = _tituloNormalizado(item.titulo);
      i = nuevaLista.indexWhere(
        (f) =>
            f.tipo == item.tipo && _tituloNormalizado(f.titulo) == normalizado,
      );
    }
    if (i >= 0) {
      nuevaLista.removeAt(i);
    } else {
      nuevaLista.add(item);
    }
    return nuevaLista;
  }

  static FavoritoModel _deSerie(SerieModel serie) => FavoritoModel(
    tipo: 'serie',
    fuente: serie.fuente,
    id: serie.id,
    imdbId: serie.imdbId,
    titulo: serie.titulo,
    anio: serie.anio,
    posterUrl: serie.posterUrl,
    fechaEstreno: serie.fechaEstreno,
  );

  static FavoritoModel _dePelicula(PeliculaModel pelicula) => FavoritoModel(
    tipo: 'pelicula',
    fuente: 'tmdb',
    id: pelicula.id,
    titulo: pelicula.titulo,
    anio: pelicula.anio,
    posterUrl: pelicula.posterUrl,
    fechaEstreno: pelicula.fechaEstreno,
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

  /// Añade el favorito si no existe; lo quita si ya estaba.
  Future<void> alternarFavorito(FavoritoModel favorito) =>
      _cambiarLista(false, (l) => _alternar(l, favorito));

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
  Future<void> alternarVisto(FavoritoModel visto) =>
      _cambiarLista(true, (l) => _alternar(l, visto));

  /// Quita un visto por su identificador único ('fuente-tipo-id').
  Future<void> quitarVisto(String idUnico) =>
      _cambiarLista(true, (l) => l.where((v) => v.idUnico != idUnico).toList());

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

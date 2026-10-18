import 'dart:io';

import 'package:flutter/material.dart';

import '../models/favorito_model.dart';
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
  ThemeMode get modoTema =>
      (_usuarioActual?.tema ?? _temaGlobal) == 'oscuro'
          ? ThemeMode.dark
          : ThemeMode.light;

  bool get esOscuro => modoTema == ThemeMode.dark;

  String get nombreUsuario => _usuarioActual?.nombre ?? '';

  // Último tema usado: se aplica en la pantalla de usuarios (sin sesión).
  String _temaGlobal = 'claro';

  /// Carga el tema global guardado al arrancar (pantalla de usuarios).
  Future<void> cargarTemaInicial() async {
    final tema = await AlmacenamientoService.cargarTemaGlobal();
    _temaGlobal = tema;
    if (_usuarioActual == null) notifyListeners();
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

  /// Cierra la aplicación en Windows.
  void cerrarAplicacion() {
    exit(0); // cierra el proceso de la app
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

  /// ¿Está esta serie o película en favoritos del usuario actual?
  /// Además del id exacto, se compara por título+tipo: la misma obra
  /// agregada desde TMDB y TVMaze tiene ids distintos en cada fuente.
  bool esFavorito(String fuente, String tipo, int id, {String? titulo}) {
    final coincideId =
        favoritos.any((f) => f.fuente == fuente && f.tipo == tipo && f.id == id);
    if (coincideId) return true;
    if (titulo == null || titulo.isEmpty) return false;
    final normalizado = _tituloNormalizado(titulo);
    return favoritos.any((f) =>
        f.tipo == tipo && _tituloNormalizado(f.titulo) == normalizado);
  }

  /// Añade o quita una serie de favoritos.
  Future<void> alternarFavoritoDeSerie(SerieModel serie) async {
    await alternarFavorito(FavoritoModel(
      tipo: 'serie',
      fuente: serie.fuente,
      id: serie.id,
      imdbId: serie.imdbId,
      titulo: serie.titulo,
      anio: serie.anio,
      posterUrl: serie.posterUrl,
      fechaEstreno: serie.fechaEstreno,
    ));
  }

  /// Añade o quita una película de favoritos.
  Future<void> alternarFavoritoDePelicula(PeliculaModel pelicula) async {
    await alternarFavorito(FavoritoModel(
      tipo: 'pelicula',
      fuente: 'tmdb',
      id: pelicula.id,
      titulo: pelicula.titulo,
      anio: pelicula.anio,
      posterUrl: pelicula.posterUrl,
      fechaEstreno: pelicula.fechaEstreno,
    ));
  }

  /// Añade el favorito si no existe; lo quita si ya estaba.
  /// Si la misma obra está en la otra fuente (mismo título y tipo),
  /// se quita en lugar de crear una entrada duplicada.
  Future<void> alternarFavorito(FavoritoModel favorito) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    final nuevaLista = List<FavoritoModel>.from(usuario.favoritos);
    final i = nuevaLista.indexWhere((f) => f.idUnico == favorito.idUnico);
    if (i >= 0) {
      nuevaLista.removeAt(i);
    } else {
      final normalizado = _tituloNormalizado(favorito.titulo);
      final j = nuevaLista.indexWhere((f) =>
          f.tipo == favorito.tipo &&
          _tituloNormalizado(f.titulo) == normalizado);
      if (j >= 0) {
        nuevaLista.removeAt(j); // ya estaba (desde la otra fuente)
      } else {
        nuevaLista.add(favorito);
      }
    }
    _usuarioActual = usuario.copyWith(favoritos: nuevaLista);
    await _persistir();
  }

  /// Añade un favorito solo si no existe ya (para importar copias).
  Future<void> agregarFavorito(FavoritoModel favorito) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    if (usuario.favoritos.any((f) => f.idUnico == favorito.idUnico)) return;
    final nuevaLista = [...usuario.favoritos, favorito];
    _usuarioActual = usuario.copyWith(favoritos: nuevaLista);
    await _persistir();
  }

  /// Quita un favorito por su identificador único ('fuente-tipo-id').
  Future<void> quitarFavorito(String idUnico) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    final nuevaLista =
        usuario.favoritos.where((f) => f.idUnico != idUnico).toList();
    _usuarioActual = usuario.copyWith(favoritos: nuevaLista);
    await _persistir();
  }

  // ===== Vistos (marcados como vistos) =====

  /// ¿Está esta serie o película marcada como vista?
  /// Además del id exacto, se compara por título+tipo: la misma obra
  /// agregada desde TMDB y TVMaze tiene ids distintos en cada fuente.
  bool esVisto(String fuente, String tipo, int id, {String? titulo}) {
    final coincideId =
        vistos.any((v) => v.fuente == fuente && v.tipo == tipo && v.id == id);
    if (coincideId) return true;
    if (titulo == null || titulo.isEmpty) return false;
    final normalizado = _tituloNormalizado(titulo);
    return vistos.any((v) =>
        v.tipo == tipo && _tituloNormalizado(v.titulo) == normalizado);
  }

  /// Añade o quita una serie de vistos.
  Future<void> alternarVistoDeSerie(SerieModel serie) async {
    await alternarVisto(FavoritoModel(
      tipo: 'serie',
      fuente: serie.fuente,
      id: serie.id,
      imdbId: serie.imdbId,
      titulo: serie.titulo,
      anio: serie.anio,
      posterUrl: serie.posterUrl,
      fechaEstreno: serie.fechaEstreno,
    ));
  }

  /// Añade o quita una película de vistos.
  Future<void> alternarVistoDePelicula(PeliculaModel pelicula) async {
    await alternarVisto(FavoritoModel(
      tipo: 'pelicula',
      fuente: 'tmdb',
      id: pelicula.id,
      titulo: pelicula.titulo,
      anio: pelicula.anio,
      posterUrl: pelicula.posterUrl,
      fechaEstreno: pelicula.fechaEstreno,
    ));
  }

  /// Marca como vista si no lo estaba; la quita de vistos si ya lo era.
  /// Si la misma obra está en la otra fuente (mismo título y tipo),
  /// se quita en lugar de crear una entrada duplicada.
  Future<void> alternarVisto(FavoritoModel visto) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    final nuevaLista = List<FavoritoModel>.from(usuario.vistos);
    final i = nuevaLista.indexWhere((v) => v.idUnico == visto.idUnico);
    if (i >= 0) {
      nuevaLista.removeAt(i);
    } else {
      final normalizado = _tituloNormalizado(visto.titulo);
      final j = nuevaLista.indexWhere((v) =>
          v.tipo == visto.tipo &&
          _tituloNormalizado(v.titulo) == normalizado);
      if (j >= 0) {
        nuevaLista.removeAt(j); // ya estaba (desde la otra fuente)
      } else {
        nuevaLista.add(visto);
      }
    }
    _usuarioActual = usuario.copyWith(vistos: nuevaLista);
    await _persistir();
  }

  /// Añade un visto solo si no existe ya (para importar copias).
  Future<void> agregarVisto(FavoritoModel visto) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    if (usuario.vistos.any((v) => v.idUnico == visto.idUnico)) return;
    final nuevaLista = [...usuario.vistos, visto];
    _usuarioActual = usuario.copyWith(vistos: nuevaLista);
    await _persistir();
  }

  /// Quita un visto por su identificador único ('fuente-tipo-id').
  Future<void> quitarVisto(String idUnico) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    final nuevaLista =
        usuario.vistos.where((v) => v.idUnico != idUnico).toList();
    _usuarioActual = usuario.copyWith(vistos: nuevaLista);
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

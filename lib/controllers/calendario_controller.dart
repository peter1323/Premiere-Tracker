import 'package:flutter/foundation.dart';

import '../models/episodio_model.dart';
import '../models/favorito_model.dart';
import '../services/tmdb_service.dart';
import '../services/tvmaze_service.dart';

/// Lógica de la pantalla de Calendario: estrenos y episodios de los
/// favoritos del usuario, con vistas de día, semana y mes.
class CalendarioController extends ChangeNotifier {
  String _modoCalendario = 'semana'; // 'dia', 'semana' o 'mes'
  DateTime _fechaVisible = DateTime.now();
  String _pestanaCalendario = 'series'; // 'series' o 'peliculas'
  bool _calendarioCargando = false;
  String? _avisoCalendario; // clave de traducción o null
  Map<String, List<EntradaCalendario>> _seriesPorDia = {};
  Map<String, List<EntradaCalendario>> _peliculasPorDia = {};
  List<FavoritoModel> _favoritos = const [];
  String _language = 'es-ES';
  String _firmaFavoritos = '';
  bool _tvmazeFallo = false;
  int _cargaToken = 0; // invalida cargas viejas al cambiar de rango
  String _rangoCargado = ''; // rango ya cargado ('inicio|fin')

  String get modoCalendario => _modoCalendario;
  DateTime get fechaVisible => _fechaVisible;
  String get pestanaCalendario => _pestanaCalendario;
  bool get calendarioCargando => _calendarioCargando;
  String? get avisoCalendario => _avisoCalendario;
  Map<String, List<EntradaCalendario>> get seriesPorDia => _seriesPorDia;
  Map<String, List<EntradaCalendario>> get peliculasPorDia => _peliculasPorDia;

  /// Primer y último día ('yyyy-MM-dd') del periodo visible según el modo.
  (String, String) get _rangoVisible => _rangoDe(_modoCalendario, _fechaVisible);

  /// Rango de días ('inicio', 'fin') que cubre el modo y la fecha dados.
  static (String, String) _rangoDe(String modo, DateTime fecha) {
    switch (modo) {
      case 'dia':
        final dia = claveDia(fecha);
        return (dia, dia);
      case 'mes':
        final inicio = DateTime(fecha.year, fecha.month, 1);
        final fin = DateTime(fecha.year, fecha.month + 1, 0);
        return (claveDia(inicio), claveDia(fin));
      case 'anio':
        return (claveDia(DateTime(fecha.year, 1, 1)),
            claveDia(DateTime(fecha.year, 12, 31)));
      case 'semana':
      default:
        final lunes =
            DateTime(fecha.year, fecha.month, fecha.day - (fecha.weekday - 1));
        return (
          claveDia(lunes),
          claveDia(DateTime(lunes.year, lunes.month, lunes.day + 6)),
        );
    }
  }

  /// Normaliza la fecha según el modo (lunes de la semana, día 1 del mes...).
  DateTime _normalizar(DateTime fecha) {
    switch (_modoCalendario) {
      case 'dia':
        return DateTime(fecha.year, fecha.month, fecha.day);
      case 'mes':
        return DateTime(fecha.year, fecha.month, 1);
      case 'anio':
        return DateTime(fecha.year, 1, 1);
      case 'semana':
      default:
        return DateTime(fecha.year, fecha.month, fecha.day - (fecha.weekday - 1));
    }
  }

  /// Guarda los favoritos y recarga el calendario solo si algo cambió.
  Future<void> syncFavoritos(
      List<FavoritoModel> favoritos, String language) async {
    final firma = '${favoritos.map((f) => f.idUnico).join('|')}#$language';
    if (firma == _firmaFavoritos) return;
    _firmaFavoritos = firma;
    _favoritos = favoritos;
    _language = language;
    _rangoCargado = ''; // datos nuevos: hay que recargar
    await cargarCalendario();
  }

  /// La vista cambió de periodo (flechas, deslizar...): carga ese rango.
  void irAFecha(DateTime fecha) {
    final normalizada = _normalizar(fecha);
    if (_mismoDia(normalizada, _fechaVisible)) return;
    _fechaVisible = normalizada;
    notifyListeners();
    _recargarSiHaceFalta();
  }

  /// Vuelve al periodo de hoy.
  void irAHoy() {
    final hoy = DateTime.now();
    if (_mismoDia(hoy, _fechaVisible)) return;
    _fechaVisible = _normalizar(hoy);
    notifyListeners();
    _recargarSiHaceFalta();
  }

  /// Cambia el modo del calendario (día | semana | mes).
  void cambiarModoCalendario(String modo) {
    if (_modoCalendario == modo) return;
    _modoCalendario = modo;
    notifyListeners();
    _recargarSiHaceFalta();
  }

  /// Cambia la pestaña del calendario (Series | Películas).
  void cambiarPestanaCalendario(String pestana) {
    if (_pestanaCalendario == pestana) return;
    _pestanaCalendario = pestana;
    notifyListeners();
  }

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Recarga solo si el rango visible no está cubierto por el cargado.
  void _recargarSiHaceFalta() {
    final rango = _rangoVisible;
    final clave = '${rango.$1}|${rango.$2}';
    if (clave == _rangoCargado) return;
    // Un rango más pequeño dentro del cargado (p. ej. mes → semana)
    // no hace falta recargarlo: ya están esos días en memoria.
    final cargado = _rangoCargado.split('|');
    if (cargado.length == 2 &&
        cargado[0].isNotEmpty &&
        rango.$1.compareTo(cargado[0]) >= 0 &&
        rango.$2.compareTo(cargado[1]) <= 0) {
      return;
    }
    cargarCalendario();
  }

  /// Carga episodios y estrenos de los favoritos en el rango visible.
  /// Fechas con TVMaze (si falla, TMDB); las películas usan TMDB.
  Future<void> cargarCalendario() async {
    // Token de esta carga: si el usuario cambia de periodo mientras
    // carga, los resultados viejos se descartan (evita datos cruzados).
    final token = ++_cargaToken;
    _calendarioCargando = true;
    _avisoCalendario = null;
    _tvmazeFallo = false;
    notifyListeners();

    final rango = _rangoVisible;
    final claveInicio = rango.$1;
    final claveFin = rango.$2;

    final seriesPorDia = <String, List<EntradaCalendario>>{};
    final peliculasPorDia = <String, List<EntradaCalendario>>{};

    for (final fav in _favoritos) {
      try {
        if (fav.tipo == 'serie') {
          final entradas = await _entradasSerie(fav, claveInicio, claveFin);
          for (final entrada in entradas) {
            (seriesPorDia[entrada.claveDia] ??= []).add(entrada);
          }
        } else {
          final entrada = await _entradaPelicula(fav, claveInicio, claveFin);
          if (entrada != null) {
            (peliculasPorDia[entrada.claveDia] ??= []).add(entrada);
          }
        }
      } catch (_) {
        // Un favorito que falle no rompe el calendario de los demás
        if (fav.tipo == 'serie') _tvmazeFallo = true;
      }
      // Otra carga más reciente tomó el relevo: se para ya
      if (token != _cargaToken) return;
    }

    // Otra carga más reciente tomó el relevo: se descarta esta
    if (token != _cargaToken) return;
    _seriesPorDia = seriesPorDia;
    _peliculasPorDia = peliculasPorDia;
    _rangoCargado = '$claveInicio|$claveFin';
    _avisoCalendario = _tvmazeFallo ? 'avisoTvmaze' : null;
    _calendarioCargando = false;
    notifyListeners();
  }

  /// Episodios de una serie favorita que caen en el rango visible.
  Future<List<EntradaCalendario>> _entradasSerie(
      FavoritoModel fav, String claveInicio, String claveFin) async {
    List<EpisodioModel> episodios = const [];
    try {
      episodios = await _episodiosTvmaze(fav);
    } catch (_) {
      _tvmazeFallo = true; // TVMaze no responde: se usa el respaldo de TMDB
    }

    // Respaldo TMDB: el próximo episodio de la serie (si cae en el rango).
    // Sin reparto: el calendario solo necesita la fecha.
    if (episodios.isEmpty && fav.fuente == 'tmdb') {
      try {
        final serie =
            await TmdbService.obtenerSerie(fav.id, _language, conReparto: false);
        final proximo = serie.proximoEpisodio;
        if (proximo != null && proximo.fechaEmision.isNotEmpty) {
          episodios = [proximo];
        }
      } catch (_) {
        // sin datos de esta serie
      }
    }

    return episodios
        .where((e) =>
            e.fechaEmision.isNotEmpty &&
            e.fechaEmision.compareTo(claveInicio) >= 0 &&
            e.fechaEmision.compareTo(claveFin) <= 0)
        .map((e) => EntradaCalendario(
              tipo: 'serie',
              fuente: fav.fuente,
              id: fav.id,
              imdbId: fav.imdbId,
              titulo: fav.titulo,
              etiqueta: e.etiqueta,
              hora: e.horaEmision,
              posterUrl: fav.posterUrl,
              claveDia: e.fechaEmision,
            ))
        .toList();
  }

  /// Episodios de la serie desde TVMaze (caché y límite ya controlados).
  /// Los favoritos guardados desde TMDB se enlazan por IMDb.
  Future<List<EpisodioModel>> _episodiosTvmaze(FavoritoModel fav) async {
    if (fav.fuente == 'tvmaze') {
      return TvmazeService.obtenerEpisodios(fav.id);
    }
    String? imdb = fav.imdbId;
    if (imdb == null) {
      try {
        imdb = await TmdbService.obtenerImdbId(fav.id);
      } catch (_) {
        return const []; // fallo de TMDB, no de TVMaze
      }
    }
    if (imdb == null || imdb.isEmpty) return const [];
    final serieTvmaze = await TvmazeService.buscarPorImdb(imdb);
    if (serieTvmaze == null) return const [];
    return TvmazeService.obtenerEpisodios(serieTvmaze.id);
  }

  /// Estreno de una película favorita dentro de la semana visible.
  Future<EntradaCalendario?> _entradaPelicula(
      FavoritoModel fav, String claveInicio, String claveFin) async {
    var fecha = fav.fechaEstreno;
    // Si el favorito no guardó la fecha, se pide a TMDB (sin reparto:
    // el calendario solo necesita la fecha).
    if (fecha.isEmpty && fav.fuente == 'tmdb') {
      try {
        final pelicula = await TmdbService.obtenerPelicula(fav.id, _language,
            conCreditos: false);
        fecha = pelicula.fechaEstreno;
      } catch (_) {
        return null;
      }
    }
    if (fecha.isEmpty) return null;
    if (fecha.compareTo(claveInicio) < 0 || fecha.compareTo(claveFin) > 0) {
      return null;
    }
    return EntradaCalendario(
      tipo: 'pelicula',
      fuente: fav.fuente,
      id: fav.id,
      titulo: fav.titulo,
      etiqueta: '',
      hora: '',
      posterUrl: fav.posterUrl,
      claveDia: fecha,
    );
  }
}

/// Un elemento del calendario: un episodio de serie o un estreno de película.
class EntradaCalendario {
  final String tipo; // 'serie' o 'pelicula'
  final String fuente;
  final int id;
  final String? imdbId;
  final String titulo;
  final String etiqueta; // "T2E5" en series, vacío en películas
  final String hora; // "HH:mm" o vacío
  final String? posterUrl;
  final String claveDia; // 'yyyy-MM-dd'

  const EntradaCalendario({
    required this.tipo,
    required this.fuente,
    required this.id,
    this.imdbId,
    required this.titulo,
    this.etiqueta = '',
    this.hora = '',
    this.posterUrl,
    required this.claveDia,
  });
}

/// Clave de un día en formato 'yyyy-MM-dd' (para agrupar por día).
String claveDia(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

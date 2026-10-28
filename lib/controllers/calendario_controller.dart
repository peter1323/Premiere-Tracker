// CONTROLADOR de la pantalla Calendario (sección 3 del menú).
// Calcula los próximos estrenos de las series y películas favoritas con
// vistas de día, semana y mes. SOLO trabaja con series y películas (los
// mangas no se meten aquí). Pide los datos a TmdbService y TvmazeService
// y los agrupa por día en mapas con clave 'yyyy-MM-dd'. Vive en el
// IndexedStack, así que no se destruye al cambiar de sección.
import 'package:flutter/foundation.dart';

import '../models/episodio_model.dart';
import '../models/favorito_model.dart';
import '../services/tmdb_service.dart';
import '../services/tvmaze_service.dart';

/// Lógica de la pantalla de Calendario: estrenos y episodios de los
/// favoritos del usuario, con vistas de día, semana y mes. Inicio lo usa
/// también con el modo 'proximos' (hoy y los 6 días siguientes).
class CalendarioController extends ChangeNotifier {
  // 'dia', 'semana', 'mes', 'anio' o 'proximos'
  String _modoCalendario;
  DateTime _fechaVisible = DateTime.now();

  CalendarioController({String modo = 'semana'}) : _modoCalendario = modo;

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

  /// Todos los estrenos cargados (series y películas) en orden de fecha y
  /// hora. Es lo que muestra Próximamente en Inicio.
  List<EntradaCalendario> get proximas => [
    ..._seriesPorDia.values.expand((l) => l),
    ..._peliculasPorDia.values.expand((l) => l),
  ]..sort(compararEstrenos);

  /// Primer y último día ('yyyy-MM-dd') del periodo visible según el modo.
  (String, String) get _rangoVisible =>
      _rangoDe(_modoCalendario, _fechaVisible);

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
      case 'proximos':
        return (
          claveDia(fecha),
          claveDia(DateTime(fecha.year, fecha.month, fecha.day + 6)),
        );
      case 'anio':
        return (
          claveDia(DateTime(fecha.year, 1, 1)),
          claveDia(DateTime(fecha.year, 12, 31)),
        );
      case 'semana':
      default:
        final lunes = DateTime(
          fecha.year,
          fecha.month,
          fecha.day - (fecha.weekday - 1),
        );
        return (
          claveDia(lunes),
          claveDia(DateTime(lunes.year, lunes.month, lunes.day + 6)),
        );
    }
  }

  /// Normaliza la fecha según el modo (lunes de la semana, día 1 del mes...).
  DateTime _normalizar(DateTime fecha) =>
      inicioDePeriodo(_modoCalendario, fecha);

  /// Guarda los favoritos y recarga el calendario solo si algo cambió.
  Future<void> syncFavoritos(
    List<FavoritoModel> favoritos,
    String language,
  ) async {
    // Solo series y películas: los mangas y novelas no van al calendario
    favoritos = favoritos
        .where((f) => f.tipo == 'serie' || f.tipo == 'pelicula')
        .toList();
    // Con la fecha y el título original: si se completan, el calendario
    // recarga
    final firma =
        '${favoritos.map((f) => '${f.idUnico}:${f.fechaEstreno}:${f.tituloOriginal}').join('|')}'
        '#$language';
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

    // Todos los favoritos a la vez (TVMaze sigue respetando su límite de
    // peticiones); Future.wait devuelve los resultados en el orden de la
    // lista de favoritos, así el calendario sale siempre igual.
    final resultados = await Future.wait(
      _favoritos.map((fav) async {
        try {
          return fav.tipo == 'serie'
              ? await _entradasSerie(fav, claveInicio, claveFin)
              : [?await _entradaPelicula(fav, claveInicio, claveFin)];
        } catch (_) {
          // Un favorito que falle no rompe el calendario de los demás
          if (fav.tipo == 'serie') _tvmazeFallo = true;
          return const <EntradaCalendario>[];
        }
      }),
    );

    // Otra carga más reciente tomó el relevo: se descarta esta
    if (token != _cargaToken) return;
    for (final entrada in resultados.expand((lista) => lista)) {
      final porDia = entrada.tipo == 'serie' ? seriesPorDia : peliculasPorDia;
      (porDia[entrada.claveDia] ??= []).add(entrada);
    }
    _seriesPorDia = seriesPorDia;
    _peliculasPorDia = peliculasPorDia;
    _rangoCargado = '$claveInicio|$claveFin';
    _avisoCalendario = _tvmazeFallo ? 'avisoTvmaze' : null;
    _calendarioCargando = false;
    notifyListeners();
  }

  /// Episodios de una serie favorita que caen en el rango visible.
  Future<List<EntradaCalendario>> _entradasSerie(
    FavoritoModel fav,
    String claveInicio,
    String claveFin,
  ) async {
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
        final serie = await TmdbService.obtenerSerie(
          fav.id,
          _language,
          conReparto: false,
        );
        final proximo = serie.proximoEpisodio;
        if (proximo != null && proximo.fechaEmision.isNotEmpty) {
          episodios = [proximo];
        }
      } catch (_) {
        // sin datos de esta serie
      }
    }

    return episodios
        .where(
          (e) =>
              e.fechaEmision.isNotEmpty &&
              e.fechaEmision.compareTo(claveInicio) >= 0 &&
              e.fechaEmision.compareTo(claveFin) <= 0,
        )
        .map(
          (e) => EntradaCalendario(
            tipo: 'serie',
            fuente: fav.fuente,
            id: fav.id,
            imdbId: fav.imdbId,
            titulo: fav.titulo,
            tituloOriginal: fav.tituloOriginal ?? '',
            etiqueta: e.etiqueta,
            hora: e.horaEmision,
            posterUrl: fav.posterUrl,
            claveDia: e.fechaEmision,
          ),
        )
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
    FavoritoModel fav,
    String claveInicio,
    String claveFin,
  ) async {
    var fecha = fav.fechaEstreno;
    // Si el favorito no guardó la fecha, se pide a TMDB (sin reparto:
    // el calendario solo necesita la fecha).
    if (fecha.isEmpty && fav.fuente == 'tmdb') {
      try {
        final pelicula = await TmdbService.obtenerPelicula(
          fav.id,
          _language,
          conCreditos: false,
        );
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
      tituloOriginal: fav.tituloOriginal ?? '',
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
  // Título en su idioma original si es distinto ('' si no o no se sabe)
  final String tituloOriginal;
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
    this.tituloOriginal = '',
    this.etiqueta = '',
    this.hora = '',
    this.posterUrl,
    required this.claveDia,
  });

  /// Copia con otra [etiqueta] (Estrenos la rellena después de cargar).
  EntradaCalendario conEtiqueta(String etiqueta) => EntradaCalendario(
    tipo: tipo,
    fuente: fuente,
    id: id,
    imdbId: imdbId,
    titulo: titulo,
    tituloOriginal: tituloOriginal,
    etiqueta: etiqueta,
    hora: hora,
    posterUrl: posterUrl,
    claveDia: claveDia,
  );

  /// Texto para mostrar: "T1E3 · Título" en series, solo el título en
  /// películas. Lo usan el calendario, Próximamente y los avisos.
  String get texto => etiqueta.isNotEmpty ? '$etiqueta · $titulo' : titulo;
}

/// Primer día del periodo de [fecha] según el [modo] del calendario (el
/// mismo día, el lunes de la semana, el día 1 del mes o el 1 de enero). Lo
/// usan el Calendario y Estrenos al cambiar de periodo.
DateTime inicioDePeriodo(String modo, DateTime fecha) => switch (modo) {
  'mes' => DateTime(fecha.year, fecha.month, 1),
  'anio' => DateTime(fecha.year, 1, 1),
  'semana' => DateTime(
    fecha.year,
    fecha.month,
    fecha.day - (fecha.weekday - 1),
  ),
  _ => DateTime(fecha.year, fecha.month, fecha.day), // día y próximos
};

/// Clave de un día en formato 'yyyy-MM-dd' (para agrupar por día).
String claveDia(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

/// Orden de los estrenos: por día y, dentro del día, por hora (los que no
/// tienen hora van al final). Lo usan Próximamente y el calendario.
int compararEstrenos(EntradaCalendario a, EntradaCalendario b) {
  final porDia = a.claveDia.compareTo(b.claveDia);
  if (porDia != 0) return porDia;
  if (a.hora.isEmpty != b.hora.isEmpty) return a.hora.isEmpty ? 1 : -1;
  return a.hora.compareTo(b.hora);
}

/// Días que faltan para [fecha] ('yyyy-MM-dd'): 0 si es hoy, null si no
/// hay fecha o ya pasó. Es la base de la cuenta atrás de las tarjetas y
/// de la ficha; [ahora] solo se pasa en los tests.
int? diasParaEstreno(String fecha, [DateTime? ahora]) {
  final dia = fecha.length >= 10 ? DateTime.tryParse(fecha) : null;
  if (dia == null) return null;
  final hoy = ahora ?? DateTime.now();
  // En UTC para que un cambio de hora (verano/invierno) no reste un día
  final dias = DateTime.utc(
    dia.year,
    dia.month,
    dia.day,
  ).difference(DateTime.utc(hoy.year, hoy.month, hoy.day)).inDays;
  return dias < 0 ? null : dias;
}

// SERVICIO de búsqueda combinada. Es el que usa Inicio para buscar a la
// vez en TMDB y TVMaze: lanza las dos consultas en paralelo y es
// anti-fallos (si una fuente cae o falla la clave, la otra sigue y se
// avisa). También deduplica personas y enlaza títulos/actores entre una
// fuente y otra. No dibuja nada.
import '../models/pelicula_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
import 'tmdb_service.dart';
import 'tvmaze_service.dart';

/// Resultado de buscar en TMDB y TVMaze a la vez.
class ResultadoBusqueda {
  final List<SerieModel> seriesTmdb;
  final List<SerieModel> seriesTvmaze;
  final List<PeliculaModel> peliculas; // Solo TMDB tiene películas
  final List<PersonaModel> personas; // TMDB + TVMaze (deduplicadas)
  final List<String> avisos; // claves de traducción de app_strings
  final bool tmdbOk;
  final bool tvmazeOk;

  const ResultadoBusqueda({
    this.seriesTmdb = const [],
    this.seriesTvmaze = const [],
    this.peliculas = const [],
    this.personas = const [],
    this.avisos = const [],
    this.tmdbOk = false,
    this.tvmazeOk = false,
  });

  /// ¿Hay algún resultado en total?
  bool get hayResultados =>
      seriesTmdb.isNotEmpty ||
      seriesTvmaze.isNotEmpty ||
      peliculas.isNotEmpty ||
      personas.isNotEmpty;
}

/// Búsqueda anti-fallos: TMDB y TVMaze se lanzan EN PARALELO
/// y el error de cada una se controla por separado.
class BusquedaService {
  static Future<ResultadoBusqueda> buscar(
    String consulta,
    String language,
  ) async {
    // Las cuatro peticiones a la vez; cada una captura su propio error.
    final resultados = await Future.wait([
      _buscarTmdb(consulta, language),
      _buscarTvmaze(consulta),
      _buscarPersonasTmdb(consulta, language),
      _buscarPersonasTvmaze(consulta),
    ]);
    final tmdb = resultados[0] as _ResultadoTmdb;
    final tvmaze = resultados[1] as _ResultadoTvmaze;
    final personasTmdb = resultados[2] as List<PersonaModel>;
    final personasTvmaze = resultados[3] as List<PersonaModel>;

    // Avisos: si fallan las dos, un solo mensaje de sin conexión.
    final avisos = <String>[];
    if (!tmdb.ok && !tvmaze.ok) {
      avisos.add('sinConexion');
    } else {
      if (tmdb.aviso != null) avisos.add(tmdb.aviso!);
      if (tvmaze.aviso != null) avisos.add(tvmaze.aviso!);
    }

    return ResultadoBusqueda(
      seriesTmdb: tmdb.series,
      seriesTvmaze: tvmaze.series,
      peliculas: tmdb.peliculas,
      personas: _fusionarPersonas(personasTmdb, personasTvmaze),
      avisos: avisos,
      tmdbOk: tmdb.ok,
      tvmazeOk: tvmaze.ok,
    );
  }

  /// Fusiona las personas de TMDB y TVMaze sin repetir nombres:
  /// primero TMDB, y luego las de TVMaze que no estén ya.
  static List<PersonaModel> _fusionarPersonas(
    List<PersonaModel> tmdb,
    List<PersonaModel> tvmaze,
  ) {
    final nombres = tmdb.map((p) => p.nombre.trim().toLowerCase()).toSet();
    final fusionadas = List<PersonaModel>.of(tmdb);
    for (final p in tvmaze) {
      if (!nombres.contains(p.nombre.trim().toLowerCase())) {
        fusionadas.add(p);
      }
    }
    return fusionadas;
  }

  /// Enlaza una serie de TMDB con su ficha en TVMaze usando IMDb de puente.
  /// Devuelve null si no se encuentra el enlace.
  static Future<SerieModel?> enlazarEnTvmaze(SerieModel serie) async {
    try {
      final imdb = serie.imdbId ?? await TmdbService.obtenerImdbId(serie.id);
      if (imdb == null || imdb.isEmpty) return null;
      return await TvmazeService.buscarPorImdb(imdb);
    } catch (_) {
      return null;
    }
  }

  /// Enlaza una serie de TVMaze con la de TMDB (búsqueda por título).
  /// Devuelve null si TMDB no la tiene.
  static Future<SerieModel?> enlazarEnTmdb(
    SerieModel serie,
    String language,
  ) async {
    try {
      final series = await TmdbService.buscarSeries(serie.titulo, language);
      if (series.isEmpty) return null;
      // Mejor coincidencia: mismo título, o la primera del resultado.
      return series.firstWhere(
        (s) => s.titulo.toLowerCase() == serie.titulo.toLowerCase(),
        orElse: () => series.first,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<_ResultadoTmdb> _buscarTmdb(
    String consulta,
    String language,
  ) async {
    try {
      final series = await TmdbService.buscarSeries(consulta, language);
      final peliculas = await TmdbService.buscarPeliculas(consulta, language);
      return _ResultadoTmdb(series, peliculas, true, null);
    } on TmdbException catch (e) {
      return _ResultadoTmdb(
        const [],
        const [],
        false,
        e.claveIncorrecta ? 'avisoTmdbKey' : 'avisoTmdb',
      );
    } catch (_) {
      return _ResultadoTmdb(const [], const [], false, 'avisoTmdb');
    }
  }

  static Future<_ResultadoTvmaze> _buscarTvmaze(String consulta) async {
    try {
      final series = await TvmazeService.buscarSeries(consulta);
      return _ResultadoTvmaze(series, true, null);
    } catch (_) {
      return _ResultadoTvmaze(const [], false, 'avisoTvmaze');
    }
  }

  /// Busca personas en TMDB (anti-fallos: si falla, lista vacía).
  static Future<List<PersonaModel>> _buscarPersonasTmdb(
    String consulta,
    String language,
  ) async {
    try {
      return await TmdbService.buscarPersonas(consulta, language);
    } catch (_) {
      return const [];
    }
  }

  /// Busca personas en TVMaze (anti-fallos: si falla, lista vacía).
  static Future<List<PersonaModel>> _buscarPersonasTvmaze(
    String consulta,
  ) async {
    try {
      return await TvmazeService.buscarPersonas(consulta);
    } catch (_) {
      return const [];
    }
  }

  /// Enlaza una persona de TVMaze con su ficha en TMDB (búsqueda por
  /// nombre exacto). Devuelve null si TMDB no la tiene.
  static Future<PersonaModel?> enlazarPersonaEnTmdb(
    PersonaModel persona,
    String language,
  ) => _mismoNombre(
    persona,
    () => TmdbService.buscarPersonas(persona.nombre, language),
  );

  /// Enlaza una persona de TMDB con su ficha en TVMaze (búsqueda por
  /// nombre exacto). Devuelve null si TVMaze no la tiene.
  static Future<PersonaModel?> enlazarPersonaEnTvmaze(PersonaModel persona) =>
      _mismoNombre(persona, () => TvmazeService.buscarPersonas(persona.nombre));

  /// Primera persona de la búsqueda con el mismo nombre (sin mayúsculas ni
  /// espacios sobrantes); null si no hay o si la búsqueda falla.
  static Future<PersonaModel?> _mismoNombre(
    PersonaModel persona,
    Future<List<PersonaModel>> Function() buscar,
  ) async {
    final nombre = persona.nombre.trim().toLowerCase();
    try {
      for (final p in await buscar()) {
        if (p.nombre.trim().toLowerCase() == nombre) return p;
      }
    } catch (_) {
      // sin conexión: no se enlaza
    }
    return null;
  }
}

/// Resultado interno de TMDB (series + películas + aviso).
class _ResultadoTmdb {
  final List<SerieModel> series;
  final List<PeliculaModel> peliculas;
  final bool ok;
  final String? aviso; // clave de traducción o null
  const _ResultadoTmdb(this.series, this.peliculas, this.ok, this.aviso);
}

/// Resultado interno de TVMaze (solo series) + aviso.
class _ResultadoTvmaze {
  final List<SerieModel> series;
  final bool ok;
  final String? aviso; // clave de traducción o null
  const _ResultadoTvmaze(this.series, this.ok, this.aviso);
}

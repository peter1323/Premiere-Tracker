// CONTROLADOR de la ficha de una serie o película (se abre con
// Navigator.push desde los resultados o desde Favoritos/Vistos).
// Carga el título desde su fuente original (TMDB o TVMaze), permite
// cambiar de fuente enlazando por el id de IMDb y carga los episodios de
// cada temporada y las recomendaciones de TMDB. Se crea en
// detalle_view.dart y se DESTRUYE al volver
// atrás: por eso sus métodos async comprueban `if (_destruido) return;`
// antes de notificar (si no, avisarían a un controlador ya liberado).
import 'package:flutter/foundation.dart';

import '../models/episodio_model.dart';
import '../models/pelicula_model.dart';
import '../models/serie_model.dart';
import '../services/busqueda_service.dart';
import '../services/tmdb_service.dart';
import '../services/tvmaze_service.dart';

/// Lógica de la pantalla de detalle: carga una serie o película, permite
/// cambiar la fuente de una serie (TMDB | TVMaze) enlazando por IMDb,
/// y carga los episodios de cada temporada.
class DetalleController extends ChangeNotifier {
  final String tipo; // 'serie' o 'pelicula'
  final int idInicial; // id en la fuente inicial
  final String fuenteInicial; // 'tmdb' o 'tvmaze'
  final String? imdbIdInicial;
  final String language; // 'es-ES' o 'en-US'

  SerieModel? _serie;
  PeliculaModel? _pelicula;
  String _fuente; // fuente mostrada ahora mismo
  String? _imdbId; // puente IMDb (series)
  int? _idTmdb; // id de TMDB de la serie (para pedir episodios)
  int? _idTvmaze; // id de TVMaze de la serie (para su enlace)
  bool _cargando = false;
  String? _aviso; // clave de traducción o null

  // Disponibilidad de cada fuente para ESTA serie
  bool _tmdbOk = true;
  bool _tvmazeOk = true;

  // Episodios cargados por número de temporada
  final Map<int, List<EpisodioModel>> _episodios = {};
  bool _cargandoEpisodios = false;
  bool _destruido = false; // true si la vista se cerró mientras cargaba

  DetalleController({
    required this.tipo,
    required this.idInicial,
    required this.fuenteInicial,
    this.imdbIdInicial,
    required this.language,
  }) : _fuente = fuenteInicial,
       _imdbId = imdbIdInicial;

  SerieModel? get serie => _serie;
  PeliculaModel? get pelicula => _pelicula;
  String get fuente => _fuente;
  String? get imdbId => _imdbId;
  bool get cargando => _cargando;
  String? get aviso => _aviso;
  bool get tmdbOk => _tmdbOk;
  bool get tvmazeOk => _tvmazeOk;
  bool get cargandoEpisodios => _cargandoEpisodios;
  bool get esSerie => tipo == 'serie';

  /// Enlaces a la ficha en las webs: TMDB y, en series, TVMaze. Si aún no
  /// se sabe el id en una de ellas (no se ha cambiado de fuente), se abre
  /// su buscador con el título.
  List<({String nombre, String url})> get enlaces {
    if (!esSerie) {
      return [
        (nombre: 'TMDB', url: 'https://www.themoviedb.org/movie/$idInicial'),
      ];
    }
    final titulo = Uri.encodeQueryComponent(_serie?.titulo ?? '');
    return [
      (
        nombre: 'TMDB',
        url: _idTmdb == null
            ? 'https://www.themoviedb.org/search/tv?query=$titulo'
            : 'https://www.themoviedb.org/tv/$_idTmdb',
      ),
      (
        nombre: 'TVMaze',
        url: _idTvmaze == null
            ? 'https://www.tvmaze.com/search?q=$titulo'
            : 'https://www.tvmaze.com/shows/$_idTvmaze',
      ),
    ];
  }

  // Recomendaciones de TMDB (solo se usa la lista del tipo de la ficha)
  List<SerieModel> _recomendacionesSeries = const [];
  List<PeliculaModel> _recomendacionesPeliculas = const [];
  List<SerieModel> get recomendacionesSeries => _recomendacionesSeries;
  List<PeliculaModel> get recomendacionesPeliculas => _recomendacionesPeliculas;

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }

  /// Temporadas de la serie (TMDB las trae en el detalle).
  /// En TVMaze no hay lista de temporadas: se derivan de los episodios
  /// ya cargados, agrupados por número de temporada.
  List<TemporadaModel> get temporadas {
    final deFuente = _serie?.temporadas ?? const <TemporadaModel>[];
    if (deFuente.isNotEmpty) return deFuente;
    if (_fuente != 'tvmaze' || _episodios.isEmpty) return const [];

    final numeros = _episodios.keys.where((n) => n > 0).toList()..sort();
    return [
      for (final numero in numeros)
        TemporadaModel(
          numero: numero,
          totalEpisodios: _episodios[numero]?.length ?? 0,
        ),
    ];
  }

  /// Episodios ya cargados de una temporada (vacío si aún no se cargaron).
  List<EpisodioModel> episodiosDeTemporada(int numero) =>
      _episodios[numero] ?? const [];

  /// ¿Ya se cargaron los episodios de esa temporada?
  bool episodiosCargados(int numero) => _episodios.containsKey(numero);

  /// Carga inicial: película por TMDB, o serie por su fuente de origen.
  Future<void> cargar() async {
    _cargando = true;
    _aviso = null;
    notifyListeners();

    if (!esSerie) {
      await _cargarPelicula();
    } else {
      await _cargarSerie(_fuente, idInicial);
    }
    if (_destruido) return; // la vista se cerró: nadie escucha ya
    _cargando = false;
    notifyListeners();
    _cargarRecomendaciones(); // después: la ficha se ve sin esperarlas
  }

  /// Recomendaciones de TMDB ("si te gustó esto..."). Necesitan el id de
  /// TMDB: si la serie se abrió desde TVMaze se enlaza por título. Si no
  /// hay id o TMDB no devuelve nada, la lista queda vacía (no se pinta).
  Future<void> _cargarRecomendaciones() async {
    try {
      if (esSerie) {
        final serie = _serie;
        final id =
            _idTmdb ??
            (serie == null
                ? null
                : (await BusquedaService.enlazarEnTmdb(serie, language))?.id);
        if (id == null) return;
        _recomendacionesSeries = await TmdbService.recomendacionesSerie(
          id,
          language,
        );
      } else {
        _recomendacionesPeliculas = await TmdbService.recomendacionesPelicula(
          idInicial,
          language,
        );
      }
    } catch (_) {
      return; // sin conexión o sin clave: sin recomendaciones
    }
    if (!_destruido) notifyListeners();
  }

  Future<void> _cargarPelicula() async {
    try {
      _pelicula = await TmdbService.obtenerPelicula(idInicial, language);
      _aviso = null;
    } on TmdbException catch (e) {
      _aviso = e.claveIncorrecta ? 'avisoTmdbKey' : 'avisoTmdb';
    } catch (_) {
      _aviso = 'sinConexion';
    }
  }

  Future<void> _cargarSerie(String fuente, int id) async {
    try {
      if (fuente == 'tmdb') {
        final serie = await TmdbService.obtenerSerie(id, language);
        // IMDb como puente para poder cambiar a TVMaze después.
        // Si esta consulta falla no se pierde la serie: solo el puente.
        String? imdb = serie.imdbId;
        if (imdb == null) {
          try {
            imdb = await TmdbService.obtenerImdbId(id);
          } catch (_) {
            imdb = null; // sin puente IMDb, pero la serie se muestra
          }
        }
        _serie = serie.copyWith(imdbId: imdb);
        _imdbId = imdb;
        _idTmdb = id; // id real de TMDB (para pedir episodios)
        _tmdbOk = true;
      } else {
        final serie = await TvmazeService.obtenerSerie(id);
        if (serie == null) {
          _tvmazeOk = false;
          _aviso = 'noEnTvmaze';
          return;
        }
        _serie = serie;
        _tvmazeOk = true;
        _idTvmaze = serie.id;
        // TVMaze trae todos los episodios de golpe: se agrupan por temporada
        await _cargarTodosTvmaze(serie.id);
      }
      _aviso = null;
    } on TmdbException catch (e) {
      _tmdbOk = false;
      _aviso = e.claveIncorrecta ? 'avisoTmdbKey' : 'avisoTmdb';
    } catch (_) {
      if (fuente == 'tmdb') {
        _tmdbOk = false;
        _aviso = 'avisoTmdb';
      } else {
        _tvmazeOk = false;
        _aviso = 'avisoTvmaze';
      }
    }
  }

  /// Cambia la fuente de la serie (TMDB <-> TVMaze) enlazando por IMDb.
  Future<void> cambiarFuente(String nuevaFuente) async {
    if (nuevaFuente == _fuente || _cargando) return;

    // Si ya se sabe que esa fuente no tiene la serie, se ignora
    if (nuevaFuente == 'tmdb' && !_tmdbOk) return;
    if (nuevaFuente == 'tvmaze' && !_tvmazeOk) return;

    _cargando = true;
    _aviso = null;
    notifyListeners();

    _fuente = nuevaFuente;
    _episodios.clear();

    if (nuevaFuente == 'tvmaze') {
      // Puente: IMDb -> TVMaze
      SerieModel? enTvmaze;
      try {
        final imdb = _imdbId ?? serie?.imdbId;
        if (imdb != null && imdb.isNotEmpty) {
          enTvmaze = await TvmazeService.buscarPorImdb(imdb);
        } else if (serie != null) {
          enTvmaze = await BusquedaService.enlazarEnTvmaze(serie!);
        }
      } catch (_) {
        enTvmaze = null;
      }
      if (enTvmaze == null) {
        _tvmazeOk = false;
        _fuente = 'tmdb'; // se vuelve a la fuente anterior
        _aviso = 'noEnTvmaze';
      } else {
        // La ficha con embeds trae reparto, canales y próximo episodio.
        // Si falla, se conserva la ficha básica del enlace.
        var completa = enTvmaze;
        try {
          completa = await TvmazeService.obtenerSerie(enTvmaze.id) ?? completa;
        } catch (_) {
          // sin embeds: se queda con la ficha básica del enlace
        }
        _serie = completa;
        _idTvmaze = completa.id;
        _imdbId = completa.imdbId ?? _imdbId;
        await _cargarTodosTvmaze(completa.id);
      }
    } else {
      // tvmaze -> tmdb: búsqueda por título
      SerieModel? enTmdb;
      try {
        enTmdb = await BusquedaService.enlazarEnTmdb(serie!, language);
      } catch (_) {
        enTmdb = null;
      }
      if (enTmdb == null) {
        _tmdbOk = false;
        _fuente = 'tvmaze'; // se vuelve a la fuente anterior
        _aviso = 'avisoTmdb';
      } else {
        // carga el detalle completo (estado, temporadas, próximo episodio)
        await _cargarSerie('tmdb', enTmdb.id);
      }
    }

    if (_destruido) return; // la vista se cerró: nadie escucha ya
    _cargando = false;
    notifyListeners();
  }

  /// Carga todos los episodios de TVMaze y los agrupa por temporada.
  Future<void> _cargarTodosTvmaze(int idSerie) async {
    final episodios = await TvmazeService.obtenerEpisodios(idSerie);
    _episodios.clear();
    for (final e in episodios) {
      (_episodios[e.temporada] ??= []).add(e);
    }
  }

  /// Carga (de forma perezosa) los episodios de una temporada de TMDB.
  /// Usa el id de TMDB de la serie cargada (no el id inicial, que podría
  /// ser el de TVMaze si el usuario cambió la fuente).
  Future<void> cargarEpisodiosTemporada(int numero) async {
    if (!esSerie || _fuente != 'tmdb') return;
    final idTmdb = _idTmdb;
    if (idTmdb == null) return;
    if (_episodios.containsKey(numero) || _cargandoEpisodios) return;
    _cargandoEpisodios = true;
    notifyListeners();
    try {
      final episodios = await TmdbService.obtenerEpisodiosTemporada(
        idTmdb,
        numero,
        language,
      );
      if (_destruido) return; // la vista se cerró: nadie escucha ya
      _episodios[numero] = episodios;
    } catch (_) {
      _episodios[numero] = const []; // marca como cargada (vacía)
    }
    _cargandoEpisodios = false;
    notifyListeners();
  }
}

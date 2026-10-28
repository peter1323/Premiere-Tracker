// SERVICIO de TMDB: la API de películas y series (la fuente principal de
// la app). Es la ÚNICA que necesita API key, y esa clave la aporta
// ClaveService (la guarda el usuario en la app; nunca va
// escrita en el código). Sirve para buscar y cargar series, películas,
// personas, reparto y episodios. Cada petición lleva timeout; si la
// clave falta o está mal lanza TmdbException con la marca
// claveIncorrecta. No dibuja nada.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/episodio_model.dart';
import '../models/filtros_estrenos.dart';
import '../models/pelicula_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
import 'cache_futuros.dart';
import 'clave_service.dart';

/// Error propio de TMDB: clave mal/servicio no disponible.
class TmdbException implements Exception {
  final String mensaje;
  final bool claveIncorrecta;
  TmdbException(this.mensaje, {this.claveIncorrecta = false});
  @override
  String toString() => mensaje;
}

/// Conexión con la API de TMDB (películas y series).
class TmdbService {
  static const String _base = 'https://api.themoviedb.org/3';
  static const Duration _timeout = Duration(seconds: 10);

  /// true si el usuario aún no ha guardado su clave.
  static bool get claveFaltante => !ClaveService.hayClave;

  /// Petición GET genérica con timeout de 10 segundos.
  static Future<Map<String, dynamic>> _get(
    String ruta, {
    Map<String, String> parametros = const {},
  }) async {
    if (claveFaltante) {
      throw TmdbException('Falta la API key de TMDB', claveIncorrecta: true);
    }
    final uri = Uri.parse(
      '$_base$ruta',
    ).replace(queryParameters: {...ClaveService.parametrosAuth, ...parametros});
    try {
      final respuesta = await http
          .get(uri, headers: ClaveService.cabeceras)
          .timeout(_timeout);
      if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
        throw TmdbException(
          'La API key de TMDB no es válida',
          claveIncorrecta: true,
        );
      }
      if (respuesta.statusCode != 200) {
        throw TmdbException('TMDB devolvió el código ${respuesta.statusCode}');
      }
      return jsonDecode(respuesta.body) as Map<String, dynamic>;
    } on TmdbException {
      rethrow;
    } catch (e) {
      throw TmdbException('Fallo de conexión con TMDB: $e');
    }
  }

  /// Lista "results" de TMDB convertida con [desde]: la usan las
  /// búsquedas y las recomendaciones (todas devuelven el mismo formato).
  static Future<List<T>> _resultados<T>(
    String ruta,
    Map<String, String> parametros,
    T Function(Map<String, dynamic>) desde,
  ) async {
    final json = await _get(ruta, parametros: parametros);
    final resultados = json['results'] as List<dynamic>? ?? [];
    return resultados.map((r) => desde(r as Map<String, dynamic>)).toList();
  }

  /// Busca series en TMDB (/search/tv).
  static Future<List<SerieModel>> buscarSeries(
    String consulta,
    String language,
  ) => _resultados('/search/tv', {
    'query': consulta,
    'language': language,
  }, SerieModel.fromTmdbBusqueda);

  /// Busca películas en TMDB (/search/movie).
  static Future<List<PeliculaModel>> buscarPeliculas(
    String consulta,
    String language,
  ) => _resultados('/search/movie', {
    'query': consulta,
    'language': language,
    // Con la región, "release_date" es la fecha de estreno de España
    'region': TmdbRefs.region,
  }, PeliculaModel.fromTmdbBusqueda);

  /// Busca personas (actores, directores...) en TMDB (/search/person).
  static Future<List<PersonaModel>> buscarPersonas(
    String consulta,
    String language,
  ) => _resultados('/search/person', {
    'query': consulta,
    'language': language,
  }, PersonaModel.fromTmdbBusqueda);

  // Caché de recomendaciones: reabrir una ficha no repite la petición.
  static final _cacheRecomendaciones = CacheFuturos();

  /// Series recomendadas para la serie [id] (/tv/{id}/recommendations).
  static Future<List<SerieModel>> recomendacionesSerie(
    int id,
    String language,
  ) => _cacheRecomendaciones.obtener(
    'tv-$id-$language',
    () => _resultados('/tv/$id/recommendations', {
      'language': language,
    }, SerieModel.fromTmdbBusqueda),
  );

  /// Películas recomendadas para la película [id]
  /// (/movie/{id}/recommendations).
  static Future<List<PeliculaModel>> recomendacionesPelicula(
    int id,
    String language,
  ) => _cacheRecomendaciones.obtener(
    'movie-$id-$language',
    () => _resultados('/movie/$id/recommendations', {
      'language': language,
    }, PeliculaModel.fromTmdbBusqueda),
  );

  // Caché de las listas de géneros de TMDB (cambian muy poco).
  static final _cacheGeneros = CacheFuturos();

  /// Id de TMDB del género [nombre] para 'tv' o 'movie' (null si no
  /// existe). Se compara en español y en inglés porque la ficha puede
  /// traer el nombre de TMDB (en el idioma de la app) o de TVMaze (en
  /// inglés). Si no hay coincidencia exacta vale una parte de un género
  /// compuesto: "Action" encaja en "Action & Adventure".
  static Future<int?> _idGenero(String tipo, String nombre) async {
    final listas = await Future.wait([
      for (final language in ['es-ES', 'en-US'])
        _cacheGeneros.obtener(
          '$tipo-$language',
          () => _get('/genre/$tipo/list', parametros: {'language': language}),
        ),
    ]);
    final buscado = nombre.toLowerCase().replaceAll('-', ' ');
    final generos = [
      for (final lista in listas)
        for (final g in lista['genres'] as List<dynamic>? ?? const [])
          (id: g['id'] as int, nombre: (g['name'] as String).toLowerCase()),
    ];
    for (final g in generos) {
      if (g.nombre.replaceAll('-', ' ') == buscado) return g.id;
    }
    for (final g in generos) {
      final partes = g.nombre.split(RegExp(r' & | y '));
      if (partes.contains(buscado)) return g.id;
    }
    return null;
  }

  /// Títulos más populares del género [genero] (/discover/tv o
  /// /discover/movie), o de la palabra clave [idPalabraClave] si se da.
  /// Lista vacía si TMDB no tiene ese género.
  static Future<List<T>> _porGenero<T>(
    String tipo,
    String genero,
    String language,
    int? idPalabraClave,
    T Function(Map<String, dynamic>) desde,
  ) async {
    final id = idPalabraClave ?? await _idGenero(tipo, genero);
    if (id == null) return [];
    return _resultados('/discover/$tipo', {
      idPalabraClave == null ? 'with_genres' : 'with_keywords': '$id',
      'sort_by': 'popularity.desc',
      'language': language,
      if (tipo == 'movie') 'region': TmdbRefs.region,
    }, desde);
  }

  /// Series populares de un género o palabra clave (al tocarlo en la ficha).
  static Future<List<SerieModel>> seriesPorGenero(
    String genero,
    String language, {
    int? idPalabraClave,
  }) => _porGenero(
    'tv',
    genero,
    language,
    idPalabraClave,
    SerieModel.fromTmdbBusqueda,
  );

  /// Películas populares de un género o palabra clave (al tocarlo en la ficha).
  static Future<List<PeliculaModel>> peliculasPorGenero(
    String genero,
    String language, {
    int? idPalabraClave,
  }) => _porGenero(
    'movie',
    genero,
    language,
    idPalabraClave,
    PeliculaModel.fromTmdbBusqueda,
  );

  /// Varias páginas de /discover/{tipo} a la vez, de las más populares a
  /// las menos, hasta [maxPaginas] (20 títulos por página). La primera dice
  /// cuántas hay; el resto se piden en paralelo. Cada página se pide también
  /// en inglés: si un título no está traducido a tu idioma, TMDB devuelve el
  /// original (p. ej. en coreano) y se usa el inglés, como hace su web.
  static Future<List<T>> _descubrir<T>(
    String tipo,
    Map<String, String> parametros,
    int maxPaginas,
    T Function(Map<String, dynamic>) desde,
  ) async {
    var totalPaginas = 1; // lo dice la primera página
    Future<List<dynamic>> pagina(int n) async {
      Future<Map<String, dynamic>> en(String language) => _get(
        '/discover/$tipo',
        parametros: {
          ...parametros,
          'language': language,
          'sort_by': 'popularity.desc',
          'page': '$n',
        },
      );
      final language = parametros['language'] ?? 'en-US';
      final propia = await en(language);
      // El inglés solo se pide si algún título está sin traducir
      final resultados = propia['results'] as List<dynamic>? ?? const [];
      final ingles = resultados.any((r) => _sinTraducir(r, language))
          ? await en('en-US')
          : const <String, dynamic>{};
      if (n == 1) totalPaginas = propia['total_pages'] as int? ?? 1;
      return _conTituloIngles(propia, ingles, language);
    }

    final primera = await pagina(1);
    final resto = await Future.wait([
      for (var n = 2; n <= totalPaginas.clamp(1, maxPaginas); n++) pagina(n),
    ]);
    return [
      for (final r in [...primera, ...resto.expand((p) => p)])
        desde(r as Map<String, dynamic>),
    ];
  }

  /// ¿Tiene [texto] letras de otro alfabeto (más allá del latino)?
  static bool _otroAlfabeto(String texto) => RegExp(
    r'\p{L}',
    unicode: true,
  ).allMatches(texto).any((letra) => letra[0]!.codeUnitAt(0) > 0x24F);

  /// ¿Viene el título de [r] (película: title; serie: name) sin traducir a
  /// [language] y en otro alfabeto? (TMDB devuelve entonces el original)
  static bool _sinTraducir(dynamic r, String language) {
    if (r is! Map<String, dynamic>) return false;
    final titulo = r['title'] ?? r['name'];
    final original = r['original_title'] ?? r['original_name'];
    return titulo is String &&
        titulo == original &&
        r['original_language'] != language.substring(0, 2) &&
        _otroAlfabeto(titulo);
  }

  /// Resultados de [propia] con el título de [ingles] en los que TMDB no
  /// tiene traducción a [language] y el original no se puede leer (otro
  /// alfabeto: coreano, tailandés...). Un original en catalán o francés se
  /// deja tal cual. Vale para películas (title) y series (name).
  static List<dynamic> _conTituloIngles(
    Map<String, dynamic> propia,
    Map<String, dynamic> ingles,
    String language,
  ) {
    final enIngles = {
      for (final r in ingles['results'] as List<dynamic>? ?? const [])
        r['id']: r['title'] ?? r['name'],
    };
    return [
      for (final r in propia['results'] as List<dynamic>? ?? const [])
        if (r is Map<String, dynamic>)
          {
            ...r,
            if (_sinTraducir(r, language) && enIngles[r['id']] != null)
              r.containsKey('title') ? 'title' : 'name': enIngles[r['id']],
          },
    ];
  }

  /// Fecha 'yyyy-MM-dd' para los filtros de TMDB.
  static String _dia(DateTime fecha) =>
      fecha.toIso8601String().substring(0, 10);

  /// Disponibilidad elegida en los filtros (vacío = cualquiera).
  static Map<String, String> _disponibilidad(FiltrosEstrenos f) =>
      f.todasDisponibilidades
      ? const {}
      : {
          'with_watch_monetization_types': f.monetizacion.join('|'),
          'watch_region': TmdbRefs.region,
        };

  /// Películas que se estrenan entre las fechas de los filtros: en España
  /// todas (hasta 400; "release_date" es el estreno de allí) y en todo el
  /// mundo las 60 más populares (ahí la fecha puede ser de otro país y el
  /// controlador busca la buena con [fechasEstreno]).
  static Future<List<PeliculaModel>> estrenosPeliculas(
    FiltrosEstrenos f,
    String language,
  ) async {
    if (f.tipos.isEmpty) return [];
    return _descubrir(
      'movie',
      {
        'language': language,
        'release_date.gte': _dia(f.desde),
        'release_date.lte': _dia(f.hasta),
        'with_release_type': f.tipos.join('|'),
        if (!f.todosPaises) 'region': TmdbRefs.region,
        ..._disponibilidad(f),
      },
      f.todosPaises ? 3 : 20,
      PeliculaModel.fromTmdbBusqueda,
    );
  }

  // Caché de las fechas de estreno por país (no cambian en la sesión)
  static final _cacheFechas = CacheFuturos();

  /// Todas las fechas de estreno de la película [id], de todos los países
  /// (/movie/{id}/release_dates).
  static Future<List<FechaEstreno>> fechasEstreno(int id) =>
      _cacheFechas.obtener('fechas-$id', () async {
        final json = await _get('/movie/$id/release_dates');
        return TmdbRefs.fechasDeEstreno(json);
      });

  /// Series con algún episodio entre las fechas de los filtros o, sin
  /// "todos los episodios", solo las que empiezan en ellas. Todas las que
  /// haya, hasta 300. Para que coincida con la web, Estrenos la llama día a
  /// día cuando se quieren todos los episodios.
  static Future<List<SerieModel>> estrenosSeries(
    FiltrosEstrenos f,
    String language,
  ) {
    final campo = f.todosEpisodios ? 'air_date' : 'first_air_date';
    return _descubrir(
      'tv',
      {
        'language': language,
        '$campo.gte': _dia(f.desde),
        '$campo.lte': _dia(f.hasta),
        ..._disponibilidad(f),
      },
      15,
      SerieModel.fromTmdbBusqueda,
    );
  }

  /// Ficha de una persona (/person/{id}): biografía, nacimiento,
  /// lugar y también el IMDb anexado (external_ids) como puente.
  static Future<PersonaModel> obtenerPersona(int id, String language) async {
    final json = await _get(
      '/person/$id',
      parametros: {'language': language, 'append_to_response': 'external_ids'},
    );
    return PersonaModel.fromTmdbDetalle(json);
  }

  /// Filmografía completa de una persona (/person/{id}/combined_credits):
  /// series y películas mezcladas, con personaje y puntuación.
  /// Se ordena por fecha (más reciente primero) y se limita a 40.
  static Future<List<CreditoPersonaModel>> obtenerCreditosPersona(
    int id,
    String language,
  ) async {
    final json = await _get(
      '/person/$id/combined_credits',
      parametros: {'language': language},
    );
    final cast = json['cast'] as List<dynamic>? ?? [];
    final creditos = cast
        .map((c) => CreditoPersonaModel.fromTmdb(c as Map<String, dynamic>))
        .toList();
    creditos.sort((a, b) => b.fecha.compareTo(a.fecha));
    return creditos.length > 40 ? creditos.sublist(0, 40) : creditos;
  }

  /// Detalle de una serie (/tv/{id}): estado, temporadas, próximo episodio,
  /// puntuación, géneros y canales (credits viene anexado como reparto básico).
  /// El reparto completo se pide aparte: aggregate_credits trae a todos
  /// los actores de todas las temporadas, y credits solo a los habituales.
  /// [conReparto] false: solo los datos básicos (más ligero, p. ej. calendario).
  static Future<SerieModel> obtenerSerie(
    int id,
    String language, {
    bool conReparto = true,
  }) async {
    final parametros = <String, String>{'language': language};
    // Reparto, "dónde verlo" y palabras clave en la misma petición
    if (conReparto) {
      parametros['append_to_response'] = 'credits,watch/providers,keywords';
    }
    final json = await _get('/tv/$id', parametros: parametros);
    final serie = SerieModel.fromTmdbDetalle(json);
    if (!conReparto) return serie;
    try {
      final agregado = await _get('/tv/$id/aggregate_credits');
      final reparto = TmdbRefs.repartoDeCredits(agregado, agregado: true);
      if (reparto.isNotEmpty) {
        return serie.copyWith(reparto: reparto);
      }
    } catch (_) {
      // sin el reparto completo se queda con el de credits
    }
    return serie;
  }

  // Caché de temporadas: Estrenos pide cientos y, al volver a aplicar los
  // filtros, no se repiten.
  static final _cacheTemporadas = CacheFuturos();

  /// Episodios de una temporada (/tv/{id}/season/{n}).
  static Future<List<EpisodioModel>> obtenerEpisodiosTemporada(
    int id,
    int temporada,
    String language,
  ) => _cacheTemporadas.obtener('$id-$temporada-$language', () async {
    final json = await _get(
      '/tv/$id/season/$temporada',
      parametros: {'language': language},
    );
    final episodios = json['episodes'] as List<dynamic>? ?? [];
    return episodios.map((e) {
      final m = e as Map<String, dynamic>;
      return EpisodioModel(
        temporada: m['season_number'] as int? ?? temporada,
        numero: m['episode_number'] as int? ?? 0,
        titulo: (m['name'] as String?) ?? '',
        fechaEmision: (m['air_date'] as String?) ?? '',
      );
    }).toList();
  });

  // Caché de IDs de IMDb: el calendario y Próximamente lo piden para cada
  // serie favorita (a la vez al entrar) y nunca cambia.
  static final _cacheImdb = CacheFuturos();

  /// ID de IMDb de una serie (/tv/{id}/external_ids): puente con TVMaze.
  static Future<String?> obtenerImdbId(int id) =>
      _cacheImdb.obtener('$id', () async {
        final json = await _get('/tv/$id/external_ids');
        final imdb = (json['imdb_id'] as String?) ?? '';
        return imdb.isEmpty ? null : imdb;
      });

  /// Detalle de una película (/movie/{id}) con puntuación, géneros
  /// y reparto (credits en la misma respuesta).
  /// [conCreditos] false: solo los datos básicos (más ligero).
  static Future<PeliculaModel> obtenerPelicula(
    int id,
    String language, {
    bool conCreditos = true,
  }) async {
    final parametros = <String, String>{
      'language': language,
      // Fechas por país siempre (la de España); reparto y "dónde verlo"
      // solo con [conCreditos]. Todo en la misma petición.
      'append_to_response': conCreditos
          ? 'release_dates,credits,watch/providers,keywords'
          : 'release_dates',
    };
    final json = await _get('/movie/$id', parametros: parametros);
    return PeliculaModel.fromTmdbDetalle(json);
  }
}

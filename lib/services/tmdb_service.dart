// SERVICIO de TMDB: la API de películas y series (la fuente principal de
// la app). Es la ÚNICA que necesita API key, y esa clave la aporta
// ClaveService (guardada en la app o leída del archivo .env; nunca va
// escrita en el código). Sirve para buscar y cargar series, películas,
// personas, reparto y episodios. Cada petición lleva timeout; si la
// clave falta o está mal lanza TmdbException con la marca
// claveIncorrecta. No dibuja nada.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/episodio_model.dart';
import '../models/pelicula_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
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

  /// true si la clave no está o sigue con el texto de ejemplo del .env.
  static bool get claveFaltante => !ClaveService.hayClave;

  /// Petición GET genérica con timeout de 10 segundos.
  static Future<Map<String, dynamic>> _get(
    String ruta, {
    Map<String, String> parametros = const {},
  }) async {
    if (claveFaltante) {
      throw TmdbException('Falta la API key de TMDB', claveIncorrecta: true);
    }
    final uri = Uri.parse('$_base$ruta').replace(
      queryParameters: {...ClaveService.parametrosAuth, ...parametros},
    );
    try {
      final respuesta = await http
          .get(uri, headers: ClaveService.cabeceras)
          .timeout(_timeout);
      if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
        throw TmdbException('La API key de TMDB no es válida',
            claveIncorrecta: true);
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

  /// Busca series en TMDB (/search/tv).
  static Future<List<SerieModel>> buscarSeries(
      String consulta, String language) async {
    final json = await _get('/search/tv',
        parametros: {'query': consulta, 'language': language});
    final resultados = json['results'] as List<dynamic>? ?? [];
    return resultados
        .map((r) => SerieModel.fromTmdbBusqueda(r as Map<String, dynamic>))
        .toList();
  }

  /// Busca películas en TMDB (/search/movie).
  static Future<List<PeliculaModel>> buscarPeliculas(
      String consulta, String language) async {
    final json = await _get('/search/movie',
        parametros: {'query': consulta, 'language': language});
    final resultados = json['results'] as List<dynamic>? ?? [];
    return resultados
        .map((r) => PeliculaModel.fromTmdbBusqueda(r as Map<String, dynamic>))
        .toList();
  }

  /// Busca personas (actores, directores...) en TMDB (/search/person).
  static Future<List<PersonaModel>> buscarPersonas(
      String consulta, String language) async {
    final json = await _get('/search/person',
        parametros: {'query': consulta, 'language': language});
    final resultados = json['results'] as List<dynamic>? ?? [];
    return resultados
        .map((r) => PersonaModel.fromTmdbBusqueda(r as Map<String, dynamic>))
        .toList();
  }

  /// Ficha de una persona (/person/{id}): biografía, nacimiento,
  /// lugar y también el IMDb anexado (external_ids) como puente.
  static Future<PersonaModel> obtenerPersona(int id, String language) async {
    final json = await _get('/person/$id', parametros: {
      'language': language,
      'append_to_response': 'external_ids',
    });
    return PersonaModel.fromTmdbDetalle(json);
  }

  /// Filmografía completa de una persona (/person/{id}/combined_credits):
  /// series y películas mezcladas, con personaje y puntuación.
  /// Se ordena por fecha (más reciente primero) y se limita a 40.
  static Future<List<CreditoPersonaModel>> obtenerCreditosPersona(
      int id, String language) async {
    final json = await _get('/person/$id/combined_credits',
        parametros: {'language': language});
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
  static Future<SerieModel> obtenerSerie(int id, String language,
      {bool conReparto = true}) async {
    final parametros = <String, String>{'language': language};
    if (conReparto) parametros['append_to_response'] = 'credits';
    final json = await _get('/tv/$id', parametros: parametros);
    final serie = SerieModel.fromTmdbDetalle(json);
    if (!conReparto) return serie;
    try {
      final agregado = await _get('/tv/$id/aggregate_credits');
      final reparto = TmdbRefs.repartoDeCreditosAgregados(agregado);
      if (reparto.isNotEmpty) {
        return serie.copyWith(reparto: reparto);
      }
    } catch (_) {
      // sin el reparto completo se queda con el de credits
    }
    return serie;
  }

  /// Episodios de una temporada (/tv/{id}/season/{n}).
  static Future<List<EpisodioModel>> obtenerEpisodiosTemporada(
      int id, int temporada, String language) async {
    final json =
        await _get('/tv/$id/season/$temporada', parametros: {'language': language});
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
  }

  /// ID de IMDb de una serie (/tv/{id}/external_ids): puente con TVMaze.
  static Future<String?> obtenerImdbId(int id) async {
    final json = await _get('/tv/$id/external_ids');
    final imdb = (json['imdb_id'] as String?) ?? '';
    return imdb.isEmpty ? null : imdb;
  }

  /// Detalle de una película (/movie/{id}) con puntuación, géneros
  /// y reparto (credits en la misma respuesta).
  /// [conCreditos] false: solo los datos básicos (más ligero).
  static Future<PeliculaModel> obtenerPelicula(int id, String language,
      {bool conCreditos = true}) async {
    final parametros = <String, String>{
      'language': language,
      if (conCreditos) 'append_to_response': 'credits',
    };
    final json = await _get('/movie/$id', parametros: parametros);
    return PeliculaModel.fromTmdbDetalle(json);
  }
}

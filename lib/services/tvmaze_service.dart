// SERVICIO de TVMaze: API pública de series (sin clave, en inglés). Es la
// fuente alternativa a TMDB para series. Tiene límite de unas 20
// peticiones cada 10 segundos, así que las respeta con un control de
// ventana y guarda resultados en caché (serie, episodios y búsqueda por
// IMDb) para no repetirlas. Cada petición lleva timeout. No dibuja nada.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/episodio_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
import 'cache_futuros.dart';

/// Conexión con la API de TVMaze: solo series, en inglés y sin API key.
/// Límite: unas 20 peticiones cada 10 segundos, así que se respeta el
/// límite y se guardan resultados en caché para no repetirlos.
class TvmazeService {
  static const String _base = 'https://api.tvmaze.com';
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxPeticiones = 20;
  static const Duration _ventana = Duration(seconds: 10);

  // Historial de peticiones recientes para respetar el límite.
  static final List<DateTime> _historial = [];

  // Caché de peticiones (serie, episodios, búsqueda por IMDb, personas):
  // dos pantallas que piden lo mismo a la vez comparten la petición.
  static final _cache = CacheFuturos();

  /// Espera si se han hecho demasiadas peticiones en los últimos 10 s.
  static Future<void> _respetarLimite() async {
    while (true) {
      final ahora = DateTime.now();
      _historial.removeWhere((f) => ahora.difference(f) >= _ventana);
      if (_historial.length < _maxPeticiones) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    _historial.add(DateTime.now());
  }

  /// Petición GET con timeout de 10 segundos.
  /// Devuelve null si la API responde 404 (no encontrado).
  static Future<dynamic> _get(String ruta) async {
    await _respetarLimite();
    final http.Response respuesta;
    try {
      respuesta = await http.get(Uri.parse('$_base$ruta')).timeout(_timeout);
    } catch (e) {
      throw Exception('Sin conexión con TVMaze: $e');
    }
    if (respuesta.statusCode == 404) return null;
    if (respuesta.statusCode != 200) {
      throw Exception('TVMaze devolvió el código ${respuesta.statusCode}');
    }
    return jsonDecode(respuesta.body);
  }

  /// Busca series en TVMaze (/search/shows?q=).
  static Future<List<SerieModel>> buscarSeries(String consulta) async {
    final datos = await _get(
      '/search/shows?q=${Uri.encodeQueryComponent(consulta)}',
    );
    if (datos == null) return [];
    return (datos as List<dynamic>)
        .map((e) => SerieModel.fromTvmaze(e as Map<String, dynamic>))
        .toList();
  }

  /// Busca personas en TVMaze (/search/people?q=).
  /// La respuesta envuelve cada persona dentro de la clave 'person'.
  static Future<List<PersonaModel>> buscarPersonas(String consulta) async {
    final datos = await _get(
      '/search/people?q=${Uri.encodeQueryComponent(consulta)}',
    );
    if (datos == null) return [];
    final personas = <PersonaModel>[];
    for (final e in datos as List<dynamic>) {
      final personaJson = (e as Map<String, dynamic>)['person'];
      if (personaJson is Map<String, dynamic>) {
        personas.add(PersonaModel.fromTvmaze(personaJson));
      }
    }
    return personas;
  }

  /// Persona con su ficha (/people/{id}), con caché.
  static Future<PersonaModel?> obtenerPersona(int id) =>
      _cache.obtener('persona-$id', () async {
        final datos = await _get('/people/$id');
        return datos == null
            ? null
            : PersonaModel.fromTvmaze(datos as Map<String, dynamic>);
      });

  /// Series en las que ha actuado (/people/{id}/castcredits?embed[]=show),
  /// con caché. El personaje viene en _links.character.name.
  static Future<List<CreditoPersonaModel>> obtenerCreditosPersona(int id) =>
      _cache.obtener('creditos-persona-$id', () async {
        final datos = await _get('/people/$id/castcredits?embed[]=show');
        if (datos == null) return <CreditoPersonaModel>[];
        final creditos = <CreditoPersonaModel>[];
        for (final e in datos as List<dynamic>) {
          final m = e as Map<String, dynamic>;
          final embebido = m['_embedded'];
          final show = (embebido is Map<String, dynamic>)
              ? embebido['show']
              : null;
          if (show is! Map<String, dynamic>) continue;
          final enlaces = m['_links'];
          final personajeJson = (enlaces is Map<String, dynamic>)
              ? enlaces['character']
              : null;
          final personaje = (personajeJson is Map<String, dynamic>)
              ? (personajeJson['name'] as String? ?? '')
              : '';
          creditos.add(CreditoPersonaModel.fromTvmaze(show, personaje));
        }
        creditos.sort((a, b) => b.fecha.compareTo(a.fecha));
        return creditos;
      });

  /// Serie con su siguiente episodio, canales y reparto
  /// (/shows/{id}?embed[]=nextepisode&embed[]=cast).
  static Future<SerieModel?> obtenerSerie(int id) =>
      _serie('serie-$id', '/shows/$id?embed[]=nextepisode&embed[]=cast');

  /// Busca una serie por su ID de IMDb (/lookup/shows?imdb=).
  /// Es el puente para enlazar la misma serie con TMDB.
  static Future<SerieModel?> buscarPorImdb(String imdbId) => _serie(
    'imdb-$imdbId',
    '/lookup/shows?imdb=${Uri.encodeQueryComponent(imdbId)}',
  );

  /// Una serie de [ruta] con caché por [clave]; null si TVMaze no la tiene.
  static Future<SerieModel?> _serie(String clave, String ruta) =>
      _cache.obtener(clave, () async {
        final datos = await _get(ruta);
        return datos == null
            ? null
            : SerieModel.fromTvmaze(datos as Map<String, dynamic>);
      });

  /// Todos los episodios de una serie (/shows/{id}/episodes), con caché.
  static Future<List<EpisodioModel>> obtenerEpisodios(int id) =>
      _cache.obtener('episodios-$id', () async {
        final datos = await _get('/shows/$id/episodes');
        if (datos == null) return <EpisodioModel>[];
        return (datos as List<dynamic>).map((e) {
          final m = e as Map<String, dynamic>;
          return EpisodioModel(
            temporada: m['season'] as int? ?? 0,
            numero: m['number'] as int? ?? 0,
            titulo: (m['name'] as String?) ?? '',
            fechaEmision: (m['airdate'] as String?) ?? '',
            horaEmision: (m['airtime'] as String?) ?? '',
          );
        }).toList();
      });
}

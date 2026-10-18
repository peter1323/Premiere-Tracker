import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/manga_model.dart';

/// Conexión con la API pública de AniList (GraphQL): datos y estado de los
/// mangas (emisión, finalizado, parado, cancelado). No necesita API key.
/// Límite generoso (unas 90 peticiones por minuto) y caché de búsquedas.
class AnilistService {
  static const String _base = 'https://graphql.anilist.co';
  static const Duration _timeout = Duration(seconds: 10);

  // Caché de búsquedas repetidas (texto en minúsculas -> resultados).
  static final Map<String, List<MangaModel>> _cache = {};

  // Campos que necesita la ficha: compartidos entre la búsqueda y la carga
  // por id, para no repetirlos.
  static const String _campos = '''
        id
        title { romaji english native }
        description(asHtml: false)
        status
        chapters
        volumes
        averageScore
        format
        countryOfOrigin
        genres
        staff(perPage: 6, sort: [RELEVANCE]) {
          edges {
            node { name { full } }
          }
        }
        siteUrl
        startDate { year month day }
        coverImage { large extraLarge }
  ''';

  static final String _consulta = '''
  query (\$search: String, \$format_in: [MediaFormat]) {
    Page(page: 1, perPage: 20) {
      media(type: MANGA, search: \$search, format_in: \$format_in, sort: SEARCH_MATCH) {
$_campos
      }
    }
  }
  ''';

  // Ficha completa por id: para abrir un manga desde Favoritos o Vistos.
  static final String _consultaPorId = '''
  query (\$id: Int) {
    Media(id: \$id, type: MANGA) {
$_campos
    }
  }
  ''';

  /// Busca cómics o novelas por nombre. En AniList manga, manhwa, manhua y
  /// novelas son todos type: MANGA y lo que los separa es el formato, así
  /// que se filtra por [formatos]: 'MANGA'+'ONE_SHOT' da los cómics y
  /// 'NOVEL' las novelas ligeras. Lanza excepción si no hay conexión.
  static Future<List<MangaModel>> buscarMangas(
    String texto,
    List<String> formatos,
  ) async {
    final busqueda = texto.trim();
    if (busqueda.isEmpty) return [];
    // La caché guarda por formato: el mismo título como cómic y como novela
    // son dos resultados distintos.
    final clave = '${formatos.join('_')}_${busqueda.toLowerCase()}';
    final guardado = _cache[clave];
    if (guardado != null) return guardado;

    final respuesta = await http
        .post(
          Uri.parse(_base),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': _consulta,
            'variables': {'search': busqueda, 'format_in': formatos},
          }),
        )
        .timeout(_timeout);

    if (respuesta.statusCode != 200) {
      throw Exception('AniList no responde');
    }
    final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final lista = datos['data']?['Page']?['media'] as List?;
    if (lista == null) {
      // Si GraphQL devuelve errores (p. ej. consulta rechazada).
      throw Exception('Respuesta incorrecta de AniList');
    }

    final mangas = lista
        .map((e) => MangaModel.fromAniList(e as Map<String, dynamic>))
        .toList();
    _cache[clave] = mangas;
    return mangas;
  }

  /// Carga una ficha completa de AniList por su id (para abrir un manga
  /// guardado en favoritos o vistos sin buscarlo por nombre).
  /// Lanza excepción si no se encuentra o no hay conexión.
  static Future<MangaModel> cargarManga(int id) async {
    final respuesta = await http
        .post(
          Uri.parse(_base),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': _consultaPorId,
            'variables': {'id': id},
          }),
        )
        .timeout(_timeout);

    if (respuesta.statusCode != 200) {
      throw Exception('AniList no responde');
    }
    final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final media = datos['data']?['Media'];
    if (media == null) {
      throw Exception('Manga no encontrado en AniList');
    }
    return MangaModel.fromAniList(media as Map<String, dynamic>);
  }
}

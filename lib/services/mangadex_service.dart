// SERVICIO de MangaDex: la API pública (sin clave) que se usa para
// enriquecer la ficha de un manga con el último capítulo publicado en cada
// idioma (español de España, español latino e inglés) y, si existe, la
// sinopsis en español. Tiene límite de 5 peticiones por segundo (respeta
// 4/s de margen), caché en memoria y timeout; si algo falla devuelve «no
// hay datos» en lugar de lanzar error. No dibuja nada.
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Capítulo de un idioma concreto en MangaDex: [numero] (p. ej. '47'; puede
/// ser null si el capítulo no tiene número), [fecha] de publicación (ISO) e
/// [idioma] ('es', 'es-la', 'en'...). null = ese idioma no tiene datos.
typedef CapituloManga = ({String? numero, String fecha, String idioma});

/// Datos de MangaDex para una ficha: el último capítulo de cada idioma y la
/// sinopsis en español si la tiene (si no, null -> se usa la de AniList).
typedef ResultadoMangadex = ({
  Map<String, CapituloManga?> capitulos,
  String? sinopsisEs,
});

/// Conexión con la API pública de MangaDex: se usa para saber el último
/// capítulo publicado en cada idioma (español de España, español latino e
/// inglés). No necesita API key. Límite: 5 peticiones por segundo; se
/// respeta con un control por ventana y caché en memoria.
class MangadexService {
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxPeticiones = 4; // margen bajo el límite real de 5/s
  static const Duration _ventana = Duration(seconds: 1);

  /// Idiomas que se muestran en la ficha, en el orden en que se piden.
  /// MangaDex no separa el inglés de EE. UU. y del Reino Unido: solo 'en'.
  static const List<String> _idiomasFicha = ['es', 'es-la', 'en'];

  // Historial de peticiones recientes para respetar el límite.
  static final List<DateTime> _historial = [];

  // Caché: título normalizado -> datos completos (capítulos y sinopsis).
  static final Map<String, ResultadoMangadex> _cache = {};

  /// Espera si se han hecho demasiadas peticiones en el último segundo.
  static Future<void> _respetarLimite() async {
    while (true) {
      final ahora = DateTime.now();
      _historial.removeWhere((f) => ahora.difference(f) > _ventana);
      if (_historial.length < _maxPeticiones) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _historial.add(DateTime.now());
  }

  /// Quita mayúsculas, tildes y signos para comparar títulos entre sí
  /// (los títulos llegan en japonés, inglés o con tildes).
  static String _normalizar(String texto) {
    final conTildes = 'áéíóúüñàèìòùâêîôûç';
    final sinTildes = 'aeiouunaeiouaeiouc';
    final limpio = texto.toLowerCase().split('').map((letra) {
      final i = conTildes.indexOf(letra);
      return i >= 0 ? sinTildes[i] : letra;
    }).join();
    return limpio
        .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(' +'), ' ')
        .trim();
  }

  /// Último capítulo por idioma de [_idiomasFicha] + sinopsis en español.
  /// Si un idioma no tiene capítulos (o MangaDex no conoce el manga, o falla
  /// la conexión), ese idioma queda en null y la vista lo muestra como
  /// «No hay datos en ese idioma».
  static Future<ResultadoMangadex> buscarDatosManga(String titulo) async {
    final sinDatos = <String, CapituloManga?>{
      for (final i in _idiomasFicha) i: null,
    };
    final ResultadoMangadex vacio = (capitulos: sinDatos, sinopsisEs: null);
    final clave = _normalizar(titulo);
    if (clave.isEmpty) return vacio;
    final guardado = _cache[clave];
    if (guardado != null) return guardado;

    try {
      // 1) Buscar el manga en MangaDex por título y quedarnos con el que
      //    más se parezca (títulos con tildes o kanji hacen falta comparar).
      await _respetarLimite();
      final uriManga = Uri.https('api.mangadex.org', '/manga', {
        'title': titulo,
        'limit': '5',
        'order[relevance]': 'desc',
      });
      final resManga = await http.get(uriManga).timeout(_timeout);
      if (resManga.statusCode != 200) return vacio;
      final datosManga = jsonDecode(resManga.body) as Map<String, dynamic>;
      final lista = datosManga['data'] as List?;
      if (lista == null || lista.isEmpty) return vacio;

      final mejor = _mejorCoincidencia(lista, clave);
      if (mejor == null) return vacio;
      final idMdx = mejor['id'] as String;

      // La sinopsis en español viene en esta misma respuesta (descriptions
      // por idioma): se aprovecha, sin peticiones extra.
      final sinopsisEs = _sinopsisEs(mejor);

      // 2) Un capítulo por idioma (petición aparte, siempre el más reciente
      //    de ese idioma). Sin datos de un idioma -> null, sin cortar el resto.
      final resultado = <String, CapituloManga?>{};
      for (final idioma in _idiomasFicha) {
        await _respetarLimite();
        final uriCap = Uri.https('api.mangadex.org', '/chapter', {
          'manga': idMdx,
          'translatedLanguage[]': [idioma],
          'order[publishAt]': 'desc',
          'limit': '1',
        });
        final resCap = await http.get(uriCap).timeout(_timeout);
        if (resCap.statusCode != 200) {
          resultado[idioma] = null;
          continue;
        }
        final datosCap = jsonDecode(resCap.body) as Map<String, dynamic>;
        final caps = datosCap['data'] as List?;
        if (caps == null || caps.isEmpty) {
          resultado[idioma] = null;
          continue;
        }
        final atributos = caps[0]['attributes'] as Map<String, dynamic>?;
        resultado[idioma] = (
          numero: atributos?['chapter'] as String?,
          fecha: atributos?['publishAt'] as String? ?? '',
          idioma: idioma,
        );
      }

      final datos = (capitulos: resultado, sinopsisEs: sinopsisEs);
      // Solo se cachea si hubo algún dato; si no, para que una segunda
      // apertura vuelva a intentarlo.
      if (resultado.values.any((v) => v != null) || sinopsisEs != null) {
        _cache[clave] = datos;
      }
      return datos;
    } catch (_) {
      // Sin conexión o respuesta rara: todo «no hay datos».
      return vacio;
    }
  }

  /// Sinopsis en español de MangaDex ('es' de España, si no 'es-la' latino),
  /// ya limpia de markdown; null si el manga no la tiene.
  static String? _sinopsisEs(Map<String, dynamic> manga) {
    final atributos = manga['attributes'] as Map<String, dynamic>?;
    final descripcion = atributos?['description'];
    if (descripcion is! Map) return null;
    for (final codigo in ['es', 'es-la']) {
      final texto = descripcion[codigo];
      if (texto is String && texto.trim().isNotEmpty) {
        return _limpiarMarkdown(texto);
      }
    }
    return null;
  }

  /// Quita el markdown que trae MangaDex (negritas, cursivas y enlaces).
  static String _limpiarMarkdown(String texto) => texto
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
      .replaceAll('*', '')
      .replaceAll('_', '')
      .replaceAll('~', '')
      .trim();

  /// Elige el manga que más se parezca al título buscado entre los
  /// candidatos de MangaDex (compara título y títulos alternativos).
  /// Devuelve el manga entero de la lista, para poder leer su sinopsis.
  static Map<String, dynamic>? _mejorCoincidencia(
    List<dynamic> lista,
    String clave,
  ) {
    Map<String, dynamic>? exacto;
    Map<String, dynamic>? parcial;
    for (final item in lista) {
      final atributos = item['attributes'] as Map<String, dynamic>?;
      final titulos = <String>[
        ...((atributos?['title'] as Map<String, dynamic>?)?.values ?? []),
        ...((atributos?['altTitles'] as List?)
                ?.expand((e) => (e as Map).values.cast<String>()) ??
            []),
      ];
      for (final t in titulos) {
        final n = _normalizar(t);
        if (n == clave) {
          exacto = item;
          break;
        }
        if (n.contains(clave) || clave.contains(n)) {
          parcial ??= item;
        }
      }
      if (exacto != null) break;
    }
    return exacto ??
        parcial ??
        (lista.isEmpty ? null : lista.first as Map<String, dynamic>);
  }
}

/// Modelo de un manga según los datos de AniList.
///
/// [estado] guarda el estado en español: 'emision', 'finalizado', 'parado',
/// 'cancelado' o 'proximamente'. La puntuación de AniList viene de 0 a 100
/// y aquí se guarda ya convertida a 0-10.
class MangaModel {
  final int id;
  final String titulo; // romaji (título original japonés)
  final String? tituloEnglish;
  final String sinopsis;
  final String estado;
  final int? capitulos;
  final int? tomos;
  final double? puntuacion;
  final String formato; // MANGA, NOVEL, ONE_SHOT...
  final String pais; // JP, KR, CN, TW...
  final List<String> generos;
  final List<String>
  etiquetas; // etiquetas de AniList sin destripes (Time Skip...)
  final List<String> autores; // guionistas y artistas (AniList staff)
  final String fechaInicio; // 'YYYY-MM-DD' o ''
  final String portada;
  final String url; // ficha en AniList

  const MangaModel({
    required this.id,
    required this.titulo,
    this.tituloEnglish,
    required this.sinopsis,
    required this.estado,
    this.capitulos,
    this.tomos,
    this.puntuacion,
    this.formato = '',
    this.pais = '',
    this.generos = const [],
    this.etiquetas = const [],
    this.autores = const [],
    this.fechaInicio = '',
    this.portada = '',
    this.url = '',
  });

  /// Convierte la respuesta JSON del GraphQL de AniList en un manga.
  /// Quita etiquetas HTML de la sinopsis que a veces trae AniList.
  factory MangaModel.fromAniList(Map<String, dynamic> json) {
    final titulo =
        json['title']?['romaji'] ??
        json['title']?['english'] ??
        json['title']?['native'] ??
        '';
    final sinopsis = (json['description'] as String? ?? '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp('<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .trim();
    final score = json['averageScore'] as num?;
    return MangaModel(
      id: json['id'] as int,
      titulo: titulo,
      tituloEnglish: json['title']?['english'] as String?,
      sinopsis: sinopsis,
      estado: _estadoDesdeAniList(json['status'] as String?),
      capitulos: json['chapters'] as int?,
      tomos: json['volumes'] as int?,
      puntuacion: score == null ? null : score.toDouble() / 10,
      formato: json['format'] as String? ?? '',
      pais: json['countryOfOrigin'] as String? ?? '',
      generos: List<String>.from(json['genres'] as List? ?? []),
      etiquetas: _etiquetas(json['tags'] as List?),
      autores: _autores(json['staff'] as Map<String, dynamic>?),
      fechaInicio: _fecha(json['startDate'] as Map<String, dynamic>?),
      portada:
          json['coverImage']?['large'] ??
          json['coverImage']?['extraLarge'] ??
          '',
      url: json['siteUrl'] as String? ?? '',
    );
  }

  /// Traduce el estado de AniList (RELEASING, FINISHED...) a nuestro texto.
  static String _estadoDesdeAniList(String? estado) {
    switch (estado) {
      case 'RELEASING':
        return 'emision';
      case 'FINISHED':
        return 'finalizado';
      case 'HIATUS':
        return 'parado';
      case 'CANCELLED':
        return 'cancelado';
      case 'NOT_YET_RELEASED':
        return 'proximamente';
      default:
        return '';
    }
  }

  /// Nombres de los autores (equipo creativo) sin repetir los que
  /// aparecen con más de un papel (p. ej. guion y arte).
  static List<String> _autores(Map<String, dynamic>? staff) {
    final edges = staff?['edges'] as List? ?? [];
    final nombres = <String>[];
    for (final e in edges) {
      final nombre = ((e as Map)['node']?['name']?['full']) as String?;
      if (nombre != null && nombre.isNotEmpty && !nombres.contains(nombre)) {
        nombres.add(nombre);
      }
    }
    return nombres;
  }

  /// Monta la fecha de inicio 'YYYY-MM-DD' (devuelve '' si falta el año).
  /// Etiquetas que AniList considera relevantes (rank >= 60) y que no
  /// destripan la historia; como mucho 8 para no llenar la ficha.
  static List<String> _etiquetas(List? tags) => [
    for (final e in tags ?? const [])
      if (e is Map &&
          e['isMediaSpoiler'] != true &&
          (e['rank'] as int? ?? 0) >= 60)
        e['name'] as String,
  ].take(8).toList();

  static String _fecha(Map<String, dynamic>? f) {
    final anio = f?['year'] as int?;
    if (anio == null) return '';
    final mes = (f?['month'] as int? ?? 1).toString().padLeft(2, '0');
    final dia = (f?['day'] as int? ?? 1).toString().padLeft(2, '0');
    return '$anio-$mes-$dia';
  }
}

/// Separa de una sinopsis el crédito de origen para mostrarlo siempre igual
/// debajo: AniList lo pone al final como "(Source: MANGA Plus)" y MangaDex
/// como líneas que solo son un enlace (el servicio ya las deja con ese
/// mismo formato). Devuelve el texto sin el crédito y sin saltos de línea
/// de sobra, y los créditos juntos (null si no había).
({String texto, String? credito}) separarCredito(String sinopsis) {
  final creditos = <String>[];
  final texto = sinopsis
      .replaceAllMapped(
        RegExp(
          r'\(\s*source:\s*([^()]*(?:\([^()]*\)[^()]*)*)\)',
          caseSensitive: false,
        ),
        (m) {
          creditos.add(m[1]!.trim());
          return '';
        },
      )
      .replaceAll(RegExp(r'(\n[ \t]*){3,}'), '\n\n')
      .trim();
  return (texto: texto, credito: creditos.isEmpty ? null : creditos.join(', '));
}

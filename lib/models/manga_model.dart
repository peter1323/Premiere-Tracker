/// Modelo de un manga según los datos de AniList.
///
/// [estado] guarda el estado en español: 'emision', 'finalizado', 'parado',
/// 'cancelado' o 'proximamente'. La puntuación de AniList viene de 0 a 100
/// y aquí se guarda ya convertida a 0-10.
class MangaModel {
  final int id;
  final String titulo; // romaji (título original japonés)
  final String? tituloEnglish;
  final String? tituloNative;
  final String sinopsis;
  final String estado;
  final int? capitulos;
  final int? tomos;
  final double? puntuacion;
  final String formato; // MANGA, NOVEL, ONE_SHOT...
  final String pais; // JP, KR, CN, TW...
  final List<String> generos;
  final List<String> autores; // guionistas y artistas (AniList staff)
  final String fechaInicio; // 'YYYY-MM-DD' o ''
  final String portada;
  final String url; // ficha en AniList

  const MangaModel({
    required this.id,
    required this.titulo,
    this.tituloEnglish,
    this.tituloNative,
    required this.sinopsis,
    required this.estado,
    this.capitulos,
    this.tomos,
    this.puntuacion,
    this.formato = '',
    this.pais = '',
    this.generos = const [],
    this.autores = const [],
    this.fechaInicio = '',
    this.portada = '',
    this.url = '',
  });

  /// Convierte la respuesta JSON del GraphQL de AniList en un manga.
  /// Quita etiquetas HTML de la sinopsis que a veces trae AniList.
  factory MangaModel.fromAniList(Map<String, dynamic> json) {
    final titulo = json['title']?['romaji'] ??
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
      tituloNative: json['title']?['native'] as String?,
      sinopsis: sinopsis,
      estado: _estadoDesdeAniList(json['status'] as String?),
      capitulos: json['chapters'] as int?,
      tomos: json['volumes'] as int?,
      puntuacion: score == null ? null : score.toDouble() / 10,
      formato: json['format'] as String? ?? '',
      pais: json['countryOfOrigin'] as String? ?? '',
      generos: List<String>.from(json['genres'] as List? ?? []),
      autores: _autores(json['staff'] as Map<String, dynamic>?),
      fechaInicio: _fecha(json['startDate'] as Map<String, dynamic>?),
      portada: json['coverImage']?['large'] ??
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
  static String _fecha(Map<String, dynamic>? f) {
    final anio = f?['year'] as int?;
    if (anio == null) return '';
    final mes = (f?['month'] as int? ?? 1).toString().padLeft(2, '0');
    final dia = (f?['day'] as int? ?? 1).toString().padLeft(2, '0');
    return '$anio-$mes-$dia';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'tituloEnglish': tituloEnglish,
        'tituloNative': tituloNative,
        'sinopsis': sinopsis,
        'estado': estado,
        'capitulos': capitulos,
        'tomos': tomos,
        'puntuacion': puntuacion,
        'formato': formato,
        'pais': pais,
        'generos': generos,
        'autores': autores,
        'fechaInicio': fechaInicio,
        'portada': portada,
        'url': url,
      };
}

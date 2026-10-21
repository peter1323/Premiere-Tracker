// MODELO de una serie (sus datos vienen de TMDB o TVMaze). Normaliza el
// estado a unos valores fijos (en_emision, finalizada, cancelada...),
// agrupa las temporadas y guarda el reparto y el próximo episodio. Solo
// campos y conversiones JSON↔objeto; no hace red ni dibuja. Aquí vive
// también TmdbRefs, la tabla de traducción de los nombres de género y
// cargo de TMDB a texto de la app.
import 'episodio_model.dart';
import 'reparto_model.dart';

/// Serie de TMDB o TVMaze.
class SerieModel {
  // Estados normalizados que entiende la app
  static const String estadoEnEmision = 'en_emision';
  static const String estadoFinalizada = 'finalizada';
  static const String estadoCancelada = 'cancelada';
  static const String estadoEnProduccion = 'en_produccion';
  static const String estadoPlaneada = 'planeada';
  static const String estadoDesconocida = 'desconocida';

  final int id;
  final String fuente; // 'tmdb' o 'tvmaze'
  final String? imdbId;
  final String titulo;
  final String sinopsis;
  final String estado; // uno de los estados normalizados de arriba
  final String fechaEstreno; // 'yyyy-MM-dd' o ''
  final String? posterUrl;
  final List<TemporadaModel> temporadas;
  final EpisodioModel? proximoEpisodio;
  final double? puntuacion; // nota media 0-10 (null si no hay)
  final List<String> generos; // p. ej. Acción, Aventura...
  final List<String> canales; // canales/redes donde se emite
  final List<RepartoModel> reparto;
  final DondeVer? dondeVer; // plataformas en España (solo TMDB)

  const SerieModel({
    required this.id,
    required this.fuente,
    this.imdbId,
    required this.titulo,
    this.sinopsis = '',
    this.estado = estadoDesconocida,
    this.fechaEstreno = '',
    this.posterUrl,
    this.temporadas = const [],
    this.proximoEpisodio,
    this.puntuacion,
    this.generos = const [],
    this.canales = const [],
    this.reparto = const [],
    this.dondeVer,
  });

  /// Año de estreno, o null si no hay fecha.
  int? get anio => fechaEstreno.length >= 4
      ? int.tryParse(fechaEstreno.substring(0, 4))
      : null;

  SerieModel copyWith({
    String? imdbId,
    String? sinopsis,
    String? estado,
    String? posterUrl,
    List<TemporadaModel>? temporadas,
    EpisodioModel? proximoEpisodio,
    double? puntuacion,
    List<String>? generos,
    List<String>? canales,
    List<RepartoModel>? reparto,
  }) {
    return SerieModel(
      id: id,
      fuente: fuente,
      imdbId: imdbId ?? this.imdbId,
      titulo: titulo,
      sinopsis: sinopsis ?? this.sinopsis,
      estado: estado ?? this.estado,
      fechaEstreno: fechaEstreno,
      posterUrl: posterUrl ?? this.posterUrl,
      temporadas: temporadas ?? this.temporadas,
      proximoEpisodio: proximoEpisodio ?? this.proximoEpisodio,
      puntuacion: puntuacion ?? this.puntuacion,
      generos: generos ?? this.generos,
      canales: canales ?? this.canales,
      reparto: reparto ?? this.reparto,
      dondeVer: dondeVer,
    );
  }

  /// Serie a partir de un resultado de búsqueda de TMDB (/search/tv).
  factory SerieModel.fromTmdbBusqueda(Map<String, dynamic> json) {
    return SerieModel(
      id: json['id'] as int? ?? 0,
      fuente: 'tmdb',
      titulo: (json['name'] as String?) ?? '',
      sinopsis: (json['overview'] as String?) ?? '',
      fechaEstreno: (json['first_air_date'] as String?) ?? '',
      posterUrl:
          TmdbRefs.urlImagen(json['poster_path'] as String?),
    );
  }

  /// Serie a partir del detalle de TMDB (/tv/{id}).
  /// El servicio añade el reparto con append_to_response=credits.
  factory SerieModel.fromTmdbDetalle(Map<String, dynamic> json) {
    // Próximo episodio a emitir (next_episode_to_air)
    final proximo = json['next_episode_to_air'] as Map<String, dynamic>?;
    return SerieModel(
      id: json['id'] as int? ?? 0,
      fuente: 'tmdb',
      titulo: (json['name'] as String?) ?? '',
      sinopsis: (json['overview'] as String?) ?? '',
      estado: _normalizarEstadoTmdb(json['status'] as String?),
      fechaEstreno: (json['first_air_date'] as String?) ?? '',
      posterUrl: TmdbRefs.urlImagen(json['poster_path'] as String?),
      puntuacion: (json['vote_average'] as num?)?.toDouble(),
      generos: TmdbRefs.nombresDeLista(json['genres']),
      canales: TmdbRefs.nombresDeLista(json['networks']),
      reparto: TmdbRefs.repartoDeCredits(json['credits']),
      dondeVer: TmdbRefs.dondeVerDe(json['watch/providers']),
      temporadas: (json['seasons'] as List<dynamic>? ?? [])
          .map((s) => TemporadaModel.fromTmdb(s as Map<String, dynamic>))
          .toList(),
      proximoEpisodio: proximo == null
          ? null
          : EpisodioModel(
              temporada: proximo['season_number'] as int? ?? 0,
              numero: proximo['episode_number'] as int? ?? 0,
              titulo: (proximo['name'] as String?) ?? '',
              fechaEmision: (proximo['air_date'] as String?) ?? '',
            ),
    );
  }

  /// Serie a partir de un JSON de TVMaze.
  /// Acepta tanto el envuelto en 'show' (búsqueda) como el directo.
  /// El reparto y el próximo episodio llegan con embed[]=nextepisode&embed[]=cast.
  factory SerieModel.fromTvmaze(Map<String, dynamic> json) {
    final m = json['show'] is Map<String, dynamic>
        ? json['show'] as Map<String, dynamic>
        : json;
    final externals = m['externals'] as Map<String, dynamic>?;
    final proximo = (m['_embedded']?['nextepisode'] as Map<String, dynamic>?);
    final rating = m['rating'];
    final network = m['network'];
    final webChannel = m['webChannel'];
    return SerieModel(
      id: m['id'] as int? ?? 0,
      fuente: 'tvmaze',
      imdbId: externals?['imdb'] as String?,
      titulo: (m['name'] as String?) ?? '',
      sinopsis: _quitarHtml(m['summary'] as String?),
      estado: _normalizarEstadoTvmaze(m['status'] as String?),
      fechaEstreno: (m['premiered'] as String?) ?? '',
      posterUrl: (m['image']?['medium'] as String?) ??
          (m['image']?['original'] as String?),
      puntuacion: (rating is Map<String, dynamic>
              ? (rating['average'] as num?)
              : null)
          ?.toDouble(),
      generos: (m['genres'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      // Canal de televisión (network) o plataforma web (webChannel)
      canales: [
        if (network is Map<String, dynamic> &&
            ((network['name'] as String?)?.isNotEmpty ?? false))
          network['name'] as String,
        if (webChannel is Map<String, dynamic> &&
            ((webChannel['name'] as String?)?.isNotEmpty ?? false))
          webChannel['name'] as String,
      ],
      reparto: _repartoTvmaze(m['_embedded']),
      proximoEpisodio: proximo == null
          ? null
          : EpisodioModel(
              temporada: proximo['season'] as int? ?? 0,
              numero: proximo['number'] as int? ?? 0,
              titulo: (proximo['name'] as String?) ?? '',
              fechaEmision: (proximo['airdate'] as String?) ?? '',
              horaEmision: (proximo['airtime'] as String?) ?? '',
            ),
    );
  }

  /// Quita las etiquetas HTML del texto de TVMaze.
  static String _quitarHtml(String? texto) {
    if (texto == null) return '';
    return texto.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Reparto de TVMaze (viene en _embedded.cast gracias a embed[]=cast).
  static List<RepartoModel> _repartoTvmaze(dynamic embedded) {
    if (embedded is! Map<String, dynamic>) return const [];
    final cast = embedded['cast'];
    if (cast is! List) return const [];
    final reparto = <RepartoModel>[];
    for (final e in cast) {
      if (e is! Map<String, dynamic>) continue;
      final person = e['person'];
      if (person is! Map<String, dynamic>) continue;
      final nombre = (person['name'] as String?) ?? '';
      if (nombre.isEmpty) continue;
      final imagen = person['image'];
      final personaje = e['character'];
      reparto.add(RepartoModel(
        nombre: nombre,
        personaje: personaje is Map<String, dynamic>
            ? (personaje['name'] as String? ?? '')
            : '',
        fotoUrl: imagen is Map<String, dynamic>
            ? ((imagen['original'] as String?) ?? (imagen['medium'] as String?))
            : null,
        // id de la persona en TVMaze (para abrir su ficha al pinchar)
        idPersona: person['id'] as int?,
        fuente: 'tvmaze',
      ));
    }
    return reparto;
  }

  static String _normalizarEstadoTmdb(String? estado) {
    switch (estado) {
      case 'Returning Series':
        return estadoEnEmision;
      case 'Ended':
        return estadoFinalizada;
      case 'Canceled':
        return estadoCancelada;
      case 'In Production':
        return estadoEnProduccion;
      case 'Planned':
        return estadoPlaneada;
      default:
        return estadoDesconocida;
    }
  }

  static String _normalizarEstadoTvmaze(String? estado) {
    switch (estado) {
      case 'Running':
        return estadoEnEmision;
      case 'Ended':
        return estadoFinalizada;
      case 'In Development':
        return estadoEnProduccion;
      case 'To Be Determined':
        return estadoDesconocida;
      default:
        return estadoDesconocida;
    }
  }
}

/// Temporada de una serie (con sus episodios cuando se cargan).
class TemporadaModel {
  final int numero;
  final String nombre;
  final String fechaEstreno; // 'yyyy-MM-dd' o ''
  final int totalEpisodios;
  final List<EpisodioModel> episodios;

  const TemporadaModel({
    required this.numero,
    this.nombre = '',
    this.fechaEstreno = '',
    this.totalEpisodios = 0,
    this.episodios = const [],
  });

  /// Temporada a partir del array "seasons" de TMDB.
  factory TemporadaModel.fromTmdb(Map<String, dynamic> json) {
    return TemporadaModel(
      numero: json['season_number'] as int? ?? 0,
      nombre: (json['name'] as String?) ?? '',
      fechaEstreno: (json['air_date'] as String?) ?? '',
      totalEpisodios: json['episode_count'] as int? ?? 0,
    );
  }
}

/// Dónde ver una obra en España (datos de JustWatch que da TMDB):
/// [enlace] a la página de TMDB con todas las opciones y las
/// [plataformas] con su nombre y logo.
typedef DondeVer = ({
  String enlace,
  List<({String nombre, String? logo})> plataformas,
});

/// Utilidades compartidas de TMDB para los modelos: URLs de imágenes
/// y lecturas de la respuesta de detalle (géneros, redes, reparto).
class TmdbRefs {
  static const String _baseImagenes = 'https://image.tmdb.org/t/p/';

  /// Construye la URL completa de una imagen desde su ruta relativa.
  /// [tamano]: 'w500' para carteles, 'w185' para retratos del reparto...
  static String? urlImagen(String? ruta, {String tamano = 'w500'}) {
    if (ruta == null || ruta.isEmpty) return null;
    return '$_baseImagenes$tamano$ruta';
  }

  /// Extrae el campo "name" de cada objeto de una lista de la respuesta
  /// de TMDB (géneros, redes/canales, etc.).
  static List<String> nombresDeLista(dynamic lista) {
    if (lista is! List) return const [];
    final nombres = <String>[];
    for (final e in lista) {
      if (e is! Map<String, dynamic>) continue;
      final nombre = (e['name'] as String?) ?? '';
      if (nombre.isNotEmpty) nombres.add(nombre);
    }
    return nombres;
  }

  /// Plataformas de streaming en España ("watch/providers", anexado al
  /// detalle): de suscripción, gratis o con anuncios, sin repetir.
  /// null si no hay ninguna (no se muestra la sección).
  // shortcut: región fija España; cambiar 'ES' si hay usuarios de fuera.
  static DondeVer? dondeVerDe(dynamic json) {
    final resultados = json is Map<String, dynamic> ? json['results'] : null;
    final es = resultados is Map<String, dynamic> ? resultados['ES'] : null;
    if (es is! Map<String, dynamic>) return null;
    final ids = <int>{};
    final plataformas = [
      for (final tipo in ['flatrate', 'free', 'ads'])
        for (final p in es[tipo] as List? ?? const [])
          if (p is Map<String, dynamic> && ids.add(p['provider_id'] as int? ?? 0))
            (
              nombre: p['provider_name'] as String? ?? '',
              logo: urlImagen(p['logo_path'] as String?, tamano: 'w92'),
            ),
    ];
    if (plataformas.isEmpty) return null;
    return (enlace: es['link'] as String? ?? '', plataformas: plataformas);
  }

  /// Reparto de TMDB: "credits" (append_to_response=credits, solo los
  /// habituales) o, con [agregado], /tv/{id}/aggregate_credits (todos los
  /// actores de todas las temporadas, invitados incluidos).
  static List<RepartoModel> repartoDeCredits(dynamic credits,
      {bool agregado = false}) {
    if (credits is! Map<String, dynamic>) return const [];
    final cast = credits['cast'];
    if (cast is! List) return const [];
    final reparto = <RepartoModel>[];
    for (final e in cast) {
      if (e is! Map<String, dynamic>) continue;
      final nombre = (e['name'] as String?) ?? '';
      if (nombre.isEmpty) continue;
      reparto.add(RepartoModel(
        nombre: nombre,
        personaje: agregado
            ? _personajesAgregados(e)
            : (e['character'] as String?) ?? '',
        fotoUrl: urlImagen(e['profile_path'] as String?, tamano: 'w185'),
        // id de la persona en TMDB (para abrir su ficha al pinchar)
        idPersona: e['id'] as int?,
        fuente: 'tmdb',
      ));
    }
    return reparto;
  }

  /// Personaje(s) de un crédito agregado: usa "characters" (array) y,
  /// si no está, los "roles" de cada temporada.
  static String _personajesAgregados(Map<String, dynamic> json) {
    final characters = json['characters'];
    if (characters is List && characters.isNotEmpty) {
      final lista = characters.whereType<String>().toList();
      if (lista.isNotEmpty) return lista.join(' / ');
    }
    final roles = json['roles'];
    if (roles is List) {
      final nombres = <String>{
        for (final r in roles)
          if (r is Map<String, dynamic> && (r['character'] as String?)?.isNotEmpty == true)
            r['character'] as String,
      };
      if (nombres.isNotEmpty) return nombres.join(' / ');
    }
    return '';
  }
}

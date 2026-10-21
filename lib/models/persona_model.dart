import 'serie_model.dart' show TmdbRefs;

/// Persona (actriz/actor, doblador, director...) de TMDB o TVMaze.
class PersonaModel {
  final int id;
  final String fuente; // 'tmdb' o 'tvmaze'
  final String nombre;
  final String? fotoUrl;
  final String departamento; // 'Actuación', 'Dirección'... ('' si no se sabe)
  final String biografia; // '' si la fuente no la tiene (TVMaze nunca)
  final String? cumpleanos; // fecha 'yyyy-MM-dd'
  final String? fallecimiento; // fecha 'yyyy-MM-dd'
  final String? lugarNacimiento; // solo TMDB
  final String? pais; // solo TVMaze
  final String? urlPagina; // ficha pública en la web de la fuente

  const PersonaModel({
    required this.id,
    required this.fuente,
    required this.nombre,
    this.fotoUrl,
    this.departamento = '',
    this.biografia = '',
    this.cumpleanos,
    this.fallecimiento,
    this.lugarNacimiento,
    this.pais,
    this.urlPagina,
  });

  PersonaModel copyWith({
    int? id,
    String? fuente,
    String? nombre,
    String? fotoUrl,
    String? departamento,
    String? biografia,
    String? cumpleanos,
    String? fallecimiento,
    String? lugarNacimiento,
    String? pais,
    String? urlPagina,
  }) {
    return PersonaModel(
      id: id ?? this.id,
      fuente: fuente ?? this.fuente,
      nombre: nombre ?? this.nombre,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      departamento: departamento ?? this.departamento,
      biografia: biografia ?? this.biografia,
      cumpleanos: cumpleanos ?? this.cumpleanos,
      fallecimiento: fallecimiento ?? this.fallecimiento,
      lugarNacimiento: lugarNacimiento ?? this.lugarNacimiento,
      pais: pais ?? this.pais,
      urlPagina: urlPagina ?? this.urlPagina,
    );
  }

  /// Resultado de /search/person de TMDB (datos básicos de la búsqueda).
  factory PersonaModel.fromTmdbBusqueda(Map<String, dynamic> json) {
    final ruta = json['profile_path'] as String?;
    return PersonaModel(
      id: json['id'] as int? ?? 0,
      fuente: 'tmdb',
      nombre: json['name'] as String? ?? '',
      fotoUrl: TmdbRefs.urlImagen(ruta),
      departamento: json['known_for_department'] as String? ?? '',
    );
  }

  /// Ficha completa de /person/{id} de TMDB: biografía, nacimiento...
  factory PersonaModel.fromTmdbDetalle(Map<String, dynamic> json) {
    final ruta = json['profile_path'] as String?;
    return PersonaModel(
      id: json['id'] as int? ?? 0,
      fuente: 'tmdb',
      nombre: json['name'] as String? ?? '',
      fotoUrl: TmdbRefs.urlImagen(ruta),
      departamento: json['known_for_department'] as String? ?? '',
      biografia: json['biography'] as String? ?? '',
      cumpleanos: _vacioANull(json['birthday'] as String?),
      fallecimiento: _vacioANull(json['deathday'] as String?),
      lugarNacimiento: _vacioANull(json['place_of_birth'] as String?),
    );
  }

  /// Persona de TVMaze (/people/{id} o /search/people): sin biografía,
  /// pero con país, imagen y enlace a su página web.
  factory PersonaModel.fromTvmaze(Map<String, dynamic> json) {
    final imagen = json['image'];
    final paisJson = json['country'];
    return PersonaModel(
      id: json['id'] as int? ?? 0,
      fuente: 'tvmaze',
      nombre: json['name'] as String? ?? '',
      fotoUrl: imagen is Map<String, dynamic>
          ? (imagen['original'] as String? ?? imagen['medium'] as String?)
          : null,
      cumpleanos: _vacioANull(json['birthday'] as String?),
      fallecimiento: _vacioANull(json['deathday'] as String?),
      pais:
          paisJson is Map<String, dynamic> ? paisJson['name'] as String? : null,
      urlPagina: _vacioANull(json['url'] as String?),
    );
  }

  /// null cuando el campo viene vacío.
  static String? _vacioANull(String? valor) =>
      (valor == null || valor.isEmpty) ? null : valor;
}

/// Película o serie en la que una persona ha participado.
class CreditoPersonaModel {
  final int id; // id de la obra en su fuente
  final String fuente; // 'tmdb' o 'tvmaze'
  final String tipo; // 'serie' o 'pelicula'
  final String titulo;
  final String fecha; // 'yyyy-MM-dd' o '' si se desconoce
  final String? posterUrl;
  final String personaje; // '' si la fuente no lo indica
  final double puntuacion; // de 0 a 10

  const CreditoPersonaModel({
    required this.id,
    required this.fuente,
    required this.tipo,
    required this.titulo,
    this.fecha = '',
    this.posterUrl,
    this.personaje = '',
    this.puntuacion = 0,
  });

  /// Año de la obra (null si no hay fecha).
  int? get anio =>
      fecha.length >= 4 ? int.tryParse(fecha.substring(0, 4)) : null;

  /// Crédito de TMDB (/person/{id}/combined_credits): película o serie
  /// según 'media_type', con personaje, fecha y puntuación.
  factory CreditoPersonaModel.fromTmdb(Map<String, dynamic> json) {
    final esSerie = (json['media_type'] as String?) == 'tv';
    final ruta = json['poster_path'] as String?;
    return CreditoPersonaModel(
      id: json['id'] as int? ?? 0,
      fuente: 'tmdb',
      tipo: esSerie ? 'serie' : 'pelicula',
      titulo: (esSerie ? json['name'] : json['title']) as String? ?? '',
      fecha: (esSerie ? json['first_air_date'] : json['release_date'])
              as String? ??
          '',
      posterUrl: TmdbRefs.urlImagen(ruta, tamano: 'w342'),
      personaje: json['character'] as String? ?? '',
      puntuacion: (json['vote_average'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Crédito de TVMaze: siempre una serie, con su show embebido
  /// y el personaje indicado en los enlaces del crédito.
  factory CreditoPersonaModel.fromTvmaze(
      Map<String, dynamic> show, String personaje) {
    final imagen = show['image'];
    final rating = show['rating'];
    return CreditoPersonaModel(
      id: show['id'] as int? ?? 0,
      fuente: 'tvmaze',
      tipo: 'serie',
      titulo: show['name'] as String? ?? '',
      fecha: show['premiered'] as String? ?? '',
      posterUrl: imagen is Map<String, dynamic>
          ? (imagen['medium'] as String? ?? imagen['original'] as String?)
          : null,
      personaje: personaje,
      puntuacion: rating is Map<String, dynamic>
          ? ((rating['average'] as num?)?.toDouble() ?? 0)
          : 0,
    );
  }
}

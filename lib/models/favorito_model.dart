/// Contenido guardado por un usuario en Favoritos o Vistos: serie,
/// película, manga/novela o persona (actriz, actor...).
class FavoritoModel {
  // Estados de una obra guardada (null = desconocido). No los elige el
  // usuario: salen de la base de datos (TMDB, TVMaze o AniList).
  static const List<String> estados = [
    'enEmision',
    'enEspera',
    'abandonado',
    'planeado',
    'finalizado',
  ];

  /// Estado de la app a partir del estado ya normalizado de SerieModel,
  /// PeliculaModel o MangaModel; null si es desconocido.
  static String? estadoDeApi(String estadoApi) => switch (estadoApi) {
    'en_emision' || 'emision' => 'enEmision',
    'parado' => 'enEspera', // serie o manga en pausa
    'cancelada' || 'cancelado' => 'abandonado',
    'planeada' || 'en_produccion' || 'proximamente' => 'planeado',
    'finalizada' || 'finalizado' || 'lanzada' => 'finalizado',
    _ => null,
  };

  final String tipo; // 'serie', 'pelicula', 'manga', 'novela' o 'persona'
  final String fuente; // 'tmdb', 'tvmaze' o 'anilist'
  final int id; // id dentro de su fuente
  final String? imdbId; // puente entre TMDB y TVMaze
  final String titulo; // en personas, su nombre
  // Título en su idioma original: '' si es igual que [titulo] o no hay,
  // null si aún no se sabe (lo guardado antes; se completa con TMDB)
  final String? tituloOriginal;
  final int? anio;
  final String? posterUrl; // URL completa del póster (o foto de la persona)
  final String fechaEstreno; // 'yyyy-MM-dd' o ''
  final String? estado; // uno de [estados] (de la base de datos), o null
  final int? puntuacion; // nota personal 1-10, o null (sin puntuar)

  const FavoritoModel({
    required this.tipo,
    required this.fuente,
    required this.id,
    this.imdbId,
    required this.titulo,
    this.tituloOriginal,
    this.anio,
    this.posterUrl,
    this.fechaEstreno = '',
    this.estado,
    this.puntuacion,
  });

  /// Identificador único: fuente + tipo + id.
  String get idUnico => '$fuente-$tipo-$id';

  /// Copia con otro estado y otra puntuación (null = quitarlos) y, si se
  /// dan, otra fecha de estreno (con su año) y otro título original.
  FavoritoModel conValoracion({
    required String? estado,
    required int? puntuacion,
    String? fechaEstreno,
    String? tituloOriginal,
  }) => FavoritoModel(
    tipo: tipo,
    fuente: fuente,
    id: id,
    imdbId: imdbId,
    titulo: titulo,
    tituloOriginal: tituloOriginal ?? this.tituloOriginal,
    anio: fechaEstreno != null && fechaEstreno.length >= 4
        ? int.tryParse(fechaEstreno.substring(0, 4)) ?? anio
        : anio,
    posterUrl: posterUrl,
    fechaEstreno: fechaEstreno ?? this.fechaEstreno,
    estado: estado,
    puntuacion: puntuacion,
  );

  /// Los campos nuevos (estado, puntuación, título original) son opcionales: los datos y
  /// las copias antiguas, que no los traen, se cargan con null.
  factory FavoritoModel.fromJson(Map<String, dynamic> json) {
    final estado = json['estado'] as String?;
    final puntuacion = json['puntuacion'] as int?;
    return FavoritoModel(
      tipo: json['tipo'] as String,
      fuente: json['fuente'] as String,
      id: json['id'] as int,
      imdbId: json['imdbId'] as String?,
      titulo: json['titulo'] as String,
      tituloOriginal: json['tituloOriginal'] as String?,
      anio: json['anio'] as int?,
      posterUrl: json['posterUrl'] as String?,
      fechaEstreno: json['fechaEstreno'] as String? ?? '',
      // Valores fuera de rango (archivo editado a mano) se ignoran
      estado: estados.contains(estado) ? estado : null,
      puntuacion: puntuacion != null && puntuacion >= 1 && puntuacion <= 10
          ? puntuacion
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'tipo': tipo,
    'fuente': fuente,
    'id': id,
    'imdbId': imdbId,
    'titulo': titulo,
    'tituloOriginal': tituloOriginal,
    'anio': anio,
    'posterUrl': posterUrl,
    'fechaEstreno': fechaEstreno,
    'estado': estado,
    'puntuacion': puntuacion,
  };
}

/// Favorito guardado por un usuario (serie o película).
class FavoritoModel {
  final String tipo; // 'serie' o 'pelicula'
  final String fuente; // 'tmdb' o 'tvmaze'
  final int id; // id dentro de su fuente
  final String? imdbId; // puente entre TMDB y TVMaze
  final String titulo;
  final int? anio;
  final String? posterUrl; // URL completa del póster
  final String fechaEstreno; // 'yyyy-MM-dd' o ''

  const FavoritoModel({
    required this.tipo,
    required this.fuente,
    required this.id,
    this.imdbId,
    required this.titulo,
    this.anio,
    this.posterUrl,
    this.fechaEstreno = '',
  });

  /// Identificador único: fuente + tipo + id.
  String get idUnico => '$fuente-$tipo-$id';

  factory FavoritoModel.fromJson(Map<String, dynamic> json) {
    return FavoritoModel(
      tipo: json['tipo'] as String,
      fuente: json['fuente'] as String,
      id: json['id'] as int,
      imdbId: json['imdbId'] as String?,
      titulo: json['titulo'] as String,
      anio: json['anio'] as int?,
      posterUrl: json['posterUrl'] as String?,
      fechaEstreno: json['fechaEstreno'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'fuente': fuente,
        'id': id,
        'imdbId': imdbId,
        'titulo': titulo,
        'anio': anio,
        'posterUrl': posterUrl,
        'fechaEstreno': fechaEstreno,
      };
}

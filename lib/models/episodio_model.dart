/// Episodio de una serie.
class EpisodioModel {
  final int temporada;
  final int numero;
  final String titulo;
  final String fechaEmision; // 'yyyy-MM-dd' o ''
  final String horaEmision; // 'HH:mm' o ''

  const EpisodioModel({
    required this.temporada,
    required this.numero,
    this.titulo = '',
    this.fechaEmision = '',
    this.horaEmision = '',
  });

  /// Texto corto tipo "T2E5" (temporada 2, episodio 5).
  String get etiqueta => 'T${temporada}E$numero';

  factory EpisodioModel.fromJson(Map<String, dynamic> json) {
    return EpisodioModel(
      temporada: json['temporada'] as int? ?? 0,
      numero: json['numero'] as int? ?? 0,
      titulo: json['titulo'] as String? ?? '',
      fechaEmision: json['fechaEmision'] as String? ?? '',
      horaEmision: json['horaEmision'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'temporada': temporada,
        'numero': numero,
        'titulo': titulo,
        'fechaEmision': fechaEmision,
        'horaEmision': horaEmision,
      };
}

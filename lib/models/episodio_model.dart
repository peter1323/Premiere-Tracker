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

}

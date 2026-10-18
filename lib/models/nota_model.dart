/// Nota personal del usuario: título de la serie o película, dónde se
/// quedó la última vez (p. ej. 'T4 E2') y un campo libre para datos
/// extra (p. ej. personajes, dudas, enlaces...). Sirve para retomar
/// cuando se vuelve tras meses.
class NotaModel {
  final String id; // id interno (microsegundos al crearla)
  final String titulo; // p. ej. 'Dragon Ball'
  final String ultimaVista; // p. ej. 'T4 E2' (texto libre)
  final String masDatos; // campo libre para lo que se quiera apuntar
  final String fechaEdicion; // ISO, para ordenar (la más reciente arriba)

  const NotaModel({
    required this.id,
    required this.titulo,
    required this.ultimaVista,
    this.masDatos = '',
    this.fechaEdicion = '',
  });

  factory NotaModel.nueva({
    required String titulo,
    required String ultimaVista,
    String masDatos = '',
  }) {
    return NotaModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      titulo: titulo,
      ultimaVista: ultimaVista,
      masDatos: masDatos,
      fechaEdicion: DateTime.now().toIso8601String(),
    );
  }

  factory NotaModel.fromJson(Map<String, dynamic> json) {
    return NotaModel(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      titulo: json['titulo'] as String? ?? '',
      ultimaVista: json['ultimaVista'] as String? ?? '',
      masDatos: json['masDatos'] as String? ?? '',
      fechaEdicion: json['fechaEdicion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'ultimaVista': ultimaVista,
        'masDatos': masDatos,
        'fechaEdicion': fechaEdicion,
      };

  /// Copia con campos actualizados (al editar una nota).
  NotaModel copiarCon({String? titulo, String? ultimaVista, String? masDatos}) {
    return NotaModel(
      id: id,
      titulo: titulo ?? this.titulo,
      ultimaVista: ultimaVista ?? this.ultimaVista,
      masDatos: masDatos ?? this.masDatos,
      fechaEdicion: DateTime.now().toIso8601String(),
    );
  }
}

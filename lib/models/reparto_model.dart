/// Miembro del reparto de una serie o película.
class RepartoModel {
  final String nombre; // nombre del actor
  final String personaje; // personaje que interpreta
  final String? fotoUrl; // URL de la foto (null si no tiene)
  final int? idPersona; // id de la persona en su fuente ('tmdb'/'tvmaze')
  final String? fuente; // fuente del id: 'tmdb' o 'tvmaze'

  const RepartoModel({
    required this.nombre,
    this.personaje = '',
    this.fotoUrl,
    this.idPersona,
    this.fuente,
  });

  factory RepartoModel.fromJson(Map<String, dynamic> json) {
    return RepartoModel(
      nombre: json['nombre'] as String? ?? '',
      personaje: json['personaje'] as String? ?? '',
      fotoUrl: json['fotoUrl'] as String?,
      idPersona: json['idPersona'] as int?,
      fuente: json['fuente'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'personaje': personaje,
        'fotoUrl': fotoUrl,
        'idPersona': idPersona,
        'fuente': fuente,
      };
}

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

}

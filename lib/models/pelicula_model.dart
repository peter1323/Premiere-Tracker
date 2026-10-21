// MODELO de una película (sus datos vienen de TMDB). Solo guarda campos
// y sabe convertir la respuesta JSON de TMDB a objeto (fromTmdb) y de
// objeto. No hace llamadas de red ni lógica de interfaz.
import 'reparto_model.dart';
import 'serie_model.dart' show TmdbRefs;

/// Película de TMDB (TVMaze no tiene películas).
class PeliculaModel {
  // Estados normalizados que entiende la app
  static const String estadoLanzada = 'lanzada';
  static const String estadoEnProduccion = 'en_produccion';
  static const String estadoCancelada = 'cancelada';
  static const String estadoDesconocida = 'desconocida';

  final int id;
  final String fuente; // siempre 'tmdb'
  final String titulo;
  final String sinopsis;
  final String fechaEstreno; // 'yyyy-MM-dd' o ''
  final String estado; // uno de los estados normalizados de arriba
  final String? posterUrl;
  final double? puntuacion; // nota media 0-10 (null si no hay)
  final List<String> generos; // p. ej. Acción, Drama...
  final List<RepartoModel> reparto;

  const PeliculaModel({
    required this.id,
    this.fuente = 'tmdb',
    required this.titulo,
    this.sinopsis = '',
    this.fechaEstreno = '',
    this.estado = estadoDesconocida,
    this.posterUrl,
    this.puntuacion,
    this.generos = const [],
    this.reparto = const [],
  });

  /// Año de estreno, o null si no hay fecha.
  int? get anio => fechaEstreno.length >= 4
      ? int.tryParse(fechaEstreno.substring(0, 4))
      : null;

  /// Película a partir de un resultado de búsqueda de TMDB (/search/movie).
  factory PeliculaModel.fromTmdbBusqueda(Map<String, dynamic> json) {
    return PeliculaModel(
      id: json['id'] as int? ?? 0,
      titulo: (json['title'] as String?) ?? '',
      sinopsis: (json['overview'] as String?) ?? '',
      fechaEstreno: (json['release_date'] as String?) ?? '',
      posterUrl: TmdbRefs.urlImagen(json['poster_path'] as String?),
    );
  }

  /// Película a partir del detalle de TMDB (/movie/{id}).
  /// El servicio añade el reparto con append_to_response=credits.
  factory PeliculaModel.fromTmdbDetalle(Map<String, dynamic> json) {
    return PeliculaModel(
      id: json['id'] as int? ?? 0,
      titulo: (json['title'] as String?) ?? '',
      sinopsis: (json['overview'] as String?) ?? '',
      fechaEstreno: (json['release_date'] as String?) ?? '',
      estado: _normalizarEstado(json['status'] as String?),
      posterUrl: TmdbRefs.urlImagen(json['poster_path'] as String?),
      puntuacion: (json['vote_average'] as num?)?.toDouble(),
      generos: TmdbRefs.nombresDeLista(json['genres']),
      reparto: TmdbRefs.repartoDeCredits(json['credits']),
    );
  }

  static String _normalizarEstado(String? estado) {
    switch (estado) {
      case 'Released':
        return estadoLanzada;
      case 'Post Production':
      case 'In Production':
        return estadoEnProduccion;
      case 'Canceled':
        return estadoCancelada;
      default:
        return estadoDesconocida;
    }
  }
}

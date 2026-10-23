// CONTROLADOR de la pantalla de un género (se abre al tocar un género en
// la ficha de una serie, película, manga o novela). Pide a la API que
// corresponde los títulos más populares de ese género: TMDB para series
// y películas, AniList para mangas y novelas. Se crea en genero_view.dart
// y se DESTRUYE al volver atrás.
import 'package:flutter/foundation.dart';

import '../services/anilist_service.dart';
import '../services/tmdb_service.dart';
import 'mangas_controller.dart';

/// Lógica de la pantalla de un género: carga sus títulos populares.
class GeneroController extends ChangeNotifier {
  final String tipo; // 'serie', 'pelicula' o un formato de AniList
  final String genero; // nombre tal cual viene de la API
  final String language; // 'es-ES' o 'en-US'
  // Si se toca una palabra clave de TMDB: su id (si no, es un género)
  final int? idPalabraClave;
  // true si es una etiqueta de AniList en vez de un género
  final bool etiqueta;

  GeneroController({
    required this.tipo,
    required this.genero,
    required this.language,
    this.idPalabraClave,
    this.etiqueta = false,
  });

  List<Object> _resultados = const [];
  bool _cargando = true;
  bool _error = false;
  bool _destruido = false; // true si la vista se cerró mientras cargaba

  List<Object> get resultados => _resultados;
  bool get cargando => _cargando;
  bool get error => _error;

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }

  /// Carga los títulos del género según el tipo de ficha de la que viene.
  Future<void> cargar() async {
    try {
      _resultados = switch (tipo) {
        'serie' => await TmdbService.seriesPorGenero(
          genero,
          language,
          idPalabraClave: idPalabraClave,
        ),
        'pelicula' => await TmdbService.peliculasPorGenero(
          genero,
          language,
          idPalabraClave: idPalabraClave,
        ),
        // Mangas: novelas por un lado y cómics (manga, one shot) por otro
        'NOVEL' => await AnilistService.porGenero(
          genero,
          MangasController.formatosNovela,
          etiqueta: etiqueta,
        ),
        _ => await AnilistService.porGenero(
          genero,
          MangasController.formatosComic,
          etiqueta: etiqueta,
        ),
      };
    } catch (_) {
      _error = true;
    }
    _cargando = false;
    if (!_destruido) notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import '../models/pelicula_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
import '../services/busqueda_service.dart';

/// Lógica de la pantalla de Inicio: buscador con resultados de TMDB y
/// TVMaze (en paralelo y anti-fallos) y selector de fuente.
class InicioController extends ChangeNotifier {
  ResultadoBusqueda? _resultado;
  bool _buscando = false;
  bool _hayConsulta = false;
  String _fuenteSeries = 'tmdb'; // fuente seleccionada del selector

  ResultadoBusqueda? get resultado => _resultado;
  bool get buscando => _buscando;

  /// true cuando ya se ha hecho alguna búsqueda (aunque haya fallado).
  bool get hayConsulta => _hayConsulta;

  /// Fuente seleccionada para las series ('tmdb' o 'tvmaze').
  String get fuenteSeries => _fuenteSeries;

  /// ¿Está disponible cada fuente en el resultado actual?
  bool get tmdbOk => _resultado?.tmdbOk ?? false;
  bool get tvmazeOk => _resultado?.tvmazeOk ?? false;

  /// Claves de aviso traducidas (TVMaze caído, TMDB caído, sin conexión...).
  List<String> get avisos => _resultado?.avisos ?? const [];

  /// Series según la fuente seleccionada.
  List<SerieModel> get seriesVisibles {
    final r = _resultado;
    if (r == null) return const [];
    return _fuenteSeries == 'tmdb' ? r.seriesTmdb : r.seriesTvmaze;
  }

  /// Películas (solo TMDB).
  List<PeliculaModel> get peliculasVisibles =>
      _resultado?.peliculas ?? const [];

  /// Personas (TMDB + TVMaze fusionadas sin repetir nombres).
  List<PersonaModel> get personasVisibles =>
      _resultado?.personas ?? const [];

  /// ¿Hay algún resultado en total?
  bool get hayResultados => _resultado?.hayResultados ?? false;

  /// La fuente seleccionada para series está disponible.
  bool get fuenteSeriesDisponible =>
      _fuenteSeries == 'tmdb' ? tmdbOk : tvmazeOk;

  /// Busca en TMDB y TVMaze a la vez (en paralelo y anti-fallos).
  Future<void> buscar(String texto, String idioma) async {
    final consulta = texto.trim();
    if (consulta.isEmpty) return;
    _buscando = true;
    _hayConsulta = true;
    notifyListeners();

    // TMDB usa es-ES o en-US según el idioma de la app
    final language = idioma == 'es' ? 'es-ES' : 'en-US';
    _resultado = await BusquedaService.buscar(consulta, language);

    // Si la fuente seleccionada no está disponible, se usa la otra
    if (!fuenteSeriesDisponible) {
      _fuenteSeries = tvmazeOk ? 'tvmaze' : 'tmdb';
    }
    _buscando = false;
    notifyListeners();
  }

  /// Cambia la fuente de los resultados de series (TMDB | TVMaze).
  void cambiarFuenteSeries(String fuente) {
    final disponible = fuente == 'tmdb' ? tmdbOk : tvmazeOk;
    if (!disponible) return; // fuente caída: se ignora el cambio
    _fuenteSeries = fuente;
    notifyListeners();
  }

  /// Limpia la búsqueda y vuelve al estado inicial.
  void limpiarBusqueda() {
    _resultado = null;
    _hayConsulta = false;
    notifyListeners();
  }
}

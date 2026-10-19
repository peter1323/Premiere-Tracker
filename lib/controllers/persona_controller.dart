// CONTROLADOR de la ficha de una persona (actriz, actor, director...),
// que se abre con Navigator.push desde los resultados de búsqueda.
// Carga sus datos y su filmografía de TMDB y TVMaze en paralelo (anti-
// fallos: si una fuente falla, la otra sigue), enlaza la persona entre
// ambas bases por nombre exacto y fusiona los dos resultados (TMDB manda
// y TVMaze rellena los huecos). Se crea en persona_view.dart y se
// DESTRUYE al volver atrás: por eso comprueba `if (_destruido) return;`
// antes de notificar tras el await.
import 'package:flutter/foundation.dart';

import '../models/persona_model.dart';
import '../services/busqueda_service.dart';
import '../services/tmdb_service.dart';
import '../services/tvmaze_service.dart';

/// Lógica de la ficha de una persona: carga sus datos de TMDB y TVMaze
/// en paralelo (anti-fallos), enlazando por nombre exacto cuando la
/// persona solo viene de una fuente, y fusiona ambos resultados:
/// TMDB es la fuente principal y TVMaze rellena los huecos.
class PersonaController extends ChangeNotifier {
  final PersonaModel personaInicial;
  final String language; // 'es-ES' o 'en-US'

  PersonaModel? _persona; // ficha fusionada para mostrar
  List<CreditoPersonaModel> _creditos = const [];
  bool _cargando = false;
  String? _aviso; // clave de traducción o null

  // Ids en cada fuente (uno puede quedar null si no se encontró)
  int? _idTmdb;
  int? _idTvmaze;

  PersonaController({required this.personaInicial, required this.language})
      : _idTmdb = personaInicial.fuente == 'tmdb' ? personaInicial.id : null,
        _idTvmaze =
            personaInicial.fuente == 'tvmaze' ? personaInicial.id : null;

  bool _destruido = false; // true si la vista se cerró mientras cargaba

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }

  PersonaModel? get persona => _persona;
  List<CreditoPersonaModel> get creditos => _creditos;
  bool get cargando => _cargando;
  String? get aviso => _aviso;

  /// Carga inicial: TMDB y TVMaze en paralelo (cada una anti-fallos).
  Future<void> cargar() async {
    _cargando = true;
    _aviso = null;
    notifyListeners();

    // Completa los ids que falten enlazando por nombre exacto.
    await _completarIds();

    // Fichas y créditos de las dos fuentes a la vez.
    final resultados = await Future.wait([
      _cargarFuenteTmdb(),
      _cargarFuenteTvmaze(),
    ]);
    if (_destruido) return; // la vista se cerró: nadie escucha ya
    final tmdb = resultados[0];
    final tvmaze = resultados[1];

    _persona = _fusionar(tmdb.persona, tvmaze.persona);

    // Filmografía: la de TMDB si tiene; si no, la de TVMaze.
    _creditos = tmdb.creditos.isNotEmpty ? tmdb.creditos : tvmaze.creditos;

    // Aviso: sin conexión si ninguna fuente respondió; si solo falló
    // TMDB por la clave, se avisa porque la biografía viene de ahí.
    if (tmdb.persona == null && tvmaze.persona == null) {
      _aviso = 'sinConexion';
    } else if (tmdb.persona == null && tmdb.falloClave) {
      _aviso = 'avisoTmdbKey';
    } else {
      _aviso = null;
    }

    _cargando = false;
    notifyListeners();
  }

  /// Busca en la otra base de datos los ids que falten (por nombre exacto).
  Future<void> _completarIds() async {
    final pendientes = <Future<void>>[];
    if (_idTmdb == null) pendientes.add(_buscarIdTmdb());
    if (_idTvmaze == null) pendientes.add(_buscarIdTvmaze());
    if (pendientes.isNotEmpty) await Future.wait(pendientes);
  }

  Future<void> _buscarIdTmdb() async {
    try {
      final enTmdb = await BusquedaService.enlazarPersonaEnTmdb(
          personaInicial, language);
      _idTmdb = enTmdb?.id;
    } catch (_) {
      _idTmdb = null;
    }
  }

  Future<void> _buscarIdTvmaze() async {
    try {
      final enTvmaze =
          await BusquedaService.enlazarPersonaEnTvmaze(personaInicial);
      _idTvmaze = enTvmaze?.id;
    } catch (_) {
      _idTvmaze = null;
    }
  }

  /// Ficha + créditos desde TMDB; si el id no está, lista vacía.
  Future<_DatosPersona> _cargarFuenteTmdb() async {
    final id = _idTmdb;
    if (id == null) return const _DatosPersona.vacio();
    try {
      var persona = await TmdbService.obtenerPersona(id, language);
      // Biografía: si TMDB no la tiene en este idioma, se pide en inglés.
      if (persona.biografia.trim().isEmpty && language != 'en-US') {
        try {
          final enIngles = await TmdbService.obtenerPersona(id, 'en-US');
          if (enIngles.biografia.trim().isNotEmpty) {
            persona = persona.copyWith(biografia: enIngles.biografia);
          }
        } catch (_) {
          // sin biografía en inglés: se queda con la actual
        }
      }
      // Filmografía: si falla, se conserva la ficha básica.
      List<CreditoPersonaModel> creditos = const [];
      try {
        creditos = await TmdbService.obtenerCreditosPersona(id, language);
      } catch (_) {
        creditos = const [];
      }
      return _DatosPersona(persona, creditos);
    } on TmdbException catch (e) {
      return _DatosPersona(null, const [], falloClave: e.claveIncorrecta);
    } catch (_) {
      return const _DatosPersona.vacio();
    }
  }

  /// Ficha + créditos desde TVMaze; si el id no está, lista vacía.
  Future<_DatosPersona> _cargarFuenteTvmaze() async {
    final id = _idTvmaze;
    if (id == null) return const _DatosPersona.vacio();
    try {
      final persona = await TvmazeService.obtenerPersona(id);
      if (persona == null) return const _DatosPersona.vacio();
      // Filmografía: si falla, se conserva la ficha básica.
      List<CreditoPersonaModel> creditos = const [];
      try {
        creditos = await TvmazeService.obtenerCreditosPersona(id);
      } catch (_) {
        creditos = const [];
      }
      return _DatosPersona(persona, creditos);
    } catch (_) {
      return const _DatosPersona.vacio();
    }
  }

  /// Fusiona las dos fichas: TMDB manda y TVMaze rellena los huecos
  /// (foto, cumpleaños, fallecimiento, país y enlace a su página).
  PersonaModel _fusionar(PersonaModel? tmdb, PersonaModel? tvmaze) {
    final base = tmdb ?? tvmaze ?? personaInicial;
    if (tvmaze == null) return base;
    return base.copyWith(
      fotoUrl: base.fotoUrl ?? tvmaze.fotoUrl,
      cumpleanos: base.cumpleanos ?? tvmaze.cumpleanos,
      fallecimiento: base.fallecimiento ?? tvmaze.fallecimiento,
      pais: base.pais ?? tvmaze.pais,
      urlPagina: tvmaze.urlPagina ?? base.urlPagina,
    );
  }
}

/// Datos cargados de una fuente para una persona (ficha + créditos).
class _DatosPersona {
  final PersonaModel? persona;
  final List<CreditoPersonaModel> creditos;
  final bool falloClave; // la API key de TMDB estaba mal en esta carga

  const _DatosPersona(this.persona, this.creditos, {this.falloClave = false});

  const _DatosPersona.vacio() : this(null, const []);
}

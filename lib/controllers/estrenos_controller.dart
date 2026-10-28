// CONTROLADOR de la pantalla Estrenos (entre Lectura y Calendario en el
// menú). Busca en TMDB los próximos estrenos de series y películas según
// los filtros que elige el usuario (no solo sus favoritos) y los agrupa
// por día con el mismo formato que el Calendario, para reutilizar sus
// vistas de mes y día. Al entrar está vacío hasta aplicar unos filtros.
// Vive en el IndexedStack, así que conserva los resultados al cambiar de
// sección.
import 'package:flutter/foundation.dart';

import '../models/episodio_model.dart';
import '../models/filtros_estrenos.dart';
import '../models/pelicula_model.dart';
import '../models/serie_model.dart';
import '../services/tmdb_service.dart';
import 'calendario_controller.dart';

/// Lógica de Estrenos: filtros de series y de películas, carga desde TMDB
/// y navegación por el calendario (mes y día, Series | Películas).
class EstrenosController extends ChangeNotifier {
  FiltrosEstrenos _filtrosSeries = FiltrosEstrenos.inicial(esSerie: true);
  FiltrosEstrenos _filtrosPeliculas = FiltrosEstrenos.inicial(esSerie: false);
  bool _aplicados = false; // false hasta aceptar los filtros la 1.ª vez
  String _modo = 'mes'; // 'mes' o 'dia'
  String _pestana = 'series'; // 'series' o 'peliculas'
  DateTime _fechaVisible = inicioDePeriodo('mes', DateTime.now());
  bool _cargando = false;
  String? _aviso; // clave de traducción o null
  Map<String, List<EntradaCalendario>> _seriesPorDia = {};
  Map<String, List<EntradaCalendario>> _peliculasPorDia = {};
  int _cargaToken = 0; // descarta cargas viejas si se aplican otros filtros

  FiltrosEstrenos get filtrosSeries => _filtrosSeries;
  FiltrosEstrenos get filtrosPeliculas => _filtrosPeliculas;
  bool get aplicados => _aplicados;
  String get modo => _modo;
  String get pestana => _pestana;
  DateTime get fechaVisible => _fechaVisible;
  bool get cargando => _cargando;
  String? get aviso => _aviso;
  Map<String, List<EntradaCalendario>> get seriesPorDia => _seriesPorDia;
  Map<String, List<EntradaCalendario>> get peliculasPorDia => _peliculasPorDia;

  /// Guarda los filtros elegidos y carga sus estrenos. El calendario salta
  /// a la fecha "desde" de la pestaña visible.
  Future<void> aplicar(
    FiltrosEstrenos series,
    FiltrosEstrenos peliculas,
    String language,
  ) async {
    _filtrosSeries = series;
    _filtrosPeliculas = peliculas;
    _aplicados = true;
    _fechaVisible = inicioDePeriodo(
      _modo,
      (_pestana == 'series' ? series : peliculas).desde,
    );
    final token = ++_cargaToken;
    _cargando = true;
    _aviso = null;
    notifyListeners();

    Map<String, List<EntradaCalendario>> seriesPorDia = {};
    Map<String, List<EntradaCalendario>> peliculasPorDia = {};
    try {
      final resultado = await Future.wait([
        _cargarSeries(series, language),
        _cargarPeliculas(peliculas, language),
      ]);
      seriesPorDia = _porDia(resultado[0]);
      peliculasPorDia = _porDia(resultado[1]);
    } on TmdbException catch (e) {
      _aviso = e.claveIncorrecta ? 'avisoTmdbKey' : 'avisoTmdb';
    } catch (_) {
      _aviso = 'sinConexion';
    }
    // Se aplicaron otros filtros mientras cargaba: se descarta esta carga
    if (token != _cargaToken) return;
    _seriesPorDia = seriesPorDia;
    _peliculasPorDia = peliculasPorDia;
    _cargando = false;
    notifyListeners();
    // Con todos los episodios, el número de cada uno llega después
    if (series.todosEpisodios && _aviso == null) {
      await _ponerEtiquetas(series, language, token);
    }
  }

  /// La vista cambió de periodo (flechas o deslizar).
  void irAFecha(DateTime fecha) => _verFecha(fecha);

  /// Vuelve al periodo de hoy.
  void irAHoy() => _verFecha(DateTime.now());

  void _verFecha(DateTime fecha) {
    final nueva = inicioDePeriodo(_modo, fecha);
    if (nueva == _fechaVisible) return;
    _fechaVisible = nueva;
    notifyListeners();
  }

  /// Cambia entre Mes y Día (al tocar un día del mes se abre ese día).
  void cambiarModo(String modo) {
    if (_modo == modo) return;
    _modo = modo;
    _fechaVisible = inicioDePeriodo(modo, _fechaVisible);
    notifyListeners();
  }

  /// Cambia la pestaña (Series | Películas).
  void cambiarPestana(String pestana) {
    if (_pestana == pestana) return;
    _pestana = pestana;
    notifyListeners();
  }

  /// Agrupa las entradas por día ('yyyy-MM-dd').
  static Map<String, List<EntradaCalendario>> _porDia(
    List<EntradaCalendario> entradas,
  ) {
    final porDia = <String, List<EntradaCalendario>>{};
    for (final e in entradas) {
      (porDia[e.claveDia] ??= []).add(e);
    }
    return porDia;
  }

  /// ¿Cae [fecha] ('yyyy-MM-dd') entre las fechas de [f]?
  static bool _enRango(String fecha, FiltrosEstrenos f) =>
      fecha.isNotEmpty &&
      fecha.compareTo(claveDia(f.desde)) >= 0 &&
      fecha.compareTo(claveDia(f.hasta)) <= 0;

  /// Estrenos de películas, un día por película como en la web de TMDB.
  /// Solo España: el día que da TMDB (el estreno de allí). Todos los
  /// países: TMDB da una fecha que puede no ser la del filtro, así que se
  /// miran sus estrenos y se usa el de España si cae en las fechas o, si
  /// no, el primero de otro país (de los tipos elegidos).
  Future<List<EntradaCalendario>> _cargarPeliculas(
    FiltrosEstrenos f,
    String language,
  ) async {
    final peliculas = await TmdbService.estrenosPeliculas(f, language);
    EntradaCalendario entrada(PeliculaModel p, String dia) => EntradaCalendario(
      tipo: 'pelicula',
      fuente: 'tmdb',
      id: p.id,
      titulo: p.titulo,
      tituloOriginal: TmdbRefs.originalDistinto(p.tituloOriginal, p.titulo),
      posterUrl: p.posterUrl,
      claveDia: dia,
    );
    if (!f.todosPaises) {
      return [
        for (final p in peliculas)
          if (_enRango(p.fechaEstreno, f)) entrada(p, p.fechaEstreno),
      ];
    }
    return _porLotes(peliculas, (p) async {
      final validas = [
        for (final e in await TmdbService.fechasEstreno(p.id))
          if (f.tipos.contains(e.tipo) && _enRango(e.fecha, f)) e,
      ]..sort((a, b) => a.fecha.compareTo(b.fecha));
      if (validas.isEmpty) return const [];
      final deEspana = validas.where((e) => e.pais == TmdbRefs.region);
      return [entrada(p, (deEspana.isEmpty ? validas : deEspana).first.fecha)];
    });
  }

  /// Aplica [cargar] a cada elemento de 12 en 12 (para no saturar a TMDB) y
  /// junta los resultados. Si uno falla, se queda fuera sin romper el resto.
  static Future<List<R>> _porLotes<T, R>(
    List<T> elementos,
    Future<List<R>> Function(T) cargar,
  ) async {
    Future<List<R>> seguro(T e) async {
      try {
        return await cargar(e);
      } catch (_) {
        return const [];
      }
    }

    final resultados = <R>[];
    for (var i = 0; i < elementos.length; i += 12) {
      final lote = await Future.wait(elementos.skip(i).take(12).map(seguro));
      resultados.addAll(lote.expand((l) => l));
    }
    return resultados;
  }

  /// Estrenos de series. Solo series nuevas: el día de su primer episodio.
  /// Todos los episodios: se pregunta a TMDB día a día, como hace su web
  /// (con un rango de varios días deja fuera series que sí emiten, p. ej.
  /// Los misterios de Madame Blanc). Así salen sin el número de episodio,
  /// que se rellena después con [_ponerEtiquetas].
  Future<List<EntradaCalendario>> _cargarSeries(
    FiltrosEstrenos f,
    String language,
  ) async {
    if (!f.todosEpisodios) {
      return [
        for (final s in await TmdbService.estrenosSeries(f, language))
          if (_enRango(s.fechaEstreno, f))
            _entradaSerie(s, s.fechaEstreno, 'T1E1'),
      ];
    }
    final dias = [
      for (
        var d = f.desde;
        !d.isAfter(f.hasta);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
    return _porLotes(dias, (dia) async {
      final series = await TmdbService.estrenosSeries(
        f.copyWith(desde: dia, hasta: dia),
        language,
      );
      // Entre páginas TMDB a veces repite una serie: una vez por día
      final vistas = <int>{};
      return [
        for (final s in series)
          if (vistas.add(s.id)) _entradaSerie(s, claveDia(dia), ''),
      ];
    });
  }

  /// Rellena en segundo plano el número de episodio ("T5E1") de cada serie
  /// del calendario y avisa a la vista al terminar. Si mientras tanto se
  /// aplican otros filtros ([token] viejo), no hace nada.
  Future<void> _ponerEtiquetas(
    FiltrosEstrenos f,
    String language,
    int token,
  ) async {
    final ids = {
      for (final lista in _seriesPorDia.values)
        for (final e in lista) e.id,
    }.toList();
    final etiquetas = Map.fromEntries(
      await _porLotes(ids, (id) => _etiquetasEnRango(id, f, language)),
    );
    if (token != _cargaToken) return;
    _seriesPorDia = {
      for (final MapEntry(key: dia, value: lista) in _seriesPorDia.entries)
        dia: [
          for (final e in lista)
            e.conEtiqueta(etiquetas['${e.id}|$dia'] ?? e.etiqueta),
        ],
    };
    notifyListeners();
  }

  /// Número de episodio de la serie [id] en cada día entre las fechas de
  /// [f], con clave 'id|día'. TMDB no lo da en el listado: se miran la
  /// temporada del próximo episodio y la última ya empezada. Si TMDB no
  /// tiene próximo episodio, también la siguiente a la última (a veces la
  /// temporada nueva ya tiene episodios pero aún no sale en la ficha).
  /// Si ese día salen varios episodios, el primero.
  Future<List<MapEntry<String, String>>> _etiquetasEnRango(
    int id,
    FiltrosEstrenos f,
    String language,
  ) async {
    final ficha = await TmdbService.obtenerSerie(
      id,
      language,
      conReparto: false,
    );
    final hasta = claveDia(f.hasta);
    final empezadas = [
      for (final t in ficha.temporadas)
        if (t.numero > 0 &&
            t.fechaEstreno.isNotEmpty &&
            t.fechaEstreno.compareTo(hasta) <= 0)
          t.numero,
    ];
    final temporadas = {
      ?ficha.proximoEpisodio?.temporada,
      if (empezadas.isNotEmpty) empezadas.reduce((a, b) => a > b ? a : b),
      if (ficha.proximoEpisodio == null && ficha.temporadas.isNotEmpty)
        ficha.temporadas.map((t) => t.numero).reduce((a, b) => a > b ? a : b) +
            1,
    };
    final episodios = await Future.wait([
      for (final n in temporadas)
        // Una temporada que no existe (la siguiente) no rompe el resto
        TmdbService.obtenerEpisodiosTemporada(
          id,
          n,
          language,
        ).catchError((_) => <EpisodioModel>[]),
    ]);
    final porDia = <String, String>{};
    for (final e in episodios.expand((l) => l)) {
      if (_enRango(e.fechaEmision, f)) {
        porDia.putIfAbsent('$id|${e.fechaEmision}', () => e.etiqueta);
      }
    }
    return porDia.entries.toList();
  }

  EntradaCalendario _entradaSerie(SerieModel s, String dia, String etiqueta) =>
      EntradaCalendario(
        tipo: 'serie',
        fuente: 'tmdb',
        id: s.id,
        titulo: s.titulo,
        tituloOriginal: TmdbRefs.originalDistinto(s.tituloOriginal, s.titulo),
        etiqueta: etiqueta,
        posterUrl: s.posterUrl,
        claveDia: dia,
      );
}

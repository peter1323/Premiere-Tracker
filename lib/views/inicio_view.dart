import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/inicio_controller.dart';
import '../l10n/app_strings.dart';
import '../models/pelicula_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
import 'detalle_view.dart';
import 'persona_view.dart';
import 'widgets/selector_fuente.dart';
import 'widgets/tarjeta_persona.dart';
import 'widgets/tarjeta_resultado.dart';

/// Pantalla de Inicio: buscador (TMDB y TVMaze en paralelo) con
/// resultados en pestañas Series | Películas | Personas.
class InicioView extends StatefulWidget {
  const InicioView({super.key});

  @override
  State<InicioView> createState() => _InicioViewState();
}

class _InicioViewState extends State<InicioView>
    with SingleTickerProviderStateMixin {
  late final TabController _pestanas = TabController(length: 3, vsync: this);
  final TextEditingController _textoBuscador = TextEditingController();

  @override
  void dispose() {
    _pestanas.dispose();
    _textoBuscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El controlador vive con esta pantalla (se crea al entrar al Inicio)
    return ChangeNotifierProvider(
      create: (_) => InicioController(),
      child: _CuerpoInicio(
        controladorTexto: _textoBuscador,
        pestanas: _pestanas,
      ),
    );
  }
}

class _CuerpoInicio extends StatefulWidget {
  final TextEditingController controladorTexto;
  final TabController pestanas;

  const _CuerpoInicio({required this.controladorTexto, required this.pestanas});

  @override
  State<_CuerpoInicio> createState() => _CuerpoInicioState();
}

class _CuerpoInicioState extends State<_CuerpoInicio> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<InicioController>();
    final idioma = app.idioma;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila del buscador
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controladorTexto,
                  onSubmitted: (_) => _buscar(control, idioma),
                  decoration: InputDecoration(
                    hintText: t('buscarHint', idioma),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: t('cerrar', idioma),
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.controladorTexto.clear();
                        control.limpiarBusqueda();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed:
                    control.buscando ? null : () => _buscar(control, idioma),
                icon: const Icon(Icons.search),
                label: Text(t('buscar', idioma)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Avisos: APIs caídas, sin conexión o API key
          if (control.avisos.isNotEmpty)
            ...control.avisos.map((aviso) => _Aviso(texto: t(aviso, idioma))),

          // Contenido: resultados con pestañas, o estado vacío
          Expanded(child: _contenido(control, idioma)),
        ],
      ),
    );
  }

  void _buscar(InicioController control, String idioma) {
    control.buscar(widget.controladorTexto.text, idioma);
  }

  /// Muestra: cargando, resultados con pestañas o estado vacío.
  Widget _contenido(InicioController control, String idioma) {
    if (control.buscando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!control.hayConsulta) {
      // Sin búsqueda todavía: se invita a usar el buscador
      return _EstadoVacio(
        icono: Icons.search,
        texto: t('inicioVacio', idioma),
      );
    }
    if (!control.hayResultados) {
      return _EstadoVacio(
        icono: Icons.search_off,
        texto: t('sinResultados', idioma),
      );
    }

    // Pestañas Series | Películas | Personas con los resultados
    return Column(
      children: [
        TabBar(
          controller: widget.pestanas,
          tabs: [
            Tab(text: t('series', idioma)),
            Tab(text: t('peliculas', idioma)),
            Tab(text: t('personas', idioma)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: widget.pestanas,
            children: [
              _pestanaSeries(control, idioma),
              _pestanaPeliculas(control, idioma),
              _pestanaPersonas(control, idioma),
            ],
          ),
        ),
      ],
    );
  }

  /// Pestaña de series: selector de fuente + tarjetas.
  Widget _pestanaSeries(InicioController control, String idioma) {
    final app = context.read<AppController>();
    final series = control.seriesVisibles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector TMDB | TVMaze
        Row(
          children: [
            Text(t('fuente', idioma),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 12),
            SelectorFuente(
              valor: control.fuenteSeries,
              tmdbOk: control.tmdbOk,
              tvmazeOk: control.tvmazeOk,
              onChanged: control.cambiarFuenteSeries,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (series.isEmpty)
          Expanded(
            child: _EstadoVacio(
              icono: Icons.tv_off,
              texto: t('sinResultados', idioma),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: series
                    .map((s) => _tarjetaSerie(s, app, idioma))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  /// Pestaña de películas (solo TMDB).
  Widget _pestanaPeliculas(InicioController control, String idioma) {
    final app = context.read<AppController>();
    final peliculas = control.peliculasVisibles;

    if (peliculas.isEmpty) {
      return _EstadoVacio(
        icono: Icons.movie_filter_outlined,
        texto: t('sinResultados', idioma),
      );
    }
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: peliculas
            .map((p) => _tarjetaPelicula(p, app, idioma))
            .toList(),
      ),
    );
  }

  /// Pestaña de personas (TMDB y TVMaze fusionadas).
  Widget _pestanaPersonas(InicioController control, String idioma) {
    final personas = control.personasVisibles;

    if (personas.isEmpty) {
      return _EstadoVacio(
        icono: Icons.person_off_outlined,
        texto: t('sinResultados', idioma),
      );
    }
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: personas
            .map((p) => _tarjetaPersona(p, idioma))
            .toList(),
      ),
    );
  }

  Widget _tarjetaPersona(PersonaModel persona, String idioma) {
    return TarjetaPersona(
      nombre: persona.nombre,
      fotoUrl: persona.fotoUrl,
      departamento: persona.departamento,
      idioma: idioma,
      onAbrir: () {
        final language = idioma == 'es' ? 'es-ES' : 'en-US';
        PersonaView.abrir(context, persona, language);
      },
    );
  }

  Widget _tarjetaSerie(SerieModel serie, AppController app, String idioma) {
    final esFav =
        app.esFavorito(serie.fuente, 'serie', serie.id, titulo: serie.titulo);
    final language = idioma == 'es' ? 'es-ES' : 'en-US';
    return TarjetaResultado(
      titulo: serie.titulo,
      anio: serie.anio,
      posterUrl: serie.posterUrl,
      esFavorito: esFav,
      onFavorito: () => app.alternarFavoritoDeSerie(serie),
      esVisto: app.esVisto(serie.fuente, 'serie', serie.id,
          titulo: serie.titulo),
      onVisto: () => app.alternarVistoDeSerie(serie),
      onAbrir: () => DetalleView.abrirSerie(context, serie, language),
    );
  }

  Widget _tarjetaPelicula(
      PeliculaModel pelicula, AppController app, String idioma) {
    final esFav = app.esFavorito('tmdb', 'pelicula', pelicula.id,
        titulo: pelicula.titulo);
    final language = idioma == 'es' ? 'es-ES' : 'en-US';
    return TarjetaResultado(
      titulo: pelicula.titulo,
      anio: pelicula.anio,
      posterUrl: pelicula.posterUrl,
      esFavorito: esFav,
      onFavorito: () => app.alternarFavoritoDePelicula(pelicula),
      esVisto: app.esVisto('tmdb', 'pelicula', pelicula.id,
          titulo: pelicula.titulo),
      onVisto: () => app.alternarVistoDePelicula(pelicula),
      onAbrir: () => DetalleView.abrirPelicula(context, pelicula, language),
    );
  }
}

/// Banner de aviso (fuente caída, sin conexión, API key...).
class _Aviso extends StatelessWidget {
  final String texto;
  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: esquema.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: esquema.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: esquema.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío centrado (sin búsqueda o sin resultados).
class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _EstadoVacio({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            texto,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

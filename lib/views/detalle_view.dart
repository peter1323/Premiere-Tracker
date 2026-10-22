// VISTA de la ficha de una serie o película (se abre con Navigator.push).
// Muestra portada, datos generales, tu estado y nota, dónde verlo,
// reparto y recomendaciones (en filas con la
// rueda del ratón convertida en desplazamiento lateral), episodios por
// temporada, botones de favorito/visto y el campo de nota. Crea su
// DetalleController con ChangeNotifierProvider. El diálogo para escribir
// la nota es StatefulWidget que libera su TextEditingController en
// dispose(). Se destruye al volver atrás (por eso el controlador vigila
// si fue destruido).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/calendario_controller.dart';
import '../controllers/detalle_controller.dart';
import '../l10n/app_strings.dart';
import '../models/episodio_model.dart';
import '../models/favorito_model.dart';
import '../models/pelicula_model.dart';
import '../models/persona_model.dart';
import '../models/serie_model.dart';
import '../services/enlace_service.dart';
import 'manga_detalle_view.dart';
import 'persona_view.dart';
import 'widgets/fila_horizontal.dart';
import 'widgets/insignias.dart';
import 'widgets/selector_fuente.dart';
import 'widgets/nota_personal.dart';

/// Pantalla de detalle de una serie o película.
/// Se abre desde Inicio o Favoritos con uno de los métodos estáticos.
class DetalleView extends StatefulWidget {
  final String tipo; // 'serie' o 'pelicula'
  final int id;
  final String fuente; // 'tmdb' o 'tvmaze'
  final String? imdbId;
  final String? tituloInicial;
  final String language; // 'es-ES' o 'en-US'

  const DetalleView({
    super.key,
    required this.tipo,
    required this.id,
    required this.fuente,
    this.imdbId,
    this.tituloInicial,
    required this.language,
  });

  /// Abre el detalle de una serie.
  static void abrirSerie(
    BuildContext context,
    SerieModel serie,
    String language,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleView(
          tipo: 'serie',
          id: serie.id,
          fuente: serie.fuente,
          imdbId: serie.imdbId,
          tituloInicial: serie.titulo,
          language: language,
        ),
      ),
    );
  }

  /// Abre el detalle de una película.
  static void abrirPelicula(
    BuildContext context,
    PeliculaModel pelicula,
    String language,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleView(
          tipo: 'pelicula',
          id: pelicula.id,
          fuente: 'tmdb',
          tituloInicial: pelicula.titulo,
          language: language,
        ),
      ),
    );
  }

  /// Abre el detalle de un estreno del calendario o de Próximamente.
  static void abrirEntrada(
    BuildContext context,
    EntradaCalendario entrada,
    String language,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleView(
          tipo: entrada.tipo,
          id: entrada.id,
          fuente: entrada.fuente,
          imdbId: entrada.imdbId,
          tituloInicial: entrada.titulo,
          language: language,
        ),
      ),
    );
  }

  /// Abre el detalle desde un favorito guardado del usuario.
  static void abrirFavorito(
    BuildContext context,
    FavoritoModel favorito,
    String language,
  ) {
    // Los mangas y novelas guardados abren su propia ficha (AniList y
    // MangaDex), que no es la misma que la de series y películas.
    if (favorito.fuente == 'anilist') {
      MangaDetalleView.abrirFavorito(
        context,
        idManga: favorito.id,
        language: language,
      );
      return;
    }
    // Las personas abren su ficha, que recarga los datos de la API
    if (favorito.tipo == 'persona') {
      PersonaView.abrir(
        context,
        PersonaModel(
          id: favorito.id,
          fuente: favorito.fuente,
          nombre: favorito.titulo,
          fotoUrl: favorito.posterUrl,
        ),
        language,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleView(
          tipo: favorito.tipo,
          id: favorito.id,
          fuente: favorito.fuente,
          imdbId: favorito.imdbId,
          tituloInicial: favorito.titulo,
          language: language,
        ),
      ),
    );
  }

  @override
  State<DetalleView> createState() => _DetalleViewState();
}

class _DetalleViewState extends State<DetalleView> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DetalleController(
        tipo: widget.tipo,
        idInicial: widget.id,
        fuenteInicial: widget.fuente,
        imdbIdInicial: widget.imdbId,
        language: widget.language,
      )..cargar(),
      child: _CuerpoDetalle(
        tituloInicial: widget.tituloInicial,
        esSerie: widget.tipo == 'serie',
        language: widget.language,
      ),
    );
  }
}

class _CuerpoDetalle extends StatelessWidget {
  final String? tituloInicial;
  final bool esSerie;
  final String language; // 'es-ES' o 'en-US' (para la ficha de personas)

  const _CuerpoDetalle({
    this.tituloInicial,
    required this.esSerie,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<DetalleController>();
    final idioma = app.idioma;
    final tema = Theme.of(context);

    final titulo =
        control.serie?.titulo ??
        control.pelicula?.titulo ??
        tituloInicial ??
        '';

    // Datos que pueden venir de TMDB o de TVMaze
    final generos =
        control.serie?.generos ?? control.pelicula?.generos ?? const [];
    final reparto =
        control.serie?.reparto ?? control.pelicula?.reparto ?? const [];
    final canales = control.serie?.canales ?? const [];
    final dondeVer = control.serie?.dondeVer ?? control.pelicula?.dondeVer;

    return Scaffold(
      appBar: AppBar(title: Text(titulo, overflow: TextOverflow.ellipsis)),
      body:
          control.cargando && control.serie == null && control.pelicula == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Aviso si una fuente falló o no tiene la serie
                      if (control.aviso != null) ...[
                        _AvisoDetalle(texto: t(control.aviso!, idioma)),
                        const SizedBox(height: 16),
                      ],
                      // Cabecera: póster + datos + favorito
                      _cabecera(context, control, app, idioma, titulo),
                      const SizedBox(height: 24),
                      // Sinopsis
                      Text(
                        t('sinopsis', idioma),
                        style: tema.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sinopsis(control, idioma),
                        style: tema.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      // Géneros: Acción, Aventura, Drama...
                      if (generos.isNotEmpty) ...[
                        Text(
                          t('generos', idioma),
                          style: tema.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final g in generos)
                              Chip(label: Text(traducirGenero(g, idioma))),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Canales/redes por donde se emite (solo series)
                      if (esSerie && canales.isNotEmpty) ...[
                        Text(
                          t('canales', idioma),
                          style: tema.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in canales)
                              Chip(
                                avatar: Icon(Icons.tv_rounded, size: 16),
                                label: Text(c),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Dónde verlo en España (solo con datos de TMDB):
                      // cada plataforma abre la página con todas las
                      // opciones; TMDB exige citar a JustWatch.
                      if (dondeVer != null) ...[
                        Text(
                          t('dondeVer', idioma),
                          style: tema.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in dondeVer.plataformas)
                              ActionChip(
                                avatar: p.logo == null
                                    ? const Icon(Icons.play_circle_outline)
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(p.logo!),
                                      ),
                                label: Text(p.nombre),
                                onPressed: () =>
                                    EnlaceService.abrir(dondeVer.enlace),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('datosJustWatch', idioma),
                          style: tema.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Reparto (cada miembro abre su ficha de persona)
                      if (reparto.isNotEmpty) ...[
                        Text(
                          t('reparto', idioma),
                          style: tema.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        // Cada miembro abre su ficha de persona (si tiene id)
                        FilaHorizontal(
                          iconoSinImagen: Icons.person_outline,
                          elementos: [
                            for (final m in reparto)
                              (
                                imagen: m.fotoUrl,
                                titulo: m.nombre,
                                subtitulo: m.personaje,
                                onTap: m.idPersona == null || m.fuente == null
                                    ? null
                                    : () => PersonaView.abrir(
                                        context,
                                        PersonaModel(
                                          id: m.idPersona!,
                                          fuente: m.fuente!,
                                          nombre: m.nombre,
                                          fotoUrl: m.fotoUrl,
                                        ),
                                        language,
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Series: selector de fuente + temporadas
                      if (esSerie && control.serie != null) ...[
                        _SelectorFuenteDetalle(
                          control: control,
                          idioma: idioma,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t('temporadas', idioma),
                          style: tema.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...control.temporadas.map(
                          (temp) => _temporada(control, temp, idioma),
                        ),
                      ],
                      // Al final: "si te gustó esto..." (solo si TMDB
                      // devuelve algo; al tocar uno se abre su ficha)
                      ..._recomendaciones(context, control, idioma),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Sección de recomendaciones de TMDB: título y fila de pósters. Vacía
  /// (no se pinta nada, ni el título) si no hay ninguna.
  List<Widget> _recomendaciones(
    BuildContext context,
    DetalleController control,
    String idioma,
  ) {
    final elementos = <ElementoFila>[
      for (final s in control.recomendacionesSeries)
        (
          imagen: s.posterUrl,
          titulo: s.titulo,
          subtitulo: s.anio?.toString() ?? '',
          onTap: () => DetalleView.abrirSerie(context, s, language),
        ),
      for (final p in control.recomendacionesPeliculas)
        (
          imagen: p.posterUrl,
          titulo: p.titulo,
          subtitulo: p.anio?.toString() ?? '',
          onTap: () => DetalleView.abrirPelicula(context, p, language),
        ),
    ];
    if (elementos.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      Text(
        t('recomendaciones', idioma),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      FilaHorizontal(
        elementos: elementos,
        iconoSinImagen: Icons.movie_outlined,
      ),
    ];
  }

  String _sinopsis(DetalleController control, String idioma) {
    final texto = control.serie?.sinopsis ?? control.pelicula?.sinopsis ?? '';
    return texto.isEmpty ? t('sinSinopsis', idioma) : texto;
  }

  /// Cabecera con póster, título, estado, estreno y botón de favoritos.
  Widget _cabecera(
    BuildContext context,
    DetalleController control,
    AppController app,
    String idioma,
    String titulo,
  ) {
    final tema = Theme.of(context);
    final poster = control.serie?.posterUrl ?? control.pelicula?.posterUrl;
    final estado = control.serie?.estado ?? control.pelicula?.estado ?? '';
    final estreno =
        control.serie?.fechaEstreno ?? control.pelicula?.fechaEstreno ?? '';
    // Películas: fecha principal de TMDB (primer país del mundo); si no
    // coincide con la de España, se muestran las dos
    final mundial = control.pelicula?.fechaEstrenoMundial ?? '';
    final dosFechas = mundial.isNotEmpty && mundial != estreno;
    final puntuacion =
        control.serie?.puntuacion ?? control.pelicula?.puntuacion;
    // Nota formateada (p. ej. '7.6'); vacío si no hay puntuación.
    final textoPuntuacion = (puntuacion != null && puntuacion > 0)
        ? puntuacion.toStringAsFixed(1)
        : '';

    // ¿Está en favoritos del usuario actual? (título: la misma obra
    // puede venir de TMDB o TVMaze con ids distintos)
    final esFav = control.serie != null
        ? app.esFavorito(
            control.serie!.fuente,
            'serie',
            control.serie!.id,
            titulo: control.serie!.titulo,
          )
        : control.pelicula != null
        ? app.esFavorito(
            'tmdb',
            'pelicula',
            control.pelicula!.id,
            titulo: control.pelicula!.titulo,
          )
        : false;

    // ¿Está marcada como vista por el usuario actual?
    final esVisto = control.serie != null
        ? app.esVisto(
            control.serie!.fuente,
            'serie',
            control.serie!.id,
            titulo: control.serie!.titulo,
          )
        : control.pelicula != null
        ? app.esVisto(
            'tmdb',
            'pelicula',
            control.pelicula!.id,
            titulo: control.pelicula!.titulo,
          )
        : false;

    // Datos de la cabecera: título, estado, estreno y botones.
    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: tema.textTheme.headlineSmall),
        const SizedBox(height: 12),
        // Estado + puntuación (estrella con la nota media)
        if (estado.isNotEmpty || textoPuntuacion.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            children: [
              if (estado.isNotEmpty)
                Chip(
                  label: Text(_estadoTexto(estado, idioma)),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                ),
              if (textoPuntuacion.isNotEmpty)
                Tooltip(
                  message: t('puntuacion', idioma),
                  child: Chip(
                    avatar: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                    label: Text(textoPuntuacion),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (estreno.isNotEmpty) ...[
          // Con cuenta atrás si aún no se ha estrenado: "· en 3 días". Si la
          // película se estrenó antes en otro país, se ven las dos fechas.
          Text(
            [
              '${t(dosFechas ? 'estrenoEspana' : 'estreno', idioma)}: $estreno',
              ?enCuantoEstrena(estreno, idioma),
            ].join(' · '),
            style: tema.textTheme.bodyMedium,
          ),
          if (dosFechas)
            Text(
              '${t('estrenoMundial', idioma)}: $mundial',
              style: tema.textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
        ],
        // Próximo episodio destacado (solo series)
        if (esSerie && control.serie?.proximoEpisodio != null) ...[
          _proximoEpisodio(control.serie!.proximoEpisodio!, idioma),
          const SizedBox(height: 12),
        ],
        // Añadir/quitar de favoritos y de vistos (Wrap: en pantallas
        // estrechas los dos botones pasan a dos líneas en vez de cortarse)
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _alternarFavorito(control, app),
              icon: Icon(esFav ? Icons.favorite : Icons.favorite_border),
              label: Text(
                esFav
                    ? t('quitarFavoritos', idioma)
                    : t('anadirFavoritos', idioma),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _alternarVisto(control, app),
              icon: Icon(
                esVisto ? Icons.visibility : Icons.visibility_outlined,
              ),
              label: Text(
                esVisto ? t('quitarVistos', idioma) : t('anadirVistos', idioma),
              ),
            ),
          ],
        ),
        // Nota personal (solo si está en Favoritos o Vistos)
        if (control.serie != null)
          NotaPersonal(
            fuente: control.serie!.fuente,
            tipo: 'serie',
            id: control.serie!.id,
            titulo: control.serie!.titulo,
            estadoApi: control.serie!.estado,
            fechaEstreno: control.serie!.fechaEstreno,
          )
        else if (control.pelicula != null)
          NotaPersonal(
            fuente: 'tmdb',
            tipo: 'pelicula',
            id: control.pelicula!.id,
            titulo: control.pelicula!.titulo,
            estadoApi: control.pelicula!.estado,
            fechaEstreno: control.pelicula!.fechaEstreno,
          ),
      ],
    );

    // En pantallas estrechas (móvil vertical) la portada se pone arriba
    // y el texto ocupa todo el ancho; en anchas (escritorio u horizontal)
    // la portada sigue al lado. En pantallas bajas (horizontal de móvil)
    // la portada se reduce para equilibrar la cabecera.
    return LayoutBuilder(
      builder: (context, medidas) {
        final estrecho = medidas.maxWidth < 600;
        final alturaBaja = MediaQuery.of(context).size.height < 520;
        final anchoPoster = estrecho
            ? (medidas.maxWidth * 0.42).clamp(130.0, 180.0)
            : (alturaBaja ? 150.0 : 200.0);

        final posterWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: anchoPoster,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: poster == null
                  ? _marcador(context)
                  : Image.network(
                      poster,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          _marcador(context),
                    ),
            ),
          ),
        );

        if (estrecho) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: posterWidget),
              const SizedBox(height: 16),
              datos,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            posterWidget,
            const SizedBox(width: 24),
            Expanded(child: datos),
          ],
        );
      },
    );
  }

  void _alternarFavorito(DetalleController control, AppController app) {
    if (control.serie != null) {
      app.alternarFavoritoDeSerie(control.serie!);
    } else if (control.pelicula != null) {
      app.alternarFavoritoDePelicula(control.pelicula!);
    }
  }

  void _alternarVisto(DetalleController control, AppController app) {
    if (control.serie != null) {
      app.alternarVistoDeSerie(control.serie!);
    } else if (control.pelicula != null) {
      app.alternarVistoDePelicula(control.pelicula!);
    }
  }

  Widget _marcador(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  String _estadoTexto(String estado, String idioma) {
    switch (estado) {
      case SerieModel.estadoEnEmision:
        return t('enEmision', idioma);
      case SerieModel.estadoFinalizada:
        return t('finalizada', idioma);
      case SerieModel.estadoCancelada:
        return t('cancelada', idioma);
      case SerieModel.estadoEnProduccion:
        return t('enProduccion', idioma);
      case SerieModel.estadoPlaneada:
        return t('planeada', idioma);
      case PeliculaModel.estadoLanzada:
        return t('lanzada', idioma);
      default:
        return t('estadoDesconocido', idioma);
    }
  }

  /// Destaca el próximo episodio con su fecha.
  Widget _proximoEpisodio(EpisodioModel episodio, String idioma) {
    final fecha = episodio.fechaEmision.isEmpty
        ? t('proximamente', idioma)
        : episodio.fechaEmision;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('proximoEpisodio', idioma),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${episodio.etiqueta} · ${episodio.titulo} · $fecha'),
        ],
      ),
    );
  }

  /// Una temporada desplegable con sus episodios.
  Widget _temporada(
    DetalleController control,
    TemporadaModel temp,
    String idioma,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('${t('temporada', idioma)} ${temp.numero}'),
        subtitle: temp.totalEpisodios > 0
            ? Text('${temp.totalEpisodios} ${t('episodio', idioma)}')
            : null,
        onExpansionChanged: (abierto) {
          // TMDB: carga los episodios al abrir la temporada (perezoso)
          if (abierto && !control.episodiosCargados(temp.numero)) {
            control.cargarEpisodiosTemporada(temp.numero);
          }
        },
        children: [
          if (control.cargandoEpisodios &&
              !control.episodiosCargados(temp.numero))
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (control.episodiosDeTemporada(temp.numero).isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t('sinEpisodios', idioma)),
            )
          else
            ...control
                .episodiosDeTemporada(temp.numero)
                .map(
                  (e) => ListTile(
                    dense: true,
                    leading: Text(e.etiqueta),
                    title: Text(
                      e.titulo.isEmpty ? t('episodio', idioma) : e.titulo,
                    ),
                    trailing: Text(e.fechaEmision),
                  ),
                ),
        ],
      ),
    );
  }
}

/// Selector TMDB | TVMaze para las series.
class _SelectorFuenteDetalle extends StatelessWidget {
  final DetalleController control;
  final String idioma;

  const _SelectorFuenteDetalle({required this.control, required this.idioma});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          t('fuente', idioma),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: 12),
        SelectorFuente(
          valor: control.fuente,
          tmdbOk: control.tmdbOk,
          tvmazeOk: control.tvmazeOk,
          onChanged: control.cambiarFuente,
        ),
      ],
    );
  }
}

/// Aviso de fallo dentro del detalle.
class _AvisoDetalle extends StatelessWidget {
  final String texto;
  const _AvisoDetalle({required this.texto});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
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

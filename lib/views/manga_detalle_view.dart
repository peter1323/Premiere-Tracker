// VISTA de la ficha de un manga (se abre con Navigator.push). Puede abrir
// de dos formas: con el manga ya cargado (desde los resultados de
// Lectura) o solo con su id (desde Favoritos/Vistos), en cuyo caso trae
// la ficha completa desde AniList al iniciar (con spinner y pantalla de
// error si falla). Muestra portada, estado, datos, sinopsis, el último
// capítulo por idioma (de MangaDex) y los botones de favorito y «leído».
// Crea su MangaDetalleController, que se destruye al volver atrás.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/app_controller.dart';
import '../controllers/manga_detalle_controller.dart';
import '../l10n/app_strings.dart';
import '../models/manga_model.dart';
import '../services/anilist_service.dart';
import '../services/mangadex_service.dart';
import 'widgets/tarjeta_manga.dart';

/// Ficha de un manga: portada, estado (AniList), datos generales, sinopsis,
/// el último capítulo publicado (MangaDex) y botones para añadirlo a
/// favoritos o marcarlo como leído.
class MangaDetalleView extends StatefulWidget {
  /// La ficha ya cargada; null cuando se abre desde Favoritos o Vistos
  /// (entonces se trae por [idManga] directamente de AniList).
  final MangaModel? manga;
  final int? idManga;
  final String language; // 'es-ES' o 'en-US'

  const MangaDetalleView({
    super.key,
    this.manga,
    this.idManga,
    required this.language,
  });

  /// Abre la ficha de un manga.
  static void abrir(
    BuildContext context, {
    required MangaModel manga,
    required String language,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MangaDetalleView(manga: manga, language: language),
    ));
  }

  /// Abre la ficha de un manga guardado en favoritos o leídos, trayendo
  /// los datos completos desde AniList por su id.
  static void abrirFavorito(
    BuildContext context, {
    required int idManga,
    required String language,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MangaDetalleView(idManga: idManga, language: language),
    ));
  }

  @override
  State<MangaDetalleView> createState() => _MangaDetalleViewState();
}

class _MangaDetalleViewState extends State<MangaDetalleView> {
  MangaModel? _manga; // null mientras se trae por id desde AniList
  MangaDetalleController? _controlador;
  bool _cargandoFicha = false;

  @override
  void initState() {
    super.initState();
    final m = widget.manga;
    if (m != null) {
      _manga = m;
      _iniciarCapitulos(m);
    } else {
      _cargarPorId();
    }
  }

  /// Pide la ficha completa a AniList por id (al abrir desde Favoritos).
  Future<void> _cargarPorId() async {
    _cargandoFicha = true; // el primer build ya sale con el spinner
    try {
      final m = await AnilistService.cargarManga(widget.idManga!);
      _manga = m;
      _iniciarCapitulos(m);
    } catch (_) {
      _manga = null; // se queda en la pantalla de error
    }
    _cargandoFicha = false;
    if (mounted) setState(() {});
  }

  /// Crea el controlador de capítulos y arranca la búsqueda en MangaDex.
  /// Al terminar el controlador avisa y aquí se redibuja la ficha; sin
  /// esto el spinner se quedaría puesto para siempre (el estado cambiaba
  /// pero nadie lo escuchaba).
  void _iniciarCapitulos(MangaModel m) {
    final control = MangaDetalleController(m)..addListener(_alCambiar);
    _controlador = control;
    control.buscarDatos();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final control = _controlador;
    if (control != null) {
      control
        ..removeListener(_alCambiar)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final strings = app.idioma;
    final m = _manga;

    // Ficha cargándose desde AniList (desde Favoritos/Vistos) o fallo.
    if (m == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: _cargandoFicha
              ? const CircularProgressIndicator()
              : Text(t('errorCargarManga', strings)),
        ),
      );
    }

    final control = _controlador!;
    // Favorito y leído: se guardan igual que las series y películas.
    final tipoManga = m.formato == 'NOVEL' ? 'novela' : 'manga';
    final esFav = app.esFavorito('anilist', tipoManga, m.id, titulo: m.titulo);
    final esLeido = app.esVisto('anilist', tipoManga, m.id, titulo: m.titulo);
    // Sinopsis en español si MangaDex la tiene (cargada al abrir la ficha);
    // si no, la de AniList (casi siempre en inglés).
    final sinEs = control.sinopsisEs;
    String sinopsis = m.sinopsis;
    if (strings == 'es' && sinEs != null && sinEs.isNotEmpty) {
      sinopsis = sinEs;
    }
    final tama = MediaQuery.of(context).size.width;
    final doble = tama > 950;

    final portada = SizedBox(
      width: 240,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: m.portada.isEmpty
            ? const SizedBox(
                height: 340,
                child: Icon(Icons.menu_book_rounded, size: 60),
              )
            : Image.network(
                m.portada,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 340,
                  child: Icon(Icons.menu_book_rounded, size: 60),
                ),
              ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(m.titulo),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                portada,
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.titulo,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (m.tituloEnglish != null &&
                          m.tituloEnglish != m.titulo) ...[
                        const SizedBox(height: 4),
                        Text(
                          m.tituloEnglish!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChipEstadoManga(estado: m.estado, idioma: strings),
                          if (m.puntuacion != null)
                            _Dato(
                              icono: Icons.star_rounded,
                              texto:
                                  '${m.puntuacion!.toStringAsFixed(1)} / 10',
                            ),
                          // En emisión AniList aún no tiene el total: se
                          // muestra '?' para que se vea que se desconoce
                          // en lugar de no aparecer nada.
                          if (m.capitulos != null || m.estado == 'emision')
                            _Dato(
                              icono: Icons.menu_book_rounded,
                              texto:
                                  '${t('capitulos', strings)}: ${m.capitulos ?? '?'}',
                            ),
                          if (m.tomos != null || m.estado == 'emision')
                            _Dato(
                              icono: Icons.library_books_rounded,
                              texto:
                                  '${t('tomos', strings)}: ${m.tomos ?? '?'}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Guardar en Favoritos / Leídos (mismo sistema que
                      // las series y películas: se exportan igual).
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => app.alternarFavoritoDeManga(m),
                            icon: Icon(
                              esFav
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: esFav ? Colors.red : null,
                            ),
                            label: Text(esFav
                                ? t('quitarFavoritos', strings)
                                : t('anadirFavoritos', strings)),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => app.alternarVistoDeManga(m),
                            icon: Icon(
                              esLeido
                                  ? Icons.visibility
                                  : Icons.visibility_outlined,
                            ),
                            label: Text(esLeido
                                ? t('quitarLeidos', strings)
                                : t('anadirLeidos', strings)),
                          ),
                        ],
                      ),
                      if (m.formato.isNotEmpty || m.pais.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (m.formato.isNotEmpty)
                              _Etiqueta(
                                  texto:
                                      '${t('formato', strings)}: ${m.formato}'),
                            if (m.pais.isNotEmpty)
                              _Etiqueta(
                                texto:
                                    '${t('pais', strings)}: ${traducirPais(m.pais, strings)}',
                              ),
                          ],
                        ),
                      ],
                      if (m.fechaInicio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _Dato(
                          icono: Icons.event_rounded,
                          texto:
                              '${t('fechaInicio', strings)}: ${m.fechaInicio}',
                        ),
                      ],
                      if (m.autores.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Seccion(titulo: t('autores', strings)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: m.autores
                              .map((a) => _Etiqueta(texto: a))
                              .toList(),
                        ),
                      ],
                      if (m.generos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Seccion(titulo: t('generos', strings)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: m.generos
                              .map((g) => _Etiqueta(
                                  texto: traducirGenero(g, strings)))
                              .toList(),
                        ),
                      ],
                      if (sinopsis.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Seccion(titulo: t('sinopsis', strings)),
                        const SizedBox(height: 6),
                        Text(sinopsis),
                      ],
                      const SizedBox(height: 12),
                      _Seccion(titulo: t('ultimoCapitulo', strings)),
                      const SizedBox(height: 6),
                      _UltimoCapitulo(controlador: control),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (m.url.isNotEmpty)
                            FilledButton.icon(
                              onPressed: () => _abrirEnlace(m.url),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(t('verEnAniList', strings)),
                            ),
                          FilledButton.tonalIcon(
                            onPressed: () => _abrirEnlace(
                                'https://mangadex.org/search?q=${Uri.encodeComponent(m.titulo)}'),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(t('verEnMangaDex', strings)),
                          ),
                        ],
                      ),
                      if (!doble) const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Bloque del último capítulo en cada idioma: cargando, el capítulo de ese
/// idioma, o «No hay datos en ese idioma» si MangaDex no lo tiene.
class _UltimoCapitulo extends StatelessWidget {
  final MangaDetalleController controlador;
  const _UltimoCapitulo({required this.controlador});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final strings = app.idioma;

    if (controlador.cargandoCapitulo) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(t('buscandoCapitulo', strings)),
        ],
      );
    }

    // Una fila por idioma (código de MangaDex + etiqueta traducida).
    // Nota: MangaDex no separa el inglés de EE. UU. y del Reino Unido.
    final filas = [
      ('es', t('esEspana', strings)),
      ('es-la', t('esLatino', strings)),
      ('en', t('idiomaIngles', strings)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final fila in filas)
          _FilaIdioma(
            etiqueta: fila.$2,
            capitulo: controlador.capitulos[fila.$1],
          ),
      ],
    );
  }
}

/// Fila «Etiqueta: Capítulo 123 · 2026-10-08». Si ese idioma no tiene
/// capítulo publicado, se muestra «No hay datos en ese idioma».
class _FilaIdioma extends StatelessWidget {
  final String etiqueta;
  final CapituloManga? capitulo;
  const _FilaIdioma({required this.etiqueta, this.capitulo});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppController>().idioma;
    final tema = Theme.of(context).textTheme;
    // Variable local para que el análisis permita comparar con null.
    final cap = capitulo;
    final String dato;
    if (cap == null) {
      dato = t('sinDatosIdioma', strings);
    } else {
      final fecha = cap.fecha.isEmpty ? '' : ' · ${cap.fecha.split('T').first}';
      dato = '${t('capitulo', strings)} ${cap.numero ?? '—'}$fecha';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$etiqueta:',
              style: tema.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              dato,
              style: tema.bodySmall?.copyWith(
                color: cap == null ? Theme.of(context).hintColor : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea pequeña con icono (dato suelto: puntuación, capítulos, fecha...).
class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Dato({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Etiqueta con fondo suave (formato, país, géneros, capítulo...).
class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta({required this.texto});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// Título de sección (Sinopsis, Géneros, Último capítulo...).
class _Seccion extends StatelessWidget {
  final String titulo;
  const _Seccion({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

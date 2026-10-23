// VISTA de un género: se abre al tocar un género (Acción, Romance...) en
// la ficha de una serie, película, manga o novela, y muestra los títulos
// más populares de ese género del mismo tipo. Solo dibuja; la carga la
// hace GeneroController.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/genero_controller.dart';
import '../l10n/app_strings.dart';
import '../models/manga_model.dart';
import '../models/pelicula_model.dart';
import '../models/serie_model.dart';
import 'manga_detalle_view.dart';
import 'tarjetas_titulos.dart';
import 'widgets/estado_vacio.dart';
import 'widgets/rejilla_tarjetas.dart';
import 'widgets/tarjeta_manga.dart';

/// Pantalla con los títulos populares de un género.
class GeneroView extends StatelessWidget {
  const GeneroView({super.key});

  /// Abre el género [genero] para el [tipo] de ficha ('serie',
  /// 'pelicula' o el formato del manga: 'NOVEL', 'MANGA'...). Con
  /// [idPalabraClave] (TMDB) o [etiqueta] (AniList) abre esa palabra clave.
  static void abrir(
    BuildContext context, {
    required String tipo,
    required String genero,
    required String language,
    int? idPalabraClave,
    bool etiqueta = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => GeneroController(
            tipo: tipo,
            genero: genero,
            language: language,
            idPalabraClave: idPalabraClave,
            etiqueta: etiqueta,
          )..cargar(),
          child: const GeneroView(),
        ),
      ),
    );
  }

  /// Chips de géneros, o (con #) de palabras clave de TMDB
  /// ([palabrasClave]) o etiquetas de AniList ([etiquetas]). Cada uno abre
  /// su pantalla al tocarlo. La usan la ficha de series/películas y la de
  /// mangas/novelas.
  static Widget chips(
    BuildContext context, {
    List<String> generos = const [],
    required String tipo,
    List<PalabraClave> palabrasClave = const [],
    List<String> etiquetas = const [],
  }) {
    final idioma = context.read<AppController>().idioma;
    Widget chip(String texto, {int? id, bool etiqueta = false}) {
      final esClave = id != null || etiqueta;
      return ActionChip(
        avatar: esClave ? const Icon(Icons.tag, size: 16) : null,
        label: Text(esClave ? texto : traducirGenero(texto, idioma)),
        onPressed: () => abrir(
          context,
          tipo: tipo,
          genero: texto,
          language: idiomaApi(idioma),
          idPalabraClave: id,
          etiqueta: etiqueta,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in generos) chip(g),
        for (final k in palabrasClave) chip(k.nombre, id: k.id),
        for (final e in etiquetas) chip(e, etiqueta: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final idioma = context.watch<AppController>().idioma;
    final control = context.watch<GeneroController>();

    return Scaffold(
      appBar: AppBar(title: Text(traducirGenero(control.genero, idioma))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: control.cargando
            ? const Center(child: CircularProgressIndicator())
            : control.resultados.isEmpty
            ? EstadoVacio(
                icono: control.error ? Icons.cloud_off : Icons.search_off,
                texto: t(
                  control.error ? 'errorGenero' : 'sinResultados',
                  idioma,
                ),
              )
            : RejillaTarjetas(
                tarjetas: [
                  for (final r in control.resultados)
                    _tarjeta(context, r, idioma),
                ],
              ),
      ),
    );
  }

  /// Tarjeta según el tipo de resultado (serie, película o manga).
  Widget _tarjeta(BuildContext context, Object r, String idioma) => switch (r) {
    SerieModel s => tarjetaSerie(context, s),
    PeliculaModel p => tarjetaPelicula(context, p),
    // La tarjeta de manga reparte su alto: necesita uno fijo
    MangaModel m => SizedBox(
      height: 290,
      child: TarjetaManga(
        manga: m,
        idioma: idioma,
        onAbrir: () => MangaDetalleView.abrir(
          context,
          manga: m,
          language: idiomaApi(idioma),
        ),
      ),
    ),
    _ => const SizedBox.shrink(),
  };
}

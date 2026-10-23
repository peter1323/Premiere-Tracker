// Tarjetas de series y películas de una búsqueda (con favorito, visto y
// abrir ficha). Las comparten Inicio y la pantalla de un género para no
// repetir el mismo código.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/pelicula_model.dart';
import '../models/serie_model.dart';
import 'detalle_view.dart';
import 'widgets/tarjeta_resultado.dart';

/// Tarjeta de una serie: corazón y ojo guardan; tocarla abre su ficha.
Widget tarjetaSerie(BuildContext context, SerieModel serie) {
  final app = context.read<AppController>();
  return TarjetaResultado(
    titulo: serie.titulo,
    anio: serie.anio,
    posterUrl: serie.posterUrl,
    esFavorito: app.esFavorito(
      serie.fuente,
      'serie',
      serie.id,
      titulo: serie.titulo,
    ),
    onFavorito: () => app.alternarFavoritoDeSerie(serie),
    esVisto: app.esVisto(serie.fuente, 'serie', serie.id, titulo: serie.titulo),
    onVisto: () => app.alternarVistoDeSerie(serie),
    onAbrir: () =>
        DetalleView.abrirSerie(context, serie, idiomaApi(app.idioma)),
  );
}

/// Tarjeta de una película (siempre de TMDB).
Widget tarjetaPelicula(BuildContext context, PeliculaModel pelicula) {
  final app = context.read<AppController>();
  return TarjetaResultado(
    titulo: pelicula.titulo,
    anio: pelicula.anio,
    posterUrl: pelicula.posterUrl,
    esFavorito: app.esFavorito(
      'tmdb',
      'pelicula',
      pelicula.id,
      titulo: pelicula.titulo,
    ),
    onFavorito: () => app.alternarFavoritoDePelicula(pelicula),
    esVisto: app.esVisto(
      'tmdb',
      'pelicula',
      pelicula.id,
      titulo: pelicula.titulo,
    ),
    onVisto: () => app.alternarVistoDePelicula(pelicula),
    onAbrir: () =>
        DetalleView.abrirPelicula(context, pelicula, idiomaApi(app.idioma)),
  );
}

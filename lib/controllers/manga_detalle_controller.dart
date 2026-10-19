// CONTROLADOR de la ficha de un manga (se abre con Navigator.push desde
// los resultados de Lectura o desde Favoritos/Vistos).
// Enriquece el modelo que viene de AniList con el último capítulo
// publicado en MangaDex (por idioma) y, si existe, la sinopsis en
// español. Se crea en manga_detalle_view.dart y se DESTRUYE al volver
// atrás: por eso comprueba `if (_destruido) return;` antes de notificar
// tras el await (MangaDex puede tardar varios segundos).
import 'package:flutter/material.dart';

import '../models/manga_model.dart';
import '../services/mangadex_service.dart';

/// Lógica de la ficha de un manga: enriquece el modelo recibido de AniList
/// con el último capítulo publicado en MangaDex (en español si existe,
/// si no en inglés).
class MangaDetalleController extends ChangeNotifier {
  final MangaModel manga;
  MangaDetalleController(this.manga);

  Map<String, CapituloManga?> capitulos = {};
  String? sinopsisEs; // sinopsis en español de MangaDex (null si no hay)
  bool cargandoCapitulo = true;
  bool _destruido = false; // true si la vista ya se cerró (ficha cerrada)

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }

  /// Carga de MangaDex: el último capítulo de cada idioma (español de
  /// España, español latino e inglés) y, si existe, la sinopsis en español.
  /// Los idiomas sin datos quedan en null: la vista muestra «No hay datos
  /// en ese idioma».
  Future<void> buscarDatos() async {
    cargandoCapitulo = true;
    notifyListeners();
    final datos = await MangadexService.buscarDatosManga(manga.titulo);
    // Si el usuario cerró la ficha mientras cargaba, ya nadie escucha:
    // avisar daría error de aserción (controlador destruido).
    if (_destruido) return;
    capitulos = datos.capitulos;
    sinopsisEs = datos.sinopsisEs;
    cargandoCapitulo = false;
    notifyListeners();
  }
}

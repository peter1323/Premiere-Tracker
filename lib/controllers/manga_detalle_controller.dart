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

  /// Carga de MangaDex: el último capítulo de cada idioma (español de
  /// España, español latino e inglés) y, si existe, la sinopsis en español.
  /// Los idiomas sin datos quedan en null: la vista muestra «No hay datos
  /// en ese idioma».
  Future<void> buscarDatos() async {
    cargandoCapitulo = true;
    notifyListeners();
    final datos = await MangadexService.buscarDatosManga(manga.titulo);
    capitulos = datos.capitulos;
    sinopsisEs = datos.sinopsisEs;
    cargandoCapitulo = false;
    notifyListeners();
  }
}

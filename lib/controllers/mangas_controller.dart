// CONTROLADOR de la pantalla Lectura (sección 1 del menú).
// Maneja el buscador de mangas, manhwas, manhuas y novelas contra AniList,
// que es donde se separan por formato (MANGA/ONE_SHOT para cómics y NOVEL
// para novelas). Vive en el IndexedStack, así que no se destruye al
// cambiar de sección.
import 'package:flutter/material.dart';

import '../models/manga_model.dart';
import '../services/anilist_service.dart';

/// Lógica de la pantalla Mangas: busca en AniList los dos grupos de obra en
/// paralelo (cómics y novelas) y guarda los resultados para las dos
/// pestañas. No toca favoritos, vistos, notas ni el calendario.
///
/// En AniList manga, manhwa, manhua y novelas son todos type: MANGA; lo que
/// los separa es el formato (format: NOVEL = novela ligera), así que la
/// división se hace por formato y no por tipo.
class MangasController extends ChangeNotifier {
  // Pestaña 1: cómics — manga, manhwa, manhua y one-shots.
  static const List<String> formatosComic = ['MANGA', 'ONE_SHOT'];
  // Pestaña 2: novelas ligeras.
  static const List<String> formatosNovela = ['NOVEL'];

  // Resultados por pestaña.
  List<MangaModel> resultadosManga = [];
  List<MangaModel> resultadosNovela = [];
  bool cargando = false;
  bool busquedaHecha = false;
  bool huboError = false;
  String textoBuscado = '';

  /// Busca el texto en los dos grupos a la vez. Si uno falla, el otro se
  /// muestra igualmente y se marca [huboError].
  Future<void> buscar(String texto) async {
    final consulta = texto.trim();
    if (consulta.isEmpty) return;
    textoBuscado = consulta;
    cargando = true;
    huboError = false;
    notifyListeners();

    final resultados = await Future.wait([
      _buscarGrupo(consulta, formatosComic),
      _buscarGrupo(consulta, formatosNovela),
    ]);
    resultadosManga = resultados[0];
    resultadosNovela = resultados[1];

    cargando = false;
    busquedaHecha = true;
    notifyListeners();
  }

  /// Devuelve los resultados de un grupo de formatos; si falla, lista vacía
  /// y marca el error global (el fallo de uno no cancela al otro).
  Future<List<MangaModel>> _buscarGrupo(
    String texto,
    List<String> formatos,
  ) async {
    try {
      return await AnilistService.buscarMangas(texto, formatos);
    } catch (_) {
      huboError = true;
      return [];
    }
  }

  /// Limpia la pantalla y deja de mostrar resultados.
  void limpiar() {
    resultadosManga = [];
    resultadosNovela = [];
    busquedaHecha = false;
    huboError = false;
    textoBuscado = '';
    notifyListeners();
  }
}

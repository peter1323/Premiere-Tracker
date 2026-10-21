// CONTROLADOR de las pantallas Favoritos (sección 3) y Vistos (sección 4).
// Guarda la lista del usuario actual, el texto del buscador y el filtro
// activo (Todo / Series / Películas / Manga / Novelas). La lista no se
// guarda aquí: la recibe de AppController con sincronizar() (que solo
// avisa si algo ha cambiado de verdad, para no redibujar en bucle). Vive
// en el IndexedStack, no se destruye al cambiar de sección.
import 'package:flutter/foundation.dart';

import '../models/favorito_model.dart';

/// Lógica de Favoritos y Vistos: lista del usuario actual, buscador por
/// nombre y filtro por tipo.
class ListaGuardadaController extends ChangeNotifier {
  List<FavoritoModel> _lista = const [];
  String _consulta = '';
  String _filtro = 'todo'; // 'todo', 'serie', 'pelicula', 'manga' o 'novela'
  String _firma = '';

  /// Filtro activo.
  String get filtro => _filtro;

  /// ¿Tiene el usuario algo guardado en esta lista?
  bool get hayElementos => _lista.isNotEmpty;

  /// Elementos que pasan el filtro de tipo y el buscador por nombre.
  List<FavoritoModel> get filtrados {
    final texto = _consulta.trim().toLowerCase();
    return _lista.where((f) {
      final coincideTipo = _filtro == 'todo' || f.tipo == _filtro;
      final coincideTexto =
          texto.isEmpty || f.titulo.toLowerCase().contains(texto);
      return coincideTipo && coincideTexto;
    }).toList();
  }

  /// Mantiene la lista al día con la del usuario actual.
  /// Solo avisa si la lista ha cambiado de verdad.
  void sincronizar(List<FavoritoModel> lista) {
    final firma = lista.map((f) => f.idUnico).join('|');
    if (firma == _firma) return;
    _firma = firma;
    _lista = lista;
    notifyListeners();
  }

  /// Filtra por nombre (vacío = todos).
  void cambiarConsulta(String texto) {
    if (_consulta == texto) return;
    _consulta = texto;
    notifyListeners();
  }

  /// Cambia el filtro de tipo.
  void cambiarFiltro(String nuevoFiltro) {
    if (_filtro == nuevoFiltro) return;
    _filtro = nuevoFiltro;
    notifyListeners();
  }
}

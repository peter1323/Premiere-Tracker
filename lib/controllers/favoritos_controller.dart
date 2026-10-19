// CONTROLADOR de la pantalla Favoritos (sección 3 del menú).
// Guarda la lista de favoritos del usuario actual, el texto del buscador
// y el filtro activo (Todo / Series / Películas / Manga / Novelas). La
// lista no se guarda aquí: la recibe de AppController con syncFavoritos()
// (que solo avisa si algo ha cambiado de verdad, para no redibujar en
// bucle). Vive en el IndexedStack, no se destruye al cambiar de sección.
import 'package:flutter/foundation.dart';

import '../models/favorito_model.dart';

/// Lógica de la pantalla de Favoritos: lista del usuario actual,
/// buscador por nombre y filtro Todo / Series / Películas / Mangas /
/// Novelas.
class FavoritosController extends ChangeNotifier {
  List<FavoritoModel> _favoritos = const [];
  String _consulta = '';
  String _filtro = 'todo'; // 'todo', 'serie', 'pelicula', 'manga' o 'novela'
  String _firma = '';

  /// Texto escrito en el buscador.
  String get consulta => _consulta;

  /// Filtro activo ('todo', 'serie' o 'pelicula').
  String get filtro => _filtro;

  /// ¿Tiene el usuario algún favorito guardado?
  bool get hayFavoritos => _favoritos.isNotEmpty;

  /// Favoritos que pasan el filtro de tipo y el buscador por nombre.
  List<FavoritoModel> get favoritosFiltrados {
    final texto = _consulta.trim().toLowerCase();
    return _favoritos.where((f) {
      final coincideTipo = _filtro == 'todo' || f.tipo == _filtro;
      final coincideTexto =
          texto.isEmpty || f.titulo.toLowerCase().contains(texto);
      return coincideTipo && coincideTexto;
    }).toList();
  }

  /// Mantiene la lista al día con los favoritos del usuario actual.
  /// Solo avisa si la lista ha cambiado de verdad.
  void syncFavoritos(List<FavoritoModel> favoritos) {
    final firma = favoritos.map((f) => f.idUnico).join('|');
    if (firma == _firma) return;
    _firma = firma;
    _favoritos = favoritos;
    notifyListeners();
  }

  /// Filtra por nombre (vacío = todos).
  void cambiarConsulta(String texto) {
    if (_consulta == texto) return;
    _consulta = texto;
    notifyListeners();
  }

  /// Cambia el filtro de tipo (Todo | Series | Películas | Mangas |
  /// Novelas).
  void cambiarFiltro(String nuevoFiltro) {
    if (_filtro == nuevoFiltro) return;
    _filtro = nuevoFiltro;
    notifyListeners();
  }
}

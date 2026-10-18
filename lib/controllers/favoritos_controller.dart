import 'package:flutter/foundation.dart';

import '../models/favorito_model.dart';

/// Lógica de la pantalla de Favoritos: lista del usuario actual,
/// buscador por nombre y filtro Todo / Series / Películas.
class FavoritosController extends ChangeNotifier {
  List<FavoritoModel> _favoritos = const [];
  String _consulta = '';
  String _filtro = 'todo'; // 'todo', 'serie' o 'pelicula'
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

  /// Cambia el filtro de tipo (Todo | Series | Películas).
  void cambiarFiltro(String nuevoFiltro) {
    if (_filtro == nuevoFiltro) return;
    _filtro = nuevoFiltro;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import '../models/favorito_model.dart';

/// Lógica de la pantalla de Vistos: lista del usuario actual,
/// buscador por nombre y filtro Todo / Series / Películas.
class VistosController extends ChangeNotifier {
  List<FavoritoModel> _vistos = const [];
  String _consulta = '';
  String _filtro = 'todo'; // 'todo', 'serie' o 'pelicula'
  String _firma = '';

  /// Texto escrito en el buscador.
  String get consulta => _consulta;

  /// Filtro activo ('todo', 'serie' o 'pelicula').
  String get filtro => _filtro;

  /// ¿Tiene el usuario algo marcado como visto?
  bool get hayVistos => _vistos.isNotEmpty;

  /// Vistos que pasan el filtro de tipo y el buscador por nombre.
  List<FavoritoModel> get vistosFiltrados {
    final texto = _consulta.trim().toLowerCase();
    return _vistos.where((v) {
      final coincideTipo = _filtro == 'todo' || v.tipo == _filtro;
      final coincideTexto =
          texto.isEmpty || v.titulo.toLowerCase().contains(texto);
      return coincideTipo && coincideTexto;
    }).toList();
  }

  /// Mantiene la lista al día con los vistos del usuario actual.
  /// Solo avisa si la lista ha cambiado de verdad.
  void syncVistos(List<FavoritoModel> vistos) {
    final firma = vistos.map((v) => v.idUnico).join('|');
    if (firma == _firma) return;
    _firma = firma;
    _vistos = vistos;
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

// CONTROLADOR de la pantalla Notas (sección 6 del menú).
// Guarda la lista de notas del usuario actual y el texto del buscador.
// Las notas no se guardan aquí: las recibe de AppController con
// syncNotas(). Vive en el IndexedStack, no se destruye al cambiar de
// sección.
import 'package:flutter/foundation.dart';

import '../models/nota_model.dart';

/// Lógica de la pantalla de Notas: lista del usuario actual, ordenada
/// por edición reciente y con buscador por texto (título, última
/// vista o datos extra).
class NotasController extends ChangeNotifier {
  List<NotaModel> _notas = const [];
  String _consulta = '';
  String _firma = '';

  /// Texto escrito en el buscador.
  String get consulta => _consulta;

  /// ¿Tiene el usuario alguna nota guardada?
  bool get hayNotas => _notas.isNotEmpty;

  /// Notas que coinciden con el buscador, más recientes primero.
  List<NotaModel> get notasFiltradas {
    final texto = _consulta.trim().toLowerCase();
    final lista = _notas.where((n) {
      if (texto.isEmpty) return true;
      return n.titulo.toLowerCase().contains(texto) ||
          n.ultimaVista.toLowerCase().contains(texto) ||
          n.masDatos.toLowerCase().contains(texto);
    }).toList();
    // La más reciente arriba (fechaEdicion vacía = al final)
    lista.sort((a, b) {
      if (a.fechaEdicion.isEmpty && b.fechaEdicion.isEmpty) return 0;
      if (a.fechaEdicion.isEmpty) return 1;
      if (b.fechaEdicion.isEmpty) return -1;
      return b.fechaEdicion.compareTo(a.fechaEdicion);
    });
    return lista;
  }

  /// Mantiene la lista al día con las notas del usuario actual.
  /// Solo avisa si la lista ha cambiado de verdad. La firma incluye el
  /// contenido: al editar una nota el id no cambia, y sin esto la tabla
  /// seguiría mostrando los datos viejos.
  void syncNotas(List<NotaModel> notas) {
    final firma = notas
        .map((n) =>
            '${n.id}:${n.titulo}:${n.ultimaVista}:${n.masDatos}:${n.fechaEdicion}')
        .join('|');
    if (firma == _firma) return;
    _firma = firma;
    _notas = notas;
    notifyListeners();
  }

  /// Filtra por texto (vacío = todas).
  void cambiarConsulta(String texto) {
    if (_consulta == texto) return;
    _consulta = texto;
    notifyListeners();
  }
}

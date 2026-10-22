// CONTROLADOR de las pantallas Favoritos (sección 3) y Vistos (sección 4).
// Guarda la lista del usuario actual, el texto del buscador y el filtro
// activo (Todo / Series / Películas / Manga / Novelas / Personas), el
// filtro de estado y el orden (añadido o por tu nota; en Personas,
// añadido o alfabético). La lista no se
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
  // 'todo', 'serie', 'pelicula', 'manga', 'novela' o 'persona'
  String _filtro = 'todo';
  // 'todos', 'sin' (sin estado) o uno de FavoritoModel.estados
  String _filtroEstado = 'todos';
  // 'anadido' (orden en que se añadieron), 'nota', 'az' o 'za'
  String _orden = 'anadido';
  String _firma = '';

  String get filtro => _filtro;
  String get filtroEstado => _filtroEstado;
  String get orden => _orden;

  /// En Personas no hay estados: no se filtra por estado ni se ordena por
  /// nota, sino por orden de añadido o alfabético.
  bool get esPersonas => _filtro == 'persona';

  /// Órdenes que se pueden elegir con el filtro actual.
  List<String> get ordenes =>
      esPersonas ? const ['anadido', 'az', 'za'] : const ['anadido', 'nota'];

  /// Cuántos hay guardados de un tipo ('todo' = todos), para mostrarlo
  /// junto a cada filtro.
  int cuantos(String tipo) => tipo == 'todo'
      ? _lista.length
      : _lista.where((f) => f.tipo == tipo).length;

  /// ¿Tiene el usuario algo guardado en esta lista?
  bool get hayElementos => _lista.isNotEmpty;

  /// Elementos que pasan el filtro de tipo, el de estado y el buscador,
  /// en el orden elegido.
  List<FavoritoModel> get filtrados {
    final texto = _consulta.trim().toLowerCase();
    final lista = _lista.where((f) {
      final coincideTipo = _filtro == 'todo' || f.tipo == _filtro;
      final coincideEstado =
          esPersonas ||
          _filtroEstado == 'todos' ||
          (_filtroEstado == 'sin'
              ? f.estado == null
              : f.estado == _filtroEstado);
      final coincideTexto =
          texto.isEmpty || f.titulo.toLowerCase().contains(texto);
      return coincideTipo && coincideEstado && coincideTexto;
    }).toList();
    // A igualdad se respeta el orden en que se añadieron (el sort de Dart
    // no lo garantiza por sí solo)
    final posicion = {for (var i = 0; i < lista.length; i++) lista[i]: i};
    int comparar(FavoritoModel a, FavoritoModel b) => switch (_orden) {
      // Mayor nota primero; sin nota al final
      'nota' => (b.puntuacion ?? 0).compareTo(a.puntuacion ?? 0),
      'az' => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
      'za' => b.titulo.toLowerCase().compareTo(a.titulo.toLowerCase()),
      _ => 0,
    };
    lista.sort((a, b) {
      final c = comparar(a, b);
      return c != 0 ? c : posicion[a]!.compareTo(posicion[b]!);
    });
    return lista;
  }

  /// Mantiene la lista al día con la del usuario actual. Solo avisa si
  /// cambió de verdad (también el estado o la nota de algún elemento).
  void sincronizar(List<FavoritoModel> lista) {
    final firma = lista
        .map((f) => '${f.idUnico}:${f.estado}:${f.puntuacion}')
        .join('|');
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

  /// Cambia el filtro de tipo. Si el orden elegido no existe en el nuevo
  /// filtro (p. ej. "por nota" al entrar en Personas), vuelve al de añadido.
  void cambiarFiltro(String nuevoFiltro) {
    if (_filtro == nuevoFiltro) return;
    _filtro = nuevoFiltro;
    if (!ordenes.contains(_orden)) _orden = 'anadido';
    notifyListeners();
  }

  /// Cambia el filtro de estado ('todos', 'sin' o un estado).
  void cambiarFiltroEstado(String nuevo) {
    if (_filtroEstado == nuevo) return;
    _filtroEstado = nuevo;
    notifyListeners();
  }

  /// Cambia el orden (uno de [ordenes]).
  void cambiarOrden(String nuevo) {
    if (_orden == nuevo) return;
    _orden = nuevo;
    notifyListeners();
  }
}

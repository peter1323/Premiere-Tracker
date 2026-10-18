import 'package:flutter/foundation.dart';

import '../models/favorito_model.dart';
import '../services/almacenamiento_service.dart';
import '../services/copia_seguridad_service.dart';
import 'app_controller.dart';

/// Resultado de una importación de copia de seguridad.
class ResultadoAjustes {
  final String clave; // clave de traducción del mensaje
  final List<FavoritoModel> nuevos; // favoritos importados (sin duplicados)

  const ResultadoAjustes(this.clave, {this.nuevos = const []});
}

/// Lógica de la pantalla de Ajustes: idioma, tema, copia de seguridad
/// (exportar/importar JSON) y gestión de usuarios.
class AjustesController extends ChangeNotifier {
  final AppController app;
  AjustesController({required this.app});

  bool _ocupado = false;
  bool get ocupado => _ocupado;

  // ===== Copia de seguridad =====

  /// Exporta los favoritos, vistos y notas del usuario actual a un .json.
  /// Devuelve la clave del mensaje: 'exportadoOk', 'error', o ''
  /// si el usuario canceló el diálogo (sin mensaje).
  Future<String> exportarFavoritos() async {
    final usuario = app.usuarioActual;
    if (usuario == null) return 'error';
    _ocupado = true;
    notifyListeners();
    String clave;
    try {
      final ok = await CopiaSeguridadService.exportarFavoritos(
          usuario.nombre, usuario.favoritos, usuario.vistos, usuario.notas);
      clave = ok ? 'exportadoOk' : ''; // '' = cancelado por el usuario
    } catch (_) {
      clave = 'error';
    }
    _ocupado = false;
    notifyListeners();
    return clave;
  }

  /// Importa favoritos, vistos y notas desde un .json sin duplicarlos.
  /// Devuelve la clave del mensaje y los favoritos nuevos.
  Future<ResultadoAjustes> importarFavoritos() async {
    final usuario = app.usuarioActual;
    if (usuario == null) {
      return const ResultadoAjustes('error');
    }
    _ocupado = true;
    notifyListeners();

    ResultadoAjustes resultado;
    try {
      final importacion = await CopiaSeguridadService.importarFavoritos();
      if (importacion.cancelado) {
        resultado = const ResultadoAjustes('');
      } else if (!importacion.valido) {
        resultado = const ResultadoAjustes('archivoInvalido');
      } else {
        // Sin duplicados: se ignoran los que ya están en favoritos
        final existentes =
            usuario.favoritos.map((f) => f.idUnico).toSet();
        final nuevos = importacion.favoritos
            .where((f) => !existentes.contains(f.idUnico))
            .toList();
        for (final nuevo in nuevos) {
          await app.agregarFavorito(nuevo);
        }
        // Vistos: mismo criterio sin duplicados (agregarVisto ya lo
        // comprueba, pero se filtra antes para contar los nuevos)
        final vistosExistentes = usuario.vistos.map((v) => v.idUnico).toSet();
        final vistosNuevos = importacion.vistos
            .where((v) => !vistosExistentes.contains(v.idUnico))
            .toList();
        for (final nuevo in vistosNuevos) {
          await app.agregarVisto(nuevo);
        }
        // Notas: sin duplicar por id interna
        final notasExistentes = usuario.notas.map((n) => n.id).toSet();
        final notasNuevas = importacion.notas
            .where((n) => !notasExistentes.contains(n.id))
            .toList();
        for (final nueva in notasNuevas) {
          await app.agregarNota(nueva);
        }
        resultado = ResultadoAjustes('importadoOk', nuevos: nuevos);
      }
    } catch (_) {
      resultado = const ResultadoAjustes('errorImportar');
    }
    _ocupado = false;
    notifyListeners();
    return resultado;
  }

  // ===== Gestión de usuarios =====

  /// Cambia el nombre del usuario actual.
  /// Devuelve null si todo bien, o la clave del error.
  Future<String?> cambiarNombre(String nuevoNombre) async {
    final usuario = app.usuarioActual;
    if (usuario == null) return 'error';
    final nombre = nuevoNombre.trim();
    if (nombre.isEmpty) return 'nombreRequerido';
    if (nombre == usuario.nombre) return null;

    final actualizado = usuario.copyWith(nombre: nombre);
    await AlmacenamientoService.actualizarUsuario(actualizado);
    app.establecerUsuario(actualizado);
    return null;
  }

  /// Cambia el PIN del usuario actual. Pide el PIN actual para
  /// poder validarlo antes de guardarlo.
  /// Devuelve null si todo bien, o la clave del error.
  Future<String?> cambiarPin(String pinActual, String pinNuevo) async {
    final usuario = app.usuarioActual;
    if (usuario == null) return 'error';
    if (AlmacenamientoService.hashPin(pinActual) != usuario.pinHash) {
      return 'pinIncorrecto';
    }
    if (pinNuevo.length != 4) return 'pin4digitos';
    if (int.tryParse(pinNuevo) == null) return 'pinSoloNumeros';
    if (AlmacenamientoService.hashPin(pinNuevo) == usuario.pinHash) {
      return null; // mismo PIN, no hay nada que cambiar
    }

    final actualizado =
        usuario.copyWith(pinHash: AlmacenamientoService.hashPin(pinNuevo));
    await AlmacenamientoService.actualizarUsuario(actualizado);
    app.establecerUsuario(actualizado);
    return null;
  }

  /// Borra el usuario actual y todos sus datos (vuelve a la pantalla
  /// de usuarios).
  Future<void> borrarUsuario() async {
    final usuario = app.usuarioActual;
    if (usuario == null) return;
    await AlmacenamientoService.eliminarUsuario(usuario.id);
    app.cerrarSesion();
  }
}

// CONTROLADOR de la pantalla de Ajustes (sección 6 del menú).
// Reúne la lógica de idioma, tema, copia de seguridad (exportar/importar
// JSON de favoritos, vistos y notas) y gestión de usuarios. Vive en el
// IndexedStack de main.dart, así que NO se destruye al cambiar de sección.
// Se comunica con AppController (que tiene el usuario real) mediante el
// campo `app`.
import 'package:flutter/foundation.dart';

import '../services/almacenamiento_service.dart';
import '../services/copia_seguridad_service.dart';
import 'app_controller.dart';

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
        usuario.nombre,
        usuario.favoritos,
        usuario.vistos,
        usuario.notas,
      );
      clave = ok ? 'exportadoOk' : ''; // '' = cancelado por el usuario
    } catch (_) {
      clave = 'error';
    }
    _ocupado = false;
    notifyListeners();
    return clave;
  }

  /// Importa favoritos, vistos y notas desde un .json sin duplicarlos.
  /// Devuelve la clave del mensaje: 'importadoOk', 'archivoInvalido',
  /// 'errorImportar', 'error', o '' si el usuario canceló el diálogo.
  Future<String> importarFavoritos() async {
    if (app.usuarioActual == null) return 'error';
    _ocupado = true;
    notifyListeners();

    String clave;
    try {
      final importacion = await CopiaSeguridadService.importarFavoritos();
      if (importacion.cancelado) {
        clave = '';
      } else if (!importacion.valido) {
        clave = 'archivoInvalido';
      } else {
        await app.importar(
          importacion.favoritos,
          importacion.vistos,
          importacion.notas,
        );
        clave = 'importadoOk';
      }
    } catch (_) {
      clave = 'errorImportar';
    }
    _ocupado = false;
    notifyListeners();
    return clave;
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
    if (!AlmacenamientoService.pinValido(pinNuevo)) return 'pinSoloNumeros';
    if (AlmacenamientoService.hashPin(pinNuevo) == usuario.pinHash) {
      return null; // mismo PIN, no hay nada que cambiar
    }

    final actualizado = usuario.copyWith(
      pinHash: AlmacenamientoService.hashPin(pinNuevo),
    );
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

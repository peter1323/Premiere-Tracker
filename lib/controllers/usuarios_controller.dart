// CONTROLADOR de la pantalla de usuarios (la primera que se ve, antes de
// iniciar sesión). Carga la lista de usuarios guardados, crea usuarios
// nuevos y valida el PIN (con AlmacenamientoService). Se crea en
// main.dart junto a AppController y vive toda la sesión.
import 'package:flutter/foundation.dart';

import '../models/usuario_model.dart';
import '../services/almacenamiento_service.dart';

/// Lógica de la pantalla de usuarios: cargar, crear y validar el PIN.
class UsuariosController extends ChangeNotifier {
  List<UsuarioModel> _usuarios = [];
  bool _cargando = false;

  List<UsuarioModel> get usuarios => List.unmodifiable(_usuarios);
  bool get cargando => _cargando;

  /// Carga los usuarios guardados en el equipo.
  Future<void> cargarUsuarios() async {
    _cargando = true;
    notifyListeners();
    _usuarios = await AlmacenamientoService.cargarUsuarios();
    _cargando = false;
    notifyListeners();
  }

  /// Crea un usuario con nombre y PIN de 4 dígitos.
  /// Devuelve null si todo fue bien, o la clave del error traducido.
  Future<String?> crearUsuario(String nombre, String pin) async {
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) return 'nombreRequerido';
    if (pin.length != 4) return 'pin4digitos';
    if (int.tryParse(pin) == null) return 'pinSoloNumeros';

    final usuario = UsuarioModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombreLimpio,
      pinHash: AlmacenamientoService.hashPin(pin),
    );
    _usuarios = [..._usuarios, usuario];
    await AlmacenamientoService.agregarUsuario(usuario);
    notifyListeners();
    return null;
  }

  /// Comprueba si el PIN escrito es el del usuario.
  bool validarPin(UsuarioModel usuario, String pin) {
    if (pin.length != 4 || int.tryParse(pin) == null) return false;
    return AlmacenamientoService.hashPin(pin) == usuario.pinHash;
  }

  /// Cambia el PIN de un usuario (desde la pantalla de usuarios) tras
  /// validar el actual. Devuelve el error (null si todo bien) y el
  /// usuario actualizado, para entrar con él en la sesión (así ningún
  /// guardado posterior se lleva el PIN viejo).
  Future<({String? error, UsuarioModel? usuario})> cambiarPinDeUsuario(
      UsuarioModel usuario, String pinActual, String pinNuevo) async {
    if (!validarPin(usuario, pinActual)) {
      return (error: 'pinIncorrecto', usuario: null);
    }
    if (pinNuevo.length != 4) return (error: 'pin4digitos', usuario: null);
    if (int.tryParse(pinNuevo) == null) {
      return (error: 'pinSoloNumeros', usuario: null);
    }

    final actualizado =
        usuario.copyWith(pinHash: AlmacenamientoService.hashPin(pinNuevo));
    final i = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (i >= 0) {
      final nueva = [..._usuarios];
      nueva[i] = actualizado;
      _usuarios = nueva;
      notifyListeners();
    }
    await AlmacenamientoService.actualizarUsuario(actualizado);
    return (error: null, usuario: actualizado);
  }

  /// Pista de login: los dos primeros dígitos del PIN del usuario,
  /// recuperados del hash guardado. Devuelve '' si no se encuentra.
  String pistaPin(UsuarioModel usuario) =>
      AlmacenamientoService.pistaPin(usuario.pinHash);
}

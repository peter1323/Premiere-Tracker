// CONTROLADOR de la pantalla de usuarios (la primera que se ve, antes de
// iniciar sesión). Carga la lista de usuarios guardados, crea usuarios
// nuevos y valida el PIN (con AlmacenamientoService). Se crea en
// main.dart junto a AppController y vive toda la sesión.
import 'package:flutter/foundation.dart';

import '../models/usuario_model.dart';
import '../services/almacenamiento_service.dart';
import '../services/clave_service.dart';

/// Lógica de la pantalla de usuarios: cargar, crear y validar el PIN.
class UsuariosController extends ChangeNotifier {
  List<UsuarioModel> _usuarios = [];
  bool _cargando = false;
  String? _errorCarga;

  // Límite de tiempo de las operaciones locales: si el sistema no
  // responde, se muestra el error en vez de quedarse cargando para siempre.
  static const Duration _tiempoMax = Duration(seconds: 10);

  List<UsuarioModel> get usuarios => List.unmodifiable(_usuarios);
  bool get cargando => _cargando;

  /// Clave del error traducido si no se pudieron cargar los datos locales
  /// (null si todo fue bien).
  String? get errorCarga => _errorCarga;

  /// Carga los usuarios guardados en el equipo. Nunca deja la pantalla
  /// en carga eterna: si falla o no responde, deja el error visible.
  Future<void> cargarUsuarios() async {
    _cargando = true;
    _errorCarga = null;
    notifyListeners();
    try {
      _usuarios = await AlmacenamientoService.cargarUsuarios().timeout(
        _tiempoMax,
      );
    } catch (e) {
      debugPrint('Error cargando usuarios: $e');
      _usuarios = [];
      _errorCarga = 'errorAlmacenamiento';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Crea un usuario con nombre y PIN de 4 dígitos.
  /// Devuelve null si todo fue bien, o la clave del error traducido.
  Future<String?> crearUsuario(String nombre, String pin) async {
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) return 'nombreRequerido';
    if (pin.length != 4) return 'pin4digitos';
    if (!AlmacenamientoService.pinValido(pin)) return 'pinSoloNumeros';

    final usuario = UsuarioModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombreLimpio,
      pinHash: AlmacenamientoService.hashPin(pin),
    );
    try {
      // Se guarda primero en disco; solo entonces se añade a la lista
      // visible (si el guardado falla, no se muestra un usuario falso).
      await AlmacenamientoService.agregarUsuario(usuario).timeout(_tiempoMax);
    } catch (e) {
      debugPrint('Error guardando usuario: $e');
      return 'errorAlmacenamiento';
    }
    _usuarios = [..._usuarios, usuario];
    notifyListeners();
    return null;
  }

  /// Comprueba si el PIN escrito es el del usuario.
  bool validarPin(UsuarioModel usuario, String pin) {
    if (!AlmacenamientoService.pinValido(pin)) return false;
    return AlmacenamientoService.hashPin(pin) == usuario.pinHash;
  }

  /// Cambia el PIN de un usuario (desde la pantalla de usuarios) tras
  /// validar el actual. Devuelve el error (null si todo bien) y el
  /// usuario actualizado, para entrar con él en la sesión (así ningún
  /// guardado posterior se lleva el PIN viejo).
  Future<({String? error, UsuarioModel? usuario})> cambiarPinDeUsuario(
    UsuarioModel usuario,
    String pinActual,
    String pinNuevo,
  ) async {
    if (!validarPin(usuario, pinActual)) {
      return (error: 'pinIncorrecto', usuario: null);
    }
    if (pinNuevo.length != 4) return (error: 'pin4digitos', usuario: null);
    if (!AlmacenamientoService.pinValido(pinNuevo)) {
      return (error: 'pinSoloNumeros', usuario: null);
    }

    final actualizado = usuario.copyWith(
      pinHash: AlmacenamientoService.hashPin(pinNuevo),
    );
    try {
      await AlmacenamientoService.actualizarUsuario(actualizado)
          .timeout(_tiempoMax);
    } catch (e) {
      debugPrint('Error guardando PIN: $e');
      return (error: 'errorAlmacenamiento', usuario: null);
    }
    final i = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (i >= 0) {
      final nueva = [..._usuarios];
      nueva[i] = actualizado;
      _usuarios = nueva;
      notifyListeners();
    }
    return (error: null, usuario: actualizado);
  }

  /// Pista de login: los dos primeros dígitos del PIN del usuario,
  /// recuperados del hash guardado. Devuelve '' si no se encuentra.
  String pistaPin(UsuarioModel usuario) =>
      AlmacenamientoService.pistaPin(usuario.pinHash);

  // --- Clave TMDB (se configura en esta pantalla de usuarios) ---

  bool _comprobandoClave = false;

  /// true mientras se comprueba una clave contra TMDB.
  bool get comprobandoClave => _comprobandoClave;

  /// true si el usuario ya guardó una clave.
  bool get hayClaveTmdb => ClaveService.hayClave;

  /// Clave enmascarada para mostrar en pantalla (nunca la completa).
  String get claveTmdbEnmascarada => ClaveService.enmascarada;

  /// Guarda la clave en la app tras comprobarla con TMDB.
  /// Devuelve null si todo fue bien, o la clave del error traducido.
  Future<String?> guardarClaveTmdb(String texto) async {
    final clave = texto.trim();
    if (clave.isEmpty) return 'claveVacia';
    _comprobandoClave = true;
    notifyListeners();
    try {
      if (!await ClaveService.probar(clave)) return 'claveNoValida';
      await ClaveService.guardar(clave);
      return null;
    } catch (_) {
      return 'sinConexion';
    } finally {
      _comprobandoClave = false;
      notifyListeners();
    }
  }
}

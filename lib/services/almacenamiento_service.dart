// SERVICIO de almacenamiento local. Es el único sitio que guarda datos en
// el equipo: usa shared_preferences (almacenamiento clave-valor del SO) y
// guarda TODO bajo la clave 'usuarios' como un JSON con todos los usuarios
// y, dentro de cada uno, sus favoritos, vistos y notas. Usa una cola de
// escrituras para que dos guardados seguidos no se pisen. No dibuja nada.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario_model.dart';

/// Guarda y carga los datos locales (usuarios y sus datos) en el equipo.
/// Sin servidor ni base de datos externa: todo en SharedPreferences como JSON.
class AlmacenamientoService {
  static const String _claveUsuarios = 'usuarios';
  static const String _claveTemaGlobal = 'temaGlobal';

  /// Tema global ('claro' u 'oscuro'): el último tema usado por cualquier
  /// usuario. Se aplica en la pantalla de usuarios (sin sesión iniciada).
  static Future<String> cargarTemaGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveTemaGlobal) ?? 'claro';
  }

  /// Guarda el tema global para la próxima arrancada.
  static Future<void> guardarTemaGlobal(String tema) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveTemaGlobal, tema);
  }

  // Cola de escrituras: serializa las operaciones de modificar-guardar
  // para que dos cambios rápidos no se pisen (el segundo podría cargar
  // la lista antes de que el primero la guarde y perderlo).
  static Future<void> _colaEscrituras = Future.value();

  /// Encadena una operación de escritura al final de la cola.
  static Future<void> _serializar(Future<void> Function() operacion) {
    final resultado = _colaEscrituras.then((_) => operacion());
    // El error de una operación no corta la cola para las siguientes
    _colaEscrituras = resultado.catchError((_) {});
    return resultado;
  }

  /// Cifra el PIN con SHA-256 (nunca se guarda en texto plano).
  static String hashPin(String pin) {
    // Se añade una sal fija para dificultar ataques de diccionario
    final bytes = utf8.encode('premiere_tracker-$pin');
    return sha256.convert(bytes).toString();
  }

  /// Recupera los dos primeros dígitos del PIN a partir de su hash
  /// para la pista tras dos fallos. Solo hay 10.000 PINs de 4 dígitos:
  /// se prueba cuál da exactamente el hash guardado (milisegundos).
  /// Devuelve '' si ninguno coincide.
  static String pistaPin(String pinHash) {
    for (var i = 0; i < 10000; i++) {
      final pin = i.toString().padLeft(4, '0');
      if (hashPin(pin) == pinHash) return pin.substring(0, 2);
    }
    return '';
  }

  /// Carga todos los usuarios guardados.
  static Future<List<UsuarioModel>> cargarUsuarios() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_claveUsuarios);
    if (texto == null || texto.isEmpty) return [];
    try {
      final lista = jsonDecode(texto) as List<dynamic>;
      return lista
          .map((u) => UsuarioModel.fromJson(u as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return []; // archivo local corrupto: se empieza de cero
    }
  }

  /// Guarda la lista completa de usuarios.
  static Future<void> _guardarLista(List<UsuarioModel> usuarios) async {
    final prefs = await SharedPreferences.getInstance();
    final texto =
        jsonEncode(usuarios.map((u) => u.toJson()).toList());
    await prefs.setString(_claveUsuarios, texto);
  }

  /// Añade un usuario nuevo a la lista.
  static Future<void> agregarUsuario(UsuarioModel usuario) =>
      _serializar(() async {
        final usuarios = await cargarUsuarios();
        usuarios.add(usuario);
        await _guardarLista(usuarios);
      });

  /// Actualiza un usuario existente (nombre, PIN, tema, idioma, favoritos).
  static Future<void> actualizarUsuario(UsuarioModel usuario) =>
      _serializar(() async {
        final usuarios = await cargarUsuarios();
        final i = usuarios.indexWhere((u) => u.id == usuario.id);
        if (i >= 0) {
          usuarios[i] = usuario;
          await _guardarLista(usuarios);
        }
      });

  /// Borra un usuario por su id.
  static Future<void> eliminarUsuario(String id) => _serializar(() async {
        final usuarios = await cargarUsuarios();
        usuarios.removeWhere((u) => u.id == id);
        await _guardarLista(usuarios);
      });
}

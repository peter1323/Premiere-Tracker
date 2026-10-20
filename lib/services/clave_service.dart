// SERVICIO de la clave TMDB: la única fuente de la API key. Primero usa
// la que el usuario guardó en la app (SharedPreferences, almacenamiento
// privado del dispositivo) y, si no hay, la del archivo .env (escritorio).
// La clave nunca va escrita en el código ni se muestra completa. También
// centraliza la autenticación (clave v3 por parámetro o token v4 con
// cabecera Bearer) y comprueba una clave nueva contra TMDB antes de
// guardarla. No dibuja nada.
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Carga, guardado y comprobación de la clave TMDB.
class ClaveService {
  static const String _preferencia = 'tmdb_key';
  static const String _ejemplo = 'TU_CLAVE_AQUI';
  static const String _base = 'https://api.themoviedb.org/3';
  static const Duration _timeout = Duration(seconds: 10);

  // Estado en memoria (se rellena en cargar()).
  static String _clave = '';
  static String _entorno = '';
  static bool _enApp = false;

  /// Carga el estado al arrancar: el .env (si existe) y, con prioridad,
  /// la clave guardada en la app. Nunca lanza excepciones.
  static Future<void> cargar() async {
    _entorno =
        dotenv.isInitialized ? (dotenv.env['TMDB_API_KEY'] ?? '').trim() : '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardada = (prefs.getString(_preferencia) ?? '').trim();
      _enApp = guardada.isNotEmpty;
      _clave = guardada.isNotEmpty ? guardada : _entorno;
    } catch (_) {
      // Sin preferencias disponibles: se usa solo la del .env
      _enApp = false;
      _clave = _entorno;
    }
  }

  /// Clave efectiva en uso (vacía si no hay ninguna).
  static String get clave => _clave;

  /// true si hay una clave utilizable (no vacía ni el texto de ejemplo).
  static bool get hayClave => _clave.isNotEmpty && _clave != _ejemplo;

  /// true si la clave activa está guardada en la app (no en el .env).
  static bool get guardadaEnApp => _enApp;

  /// true si el .env contiene una clave (para poder volver a ella).
  static bool get hayClaveEnEntorno =>
      _entorno.isNotEmpty && _entorno != _ejemplo;

  /// Clave enmascarada para pantalla: solo los cuatro últimos caracteres.
  static String get enmascarada {
    if (_clave.length <= 4) return '••••';
    return '••••${_clave.substring(_clave.length - 4)}';
  }

  /// Los tokens v4 de TMDB (JWT) empiezan por eyJ.
  static bool get _esToken => _clave.startsWith('eyJ');

  /// Parámetros de autenticación para TMDB (clave v3 por query).
  static Map<String, String> get parametrosAuth =>
      _esToken ? const {} : {'api_key': _clave};

  /// Cabeceras de autenticación para TMDB (token v4 con Bearer).
  static Map<String, String> get cabeceras =>
      _esToken ? {'Authorization': 'Bearer $_clave'} : const {};

  /// Guarda la clave en la app; toda la app la usa a partir de ese momento.
  static Future<void> guardar(String claveNueva) async {
    final limpia = claveNueva.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencia, limpia);
    _clave = limpia;
    _enApp = true;
  }

  /// Elimina la clave guardada en la app y vuelve a la del .env.
  static Future<void> restaurarEntorno() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_preferencia);
    _enApp = false;
    _clave = _entorno;
  }

  /// Comprueba una clave contra TMDB (/3/configuration): true si la
  /// acepta, false si la rechaza (401/403) y excepción si TMDB no
  /// responde bien o no hay conexión.
  static Future<bool> probar(String claveNueva) async {
    final esToken = claveNueva.startsWith('eyJ');
    final uri = Uri.parse('$_base/configuration').replace(
      queryParameters: esToken ? null : {'api_key': claveNueva},
    );
    final respuesta = await http
        .get(
          uri,
          headers:
              esToken ? {'Authorization': 'Bearer $claveNueva'} : const {},
        )
        .timeout(_timeout);
    if (respuesta.statusCode == 200) return true;
    if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
      return false;
    }
    throw Exception('TMDB respondió ${respuesta.statusCode}');
  }
}

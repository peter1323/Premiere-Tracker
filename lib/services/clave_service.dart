// SERVICIO de la clave TMDB: la única fuente de la API key. La clave la
// escribe el usuario en la pantalla de usuarios y se guarda en el
// dispositivo (SharedPreferences, almacenamiento privado). La clave nunca
// va escrita en el código ni se muestra completa. También centraliza la
// autenticación (clave v3 por parámetro o token v4 con cabecera Bearer) y
// comprueba una clave nueva contra TMDB antes de guardarla. No dibuja nada.
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Carga, guardado y comprobación de la clave TMDB.
class ClaveService {
  static const String _preferencia = 'tmdb_key';
  static const String _base = 'https://api.themoviedb.org/3';
  static const Duration _timeout = Duration(seconds: 10);

  // Clave en memoria (se rellena en cargar() y guardar()).
  static String _clave = '';

  /// Carga la clave guardada en la app al arrancar. Nunca lanza excepciones.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _clave = (prefs.getString(_preferencia) ?? '').trim();
    } catch (_) {
      _clave = ''; // sin preferencias disponibles: sin clave
    }
  }

  /// true si hay una clave guardada.
  static bool get hayClave => _clave.isNotEmpty;

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
  }

  /// Comprueba una clave contra TMDB (/3/configuration): true si la
  /// acepta, false si la rechaza (401/403) y excepción si TMDB no
  /// responde bien o no hay conexión.
  static Future<bool> probar(String claveNueva) async {
    final esToken = claveNueva.startsWith('eyJ');
    final uri = Uri.parse('$_base/configuration')
        .replace(queryParameters: esToken ? null : {'api_key': claveNueva});
    final respuesta = await http
        .get(
          uri,
          headers: esToken ? {'Authorization': 'Bearer $claveNueva'} : const {},
        )
        .timeout(_timeout);
    if (respuesta.statusCode == 200) return true;
    if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
      return false;
    }
    throw Exception('TMDB respondió ${respuesta.statusCode}');
  }
}

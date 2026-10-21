// SERVICIO de enlaces: abre una dirección web en el navegador del sistema.
// Es el único sitio de la app que usa url_launcher (créditos de TVMaze,
// fichas de AniList/TMDB, página de la clave TMDB y "dónde verlo").
// No dibuja nada.
import 'package:url_launcher/url_launcher.dart';

/// Apertura de enlaces externos.
class EnlaceService {
  /// Abre [url] en el navegador (fuera de la app). Si la dirección no es
  /// válida o no hay app que la abra, no hace nada.
  static Future<void> abrir(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

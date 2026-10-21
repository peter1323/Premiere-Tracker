// SERVICIO de avisos de estreno (solo Android). Con la lista de
// Próximamente (estrenos de los favoritos de hoy a 6 días) programa una
// notificación del sistema a las 10:00 del día de cada estreno:
// "Hoy se estrena · T1E4 · Dragon Ball Super: Beerus". Las notificaciones
// salen aunque la app esté cerrada, y se reprograman cada vez que esa
// lista cambia (al abrir la app o al cambiar los favoritos).
// En Windows no hace nada. No dibuja nada.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../controllers/calendario_controller.dart';
import '../l10n/app_strings.dart';

/// Programa los avisos de estreno en Android.
class AvisosService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false; // true tras iniciar() en Android
  static String _firma = ''; // lo último programado, para no repetirlo
  static bool _permisoPedido = false; // el permiso se pide una sola vez

  // Canal de Android "Estrenos" (el usuario puede silenciarlo en Ajustes)
  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails('estrenos', 'Estrenos'),
  );

  /// Prepara el plugin al arrancar la app. En Windows no hace nada.
  static Future<void> iniciar() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      tz.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Avisos no disponibles: $e'); // la app sigue sin avisos
    }
  }

  /// Sustituye los avisos programados por los de [estrenos]. Si la lista
  /// no ha cambiado desde la última vez, no hace nada.
  static Future<void> programar(
    List<EntradaCalendario> estrenos,
    String idioma,
  ) async {
    if (!_listo) return;
    final firma =
        '$idioma|${estrenos.map((e) => '${e.claveDia}${e.texto}').join('|')}';
    if (firma == _firma) return;
    _firma = firma;
    try {
      // Android 13+: se pide permiso UNA vez, cuando ya hay algo que
      // avisar. Sin esperar la respuesta: los avisos se programan igual y
      // salen en cuanto se conceda. Pedirlo con la ventana aún abierta da
      // error en Android, por eso no se repite.
      if (estrenos.isNotEmpty && !_permisoPedido) {
        _permisoPedido = true;
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission()
            .catchError((_) => null);
      }
      await _plugin.cancelAll();
      final ahora = DateTime.now();
      for (var i = 0; i < estrenos.length; i++) {
        final dia = DateTime.parse(estrenos[i].claveDia);
        // shortcut: siempre a las 10:00 hora local; la hora de emisión
        // viene en la zona de la cadena (p. ej. Japón), habría que
        // convertirla si se quiere el aviso a la hora exacta.
        final cuando = DateTime(dia.year, dia.month, dia.day, 10);
        if (cuando.isBefore(ahora)) continue; // hoy ya pasaron las 10:00
        await _plugin.zonedSchedule(
          id: i,
          // Instante absoluto: la hora local de arriba pasada a UTC
          scheduledDate: tz.TZDateTime.from(cuando, tz.UTC),
          notificationDetails: _detalles,
          // Inexacto: no necesita el permiso de alarmas exactas
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: t('avisoHoy', idioma),
          body: estrenos[i].texto,
        );
      }
    } catch (e) {
      _firma = ''; // se reintentará la próxima vez
      debugPrint('No se pudieron programar los avisos: $e');
    }
  }
}

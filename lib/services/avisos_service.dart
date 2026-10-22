// SERVICIO de avisos de estreno. Texto común: «Hoy estrena: Título» o
// «Hoy sale el episodio T1E4 de Serie».
// - Android: con la lista de Próximamente (favoritos de hoy a 6 días)
//   programa una notificación a las 10:00 del día de cada estreno; salen
//   aunque la app esté cerrada y se reprograman cuando la lista cambia.
// - Windows: avisa al momento de los estrenos de HOY que le pasa
//   AvisosController (al abrir la app y cada hora), una sola vez por
//   estreno: lo ya avisado se guarda en el equipo. Sin la app abierta no
//   avisa (no hay servicio en segundo plano).
// En el resto de plataformas no hace nada. No dibuja nada.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../controllers/calendario_controller.dart';
import '../l10n/app_strings.dart';

/// Avisos de estreno en Android (programados) y Windows (al momento).
class AvisosService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false; // true tras iniciar() en Android o Windows
  static String _firma = ''; // Android: lo último programado
  static bool _permisoPedido = false; // Android: se pide una sola vez
  static const _avisados = 'avisosMostrados'; // Windows: ya avisados hoy

  static bool get _esAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get _esWindows => defaultTargetPlatform == TargetPlatform.windows;

  // Canal de Android "Estrenos" (el usuario puede silenciarlo en Ajustes)
  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails('estrenos', 'Estrenos'),
  );

  /// Prepara el plugin al arrancar la app (solo Android y Windows).
  static Future<void> iniciar() async {
    if (!_esAndroid && !_esWindows) return;
    try {
      tz.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          windows: WindowsInitializationSettings(
            appName: 'Premiere Tracker',
            appUserModelId: 'Peter1323.PremiereTracker',
            guid: 'b6d1a2f4-3c8e-4f7a-9d21-5e0c7a4b9f13',
          ),
        ),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Avisos no disponibles: $e'); // la app sigue sin avisos
    }
  }

  /// Texto del aviso de un estreno: película o episodio.
  static String textoAviso(EntradaCalendario e, String idioma) =>
      e.etiqueta.isEmpty
      ? tv('avisoHoyPelicula', idioma, {'titulo': e.titulo})
      : tv('avisoHoyEpisodio', idioma, {'n': e.etiqueta, 'titulo': e.titulo});

  /// Identifica un aviso (obra, episodio y día) para no repetirlo.
  static String claveAviso(EntradaCalendario e) =>
      '${e.tipo}-${e.fuente}-${e.id}-${e.etiqueta}|${e.claveDia}';

  /// De [estrenos], los del día [hoy] ('yyyy-MM-dd') aún no avisados.
  static List<EntradaCalendario> pendientes(
    List<EntradaCalendario> estrenos,
    Set<String> avisados,
    String hoy,
  ) => estrenos
      .where((e) => e.claveDia == hoy && !avisados.contains(claveAviso(e)))
      .toList();

  /// Android: sustituye los avisos programados por los de [estrenos] (lista
  /// vacía = ninguno, p. ej. con los avisos desactivados). Si la lista no
  /// ha cambiado desde la última vez, no hace nada.
  static Future<void> programar(
    List<EntradaCalendario> estrenos,
    String idioma,
  ) async {
    if (!_listo || !_esAndroid) return;
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
          title: 'Premiere Tracker',
          body: textoAviso(estrenos[i], idioma),
        );
      }
    } catch (e) {
      _firma = ''; // se reintentará la próxima vez
      debugPrint('No se pudieron programar los avisos: $e');
    }
  }

  /// Windows: avisa ya de los estrenos de hoy de [estrenos] que no se
  /// hayan avisado antes (aunque su hora ya haya pasado).
  static Future<void> avisarHoy(
    List<EntradaCalendario> estrenos,
    String idioma,
  ) async {
    if (!_listo || !_esWindows) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hoy = claveDia(DateTime.now());
      // Solo se recuerdan los de hoy: los de otros días ya no sirven
      final avisados = (prefs.getStringList(_avisados) ?? [])
          .where((c) => c.endsWith('|$hoy'))
          .toSet();
      for (final e in pendientes(estrenos, avisados, hoy)) {
        await _plugin.show(
          id: avisados.length,
          title: 'Premiere Tracker',
          body: textoAviso(e, idioma),
        );
        avisados.add(claveAviso(e));
        // Se guarda tras cada aviso: si la app se cierra, no se repite
        await prefs.setStringList(_avisados, avisados.toList());
      }
    } catch (e) {
      debugPrint('No se pudo avisar de los estrenos: $e');
    }
  }
}

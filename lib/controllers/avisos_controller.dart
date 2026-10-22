// CONTROLADOR de las notificaciones de escritorio (SOLO Windows). Mientras
// hay una sesión abierta, al entrar y cada hora busca los estrenos de HOY
// (con el mismo cálculo y caché que el calendario) entre los Favoritos y lo
// marcado como «Planeado» o «En emisión», y se los pasa a AvisosService,
// que avisa una sola vez por estreno. Si el usuario los desactiva en
// Ajustes no hace nada. En Android no se usa (allí los avisos se programan
// desde Próximamente). No dibuja nada.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/app_strings.dart';
import '../models/favorito_model.dart';
import '../services/avisos_service.dart';
import 'app_controller.dart';
import 'calendario_controller.dart';

/// Comprobación periódica de los estrenos de hoy en Windows.
class AvisosController {
  final AppController app;
  Timer? _reloj;

  AvisosController(this.app);

  /// Empieza a comprobar (ahora y cada hora). En Android no hace nada.
  void iniciar() {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    _comprobar();
    _reloj = Timer.periodic(const Duration(hours: 1), (_) => _comprobar());
  }

  /// Deja de comprobar (al cerrar la sesión).
  void detener() => _reloj?.cancel();

  /// Carga los estrenos de hoy de los contenidos avisables y avisa.
  Future<void> _comprobar() async {
    if (!app.avisosActivados) return;
    // Controlador nuevo cada vez: así "hoy" es siempre el día actual
    final hoy = CalendarioController(modo: 'dia');
    await hoy.syncFavoritos(
      avisables(app.favoritos, app.vistos),
      idiomaApi(app.idioma),
    );
    await AvisosService.avisarHoy(hoy.proximas, app.idioma);
  }

  /// Contenidos de los que se avisa: los Favoritos y lo marcado como
  /// «Planeado» o «En emisión» (esté en Favoritos o en Vistos), sin
  /// repetir. El calendario ya descarta mangas y personas.
  static List<FavoritoModel> avisables(
    List<FavoritoModel> favoritos,
    List<FavoritoModel> vistos,
  ) {
    final ids = favoritos.map((f) => f.idUnico).toSet();
    return [
      ...favoritos,
      ...vistos.where(
        (v) =>
            (v.estado == 'planeado' || v.estado == 'enEmision') &&
            ids.add(v.idUnico),
      ),
    ];
  }
}

// WIDGET de Inicio: "Próximamente", los estrenos de los FAVORITOS del
// usuario de hoy a 6 días vista (series y películas, igual que el
// calendario). Usa un CalendarioController en modo 'proximos' que crea
// InicioView, y con esa misma lista programa los avisos de Android.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../controllers/calendario_controller.dart';
import '../../l10n/app_strings.dart';
import '../../services/avisos_service.dart';
import '../detalle_view.dart';
import 'fila_estreno.dart';

/// Lista de próximos estrenos; si no hay ninguno muestra [vacio].
class ProximosEstrenos extends StatelessWidget {
  final Widget vacio;
  const ProximosEstrenos({super.key, required this.vacio});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<CalendarioController>();
    final idioma = app.idioma;
    final esquema = Theme.of(context).colorScheme;
    final proximas = control.proximas;

    // Tras el build (no se puede notificar durante él): mantiene la lista
    // al día con los favoritos y, ya cargada, reprograma los avisos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      control.syncFavoritos(app.favoritos, idiomaApi(idioma));
      // Sin red no se tocan los avisos ya programados
      if (!control.calendarioCargando && control.avisoCalendario == null) {
        AvisosService.programar(proximas, idioma);
      }
    });

    if (proximas.isEmpty) {
      return control.calendarioCargando
          ? const Center(child: CircularProgressIndicator())
          : vacio;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('proximosEstrenos', idioma),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final e in proximas)
                FilaEstreno(
                  entrada: e,
                  // Mismos colores que el calendario: series y películas
                  color: e.tipo == 'serie' ? esquema.primary : esquema.tertiary,
                  prefijo: _cuando(e, idioma),
                  onTap: () =>
                      DetalleView.abrirEntrada(context, e, idiomaApi(idioma)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Dom 25/10" y la hora si la hay: "Dom 25/10 · 23:00".
  String _cuando(EntradaCalendario e, String idioma) {
    final fecha = DateTime.parse(e.claveDia);
    final dia =
        '${diaCorto(fecha, idioma)} ${fecha.day}/${fecha.month.toString().padLeft(2, '0')}';
    return e.hora.isEmpty ? dia : '$dia · ${e.hora}';
  }
}

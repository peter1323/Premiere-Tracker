// VISTA de la pantalla Calendario (sección 2 del menú). Es la carcasa que
// crea CalendarioController con ChangeNotifierProvider y le pasa el
// calendario (widget de la carpeta widgets/). Solo dibuja la estructura y
// delega la lógica de estrenos en el controlador. Vive en el IndexedStack.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/calendario_controller.dart';
import 'detalle_view.dart';
import 'widgets/calendario.dart';

/// Pantalla de Calendario: estrenos y episodios de los favoritos con
/// vistas de día, semana, mes y año, pestañas Series | Películas y "Hoy".
class CalendarioView extends StatefulWidget {
  const CalendarioView({super.key});

  @override
  State<CalendarioView> createState() => _CalendarioViewState();
}

class _CalendarioViewState extends State<CalendarioView> {
  @override
  Widget build(BuildContext context) {
    // El controlador vive con esta pantalla (se crea al entrar al Calendario)
    return ChangeNotifierProvider(
      create: (_) => CalendarioController(),
      child: const _CuerpoCalendario(),
    );
  }
}

class _CuerpoCalendario extends StatelessWidget {
  const _CuerpoCalendario();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<CalendarioController>();
    final idioma = app.idioma;

    // Mantiene el calendario al día con los favoritos y el idioma.
    // Se hace tras el build para no notificar durante el mismo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final language = idioma == 'es' ? 'es-ES' : 'en-US';
        context.read<CalendarioController>().syncFavoritos(
              app.favoritos,
              language,
            );
      }
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: CalendarioFavoritos(
        seriesPorDia: control.seriesPorDia,
        peliculasPorDia: control.peliculasPorDia,
        cargando: control.calendarioCargando,
        pestana: control.pestanaCalendario,
        modo: control.modoCalendario,
        fechaVisible: control.fechaVisible,
        aviso: control.avisoCalendario,
        idioma: idioma,
        onFecha: control.irAFecha,
        onHoy: control.irAHoy,
        onModo: control.cambiarModoCalendario,
        onPestana: control.cambiarPestanaCalendario,
        onAbrirEntrada: (entrada) => _abrirEntrada(context, entrada, idioma),
      ),
    );
  }

  /// Abre el detalle de un episodio o estreno del calendario.
  void _abrirEntrada(
      BuildContext context, EntradaCalendario entrada, String idioma) {
    final language = idioma == 'es' ? 'es-ES' : 'en-US';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetalleView(
        tipo: entrada.tipo,
        id: entrada.id,
        fuente: entrada.fuente,
        imdbId: entrada.imdbId,
        tituloInicial: entrada.titulo,
        language: language,
      ),
    ));
  }
}

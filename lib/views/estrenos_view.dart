// VISTA de la pantalla Estrenos (entre Lectura y Calendario en el menú):
// próximos estrenos de series y películas de TMDB según unos filtros.
// Reutiliza el calendario (vistas de mes y día, pestañas Series |
// Películas) y añade el botón Filtros junto a "Hoy", que abre
// FiltrosEstrenosView. Solo dibuja; la carga la hace EstrenosController.
// Vive en el IndexedStack.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/estrenos_controller.dart';
import '../l10n/app_strings.dart';
import 'detalle_view.dart';
import 'filtros_estrenos_view.dart';
import 'widgets/calendario.dart';

/// Pantalla de Estrenos.
class EstrenosView extends StatelessWidget {
  const EstrenosView({super.key});

  @override
  Widget build(BuildContext context) {
    // El controlador vive con esta pantalla
    return ChangeNotifierProvider(
      create: (_) => EstrenosController(),
      child: const _CuerpoEstrenos(),
    );
  }
}

class _CuerpoEstrenos extends StatelessWidget {
  const _CuerpoEstrenos();

  @override
  Widget build(BuildContext context) {
    final idioma = context.watch<AppController>().idioma;
    final control = context.watch<EstrenosController>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: CalendarioFavoritos(
        seriesPorDia: control.seriesPorDia,
        peliculasPorDia: control.peliculasPorDia,
        cargando: control.cargando,
        pestana: control.pestana,
        modo: control.modo,
        fechaVisible: control.fechaVisible,
        aviso: control.aviso,
        idioma: idioma,
        onFecha: control.irAFecha,
        onHoy: control.irAHoy,
        onModo: control.cambiarModo,
        onPestana: control.cambiarPestana,
        onAbrirEntrada: (entrada) =>
            DetalleView.abrirEntrada(context, entrada, idiomaApi(idioma)),
        modos: const ['dia', 'mes'],
        claveTitulo: 'estrenos',
        // Antes de elegir filtros, el calendario vacío invita a usarlos
        claveVacio: control.aplicados ? 'noHayEstrenos' : 'estrenosVacio',
        siempreLista: true,
        accion: FilledButton.tonalIcon(
          onPressed: () => _abrirFiltros(context, control, idioma),
          icon: const Icon(Icons.filter_alt_outlined),
          label: Text(t('filtros', idioma)),
        ),
      ),
    );
  }

  /// Abre los filtros encima y, si se aceptan, carga sus estrenos.
  Future<void> _abrirFiltros(
    BuildContext context,
    EstrenosController control,
    String idioma,
  ) async {
    final elegidos = await FiltrosEstrenosView.abrir(
      context,
      series: control.filtrosSeries,
      peliculas: control.filtrosPeliculas,
      pestana: control.pestana,
    );
    if (elegidos == null) return;
    control.aplicar(elegidos.series, elegidos.peliculas, idiomaApi(idioma));
  }
}

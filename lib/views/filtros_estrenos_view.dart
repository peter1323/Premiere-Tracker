// VISTA de los filtros de Estrenos: se abre encima de la pantalla con dos
// pestañas, Series y Películas, porque cada una tiene sus filtros (como
// la web de TMDB). Se editan copias y solo al pulsar Aceptar se devuelven
// a Estrenos, que es quien carga los resultados.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/filtros_estrenos.dart';

/// Filtros elegidos al aceptar: los de series y los de películas.
typedef FiltrosElegidos = ({FiltrosEstrenos series, FiltrosEstrenos peliculas});

/// Pantalla de filtros de Estrenos.
class FiltrosEstrenosView extends StatefulWidget {
  final FiltrosEstrenos series;
  final FiltrosEstrenos peliculas;
  final String pestana; // pestaña con la que se abre
  const FiltrosEstrenosView({
    super.key,
    required this.series,
    required this.peliculas,
    required this.pestana,
  });

  /// Abre los filtros; devuelve los elegidos o null si se cierra sin
  /// aceptar.
  static Future<FiltrosElegidos?> abrir(
    BuildContext context, {
    required FiltrosEstrenos series,
    required FiltrosEstrenos peliculas,
    required String pestana,
  }) => Navigator.of(context).push<FiltrosElegidos>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FiltrosEstrenosView(
        series: series,
        peliculas: peliculas,
        pestana: pestana,
      ),
    ),
  );

  @override
  State<FiltrosEstrenosView> createState() => _FiltrosEstrenosViewState();
}

class _FiltrosEstrenosViewState extends State<FiltrosEstrenosView> {
  // Copias que se van editando (lo de fuera no cambia hasta Aceptar)
  late FiltrosEstrenos _series = widget.series.desdeHoy;
  late FiltrosEstrenos _peliculas = widget.peliculas.desdeHoy;

  @override
  Widget build(BuildContext context) {
    final idioma = context.watch<AppController>().idioma;
    void aceptar() =>
        Navigator.of(context).pop((series: _series, peliculas: _peliculas));

    return DefaultTabController(
      length: 2,
      initialIndex: widget.pestana == 'series' ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('filtros', idioma)),
          actions: [
            TextButton(onPressed: aceptar, child: Text(t('aceptar', idioma))),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: t('series', idioma)),
              Tab(text: t('peliculas', idioma)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _pestana(
              _series,
              (f) => setState(() => _series = f),
              esSerie: true,
              idioma: idioma,
            ),
            _pestana(
              _peliculas,
              (f) => setState(() => _peliculas = f),
              esSerie: false,
              idioma: idioma,
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: aceptar,
              icon: const Icon(Icons.check),
              label: Text(t('aceptar', idioma)),
            ),
          ),
        ),
      ),
    );
  }

  /// Filtros de una pestaña: disponibilidad, fechas y lo propio de series
  /// (todos los episodios) o de películas (países y tipos de estreno).
  Widget _pestana(
    FiltrosEstrenos f,
    ValueChanged<FiltrosEstrenos> cambiar, {
    required bool esSerie,
    required String idioma,
  }) {
    final tema = Theme.of(context);
    Widget seccion(String clave) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(t(clave, idioma), style: tema.textTheme.titleSmall),
    );
    Widget casilla(String texto, bool valor, ValueChanged<bool> alCambiar) =>
        CheckboxListTile(
          dense: true,
          title: Text(texto),
          value: valor,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => alCambiar(v ?? false),
        );
    // Añade o quita [valor] de un conjunto de casillas
    Set<T> alternar<T>(Set<T> conjunto, T valor, bool marcado) =>
        marcado ? {...conjunto, valor} : ({...conjunto}..remove(valor));

    return ListView(
      children: [
        seccion('disponibilidad'),
        casilla(
          t('todasDisponibilidades', idioma),
          f.todasDisponibilidades,
          (v) => cambiar(f.copyWith(todasDisponibilidades: v)),
        ),
        // Las disponibilidades sueltas solo si no se buscan todas
        if (!f.todasDisponibilidades)
          for (final d in disponibilidades)
            casilla(
              t('disp_$d', idioma),
              f.monetizacion.contains(d),
              (v) => cambiar(
                f.copyWith(monetizacion: alternar(f.monetizacion, d, v)),
              ),
            ),
        const Divider(),
        seccion(esSerie ? 'fechaPublicacion' : 'fechasEstreno'),
        if (esSerie)
          casilla(
            t('todosEpisodios', idioma),
            f.todosEpisodios,
            (v) => cambiar(f.copyWith(todosEpisodios: v)),
          )
        else ...[
          casilla(
            t('todosPaises', idioma),
            f.todosPaises,
            (v) => cambiar(f.copyWith(todosPaises: v)),
          ),
          for (final tipo in tiposEstreno)
            casilla(
              t('estreno_$tipo', idioma),
              f.tipos.contains(tipo),
              (v) => cambiar(f.copyWith(tipos: alternar(f.tipos, tipo, v))),
            ),
        ],
        _fecha('desde', f.desde, idioma, (d) {
          // Si "desde" pasa de "hasta", "hasta" se mueve con él
          cambiar(f.copyWith(desde: d, hasta: d.isAfter(f.hasta) ? d : null));
        }),
        _fecha('hasta', f.hasta, idioma, (d) {
          cambiar(f.copyWith(hasta: d, desde: d.isBefore(f.desde) ? d : null));
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Fila "Desde / Hasta" con la fecha; al tocarla se elige otra.
  Widget _fecha(
    String clave,
    DateTime fecha,
    String idioma,
    ValueChanged<DateTime> alElegir,
  ) {
    final texto =
        '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    return ListTile(
      leading: const Icon(Icons.event),
      title: Text(t(clave, idioma)),
      trailing: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      onTap: () async {
        // Son próximos estrenos: no se puede elegir un día anterior a hoy
        final ahora = DateTime.now();
        final hoy = DateTime(ahora.year, ahora.month, ahora.day);
        final elegida = await showDatePicker(
          context: context,
          initialDate: fecha.isBefore(hoy) ? hoy : fecha,
          firstDate: hoy,
          lastDate: DateTime(DateTime.now().year + 6, 12, 31),
        );
        if (elegida != null) alElegir(elegida);
      },
    );
  }
}

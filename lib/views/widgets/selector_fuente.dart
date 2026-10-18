import 'package:flutter/material.dart';

/// Botón segmentado para elegir la fuente de las series: TMDB | TVMaze.
/// Si una fuente falló en la búsqueda, su opción aparece desactivada.
class SelectorFuente extends StatelessWidget {
  final String valor; // 'tmdb' o 'tvmaze'
  final bool tmdbOk;
  final bool tvmazeOk;
  final ValueChanged<String> onChanged;

  const SelectorFuente({
    super.key,
    required this.valor,
    required this.tmdbOk,
    required this.tvmazeOk,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        const ButtonSegment(value: 'tmdb', label: Text('TMDB')),
        const ButtonSegment(value: 'tvmaze', label: Text('TVMaze')),
      ],
      selected: {valor},
      onSelectionChanged: (nuevo) {
        if (nuevo.isNotEmpty) onChanged(nuevo.first);
      },
      // La fuente que no está disponible queda desactivada
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) {
            return Theme.of(context).colorScheme.surfaceContainerHighest;
          }
          return null;
        }),
      ),
    );
  }
}

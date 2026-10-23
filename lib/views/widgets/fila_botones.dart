// WIDGET compartido de las fichas: botones uno al lado del otro (favoritos
// y vistos, o los enlaces a las webs). Solo coloca; cada botón hace lo suyo.
import 'package:flutter/material.dart';

/// [botones] en fila. Con la pantalla estrecha (móvil en vertical) se
/// reparten el ancho a partes iguales, con la misma altura, y el texto
/// largo pasa a dos líneas; en las anchas cada uno va a su tamaño.
class FilaBotones extends StatelessWidget {
  final List<Widget> botones;
  const FilaBotones({super.key, required this.botones});

  @override
  Widget build(BuildContext context) {
    // Se mira el ancho de la pantalla y no el del hueco: en escritorio los
    // botones quedan como siempre aunque vayan al lado del póster
    if (MediaQuery.sizeOf(context).width >= 600) {
      return Wrap(spacing: 12, runSpacing: 8, children: botones);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < botones.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: botones[i]),
          ],
        ],
      ),
    );
  }
}

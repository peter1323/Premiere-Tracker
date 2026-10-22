// WIDGET compartido: cuadrícula con scroll de tarjetas de resultados
// (Inicio, Favoritos y Vistos). En anchos de móvil en vertical pone dos
// columnas que llenan la pantalla, como en Lectura; en pantallas anchas
// (escritorio u horizontal), tarjetas de 170 px en las columnas que quepan.
import 'package:flutter/material.dart';

/// Cuadrícula de [tarjetas] (cada una toma el ancho que le da la rejilla).
class RejillaTarjetas extends StatelessWidget {
  final List<Widget> tarjetas;
  const RejillaTarjetas({super.key, required this.tarjetas});

  static const double _espacio = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        // Estrecho (< 400 px, móvil en vertical): dos columnas exactas
        final ancho = medidas.maxWidth < 400
            ? (medidas.maxWidth - _espacio) / 2
            : 170.0;
        return SingleChildScrollView(
          child: Wrap(
            spacing: _espacio,
            runSpacing: _espacio,
            children: [
              for (final tarjeta in tarjetas)
                SizedBox(width: ancho, child: tarjeta),
            ],
          ),
        );
      },
    );
  }
}

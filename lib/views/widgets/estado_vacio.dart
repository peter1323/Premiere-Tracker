// WIDGET compartido: el aviso centrado que se ve cuando una lista está
// vacía o una búsqueda no da resultados (Inicio, Favoritos, Vistos y
// Notas). Solo dibuja; no tiene lógica.
import 'package:flutter/material.dart';

/// Estado vacío centrado: icono grande y un texto (sin resultados, lista
/// vacía...).
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  const EstadoVacio({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            texto,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// WIDGET compartido: la tarjeta de un estreno (episodio o película) en una
// lista. La usan el calendario de Android (vistas Día y Semana) e Inicio
// (Próximamente). Solo dibuja; al pulsarla avisa con [onTap].
import 'package:flutter/material.dart';

import '../../controllers/calendario_controller.dart';

/// Color de texto legible sobre [fondo]: blanco si el fondo es oscuro,
/// casi negro si es claro.
Color colorTextoSobre(Color fondo) =>
    ThemeData.estimateBrightnessForColor(fondo) == Brightness.dark
    ? Colors.white
    : Colors.black87;

/// Tarjeta de color con [prefijo] en negrita a la izquierda (la hora, o el
/// día y la hora) y "T1E3 · Título" a continuación (con el título original
/// debajo si lo hay).
class FilaEstreno extends StatelessWidget {
  final EntradaCalendario entrada;
  final Color color;
  final String prefijo; // '' para no mostrar nada a la izquierda
  final VoidCallback onTap;

  const FilaEstreno({
    super.key,
    required this.entrada,
    required this.color,
    required this.prefijo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = colorTextoSobre(color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (prefijo.isNotEmpty) ...[
                  Text(
                    prefijo,
                    style: TextStyle(
                      color: colorTexto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entrada.texto,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorTexto),
                      ),
                      // Título original debajo, más pequeño (Estrenos)
                      if (entrada.tituloOriginal.isNotEmpty)
                        Text(
                          entrada.tituloOriginal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorTexto.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

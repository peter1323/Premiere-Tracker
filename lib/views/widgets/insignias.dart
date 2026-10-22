// WIDGETS compartidos: insignias pequeñas de las tarjetas guardadas y de
// las fichas. Estado (de la base de datos), nota personal y cuenta atrás del
// estreno ("Estrena en 3 días" / "¡Hoy estrena!"). Solo dibujan.
import 'package:flutter/material.dart';

import '../../controllers/calendario_controller.dart';
import '../../l10n/app_strings.dart';

/// Texto traducido del estado de una obra guardada ('enEmision'...).
String textoEstado(String estado, String idioma) => t(switch (estado) {
  'enEmision' => 'enEmisionEstado',
  'finalizado' => 'finalizadoEstado',
  _ => estado,
}, idioma);

/// "hoy", "mañana" o "en N días" hasta [fecha]; null si no hay fecha o ya
/// pasó. Va junto a la fecha de estreno en la ficha.
String? enCuantoEstrena(String fecha, String idioma) {
  final dias = diasParaEstreno(fecha);
  if (dias == null) return null;
  if (dias == 0) return t('hoyMinuscula', idioma);
  if (dias == 1) return t('manana', idioma);
  return tv('enDias', idioma, {'n': dias});
}

/// Insignia pequeña con icono y texto; [destacada] usa el color primario.
class Insignia extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool destacada;
  const Insignia({
    super.key,
    required this.icono,
    required this.texto,
    this.destacada = false,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fondo = destacada ? esquema.primary : esquema.secondaryContainer;
    final color = destacada ? esquema.onPrimary : esquema.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Insignias de una tarjeta guardada: estado, nota y cuenta atrás. Solo
/// las que tengan dato (sin estado, sin nota o sin fecha futura = nada).
List<Widget> insigniasDe({
  required String? estado,
  required int? puntuacion,
  required String fechaEstreno,
  required String idioma,
}) {
  final dias = diasParaEstreno(fechaEstreno);
  return [
    if (estado != null)
      Insignia(
        icono: Icons.bookmark_outline,
        texto: textoEstado(estado, idioma),
      ),
    if (puntuacion != null)
      Insignia(icono: Icons.star_rounded, texto: '$puntuacion/10'),
    if (dias != null)
      Insignia(
        icono: Icons.timer_outlined,
        destacada: dias == 0,
        texto: dias == 0
            ? t('hoyEstrena', idioma)
            : dias == 1
            ? t('estrenaManana', idioma)
            : tv('estrenaEnDias', idioma, {'n': dias}),
      ),
  ];
}

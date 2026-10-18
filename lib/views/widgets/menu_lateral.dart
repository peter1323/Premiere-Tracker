import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// Menú lateral fijo con las seis secciones: Inicio, Calendario,
/// Favoritos, Vistos, Notas y Ajustes.
class MenuLateral extends StatelessWidget {
  final int indice;
  final ValueChanged<int> onSeleccionar;
  final String idioma;

  const MenuLateral({
    super.key,
    required this.indice,
    required this.onSeleccionar,
    required this.idioma,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: indice,
      onDestinationSelected: onSeleccionar,
      // Las etiquetas siempre visibles, cómodo en escritorio
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          Icons.live_tv_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: Text(t('inicio', idioma)),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
          label: Text(t('calendario', idioma)),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.favorite_outline),
          selectedIcon: const Icon(Icons.favorite),
          label: Text(t('favoritos', idioma)),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.visibility_outlined),
          selectedIcon: const Icon(Icons.visibility),
          label: Text(t('vistos', idioma)),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.edit_note_outlined),
          selectedIcon: const Icon(Icons.edit_note),
          label: Text(t('notas', idioma)),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(t('ajustes', idioma)),
        ),
      ],
    );
  }
}

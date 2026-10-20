// WIDGETS de navegación. Comparten la lista de los 7 destinos (Inicio,
// Lectura, Calendario, Favoritos, Vistos, Notas y Ajustes) para no
// repetir iconos y textos: MenuLateral (raíl lateral, pantalla ancha /
// escritorio) y MenuInferior (barra inferior, móvil). Ambos avisan a
// main.dart con onSeleccionar() al pulsar un destino, para que cambie el
// índice del IndexedStack. No contienen lógica de datos.
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// Datos de un destino del menú: icono normal, icono seleccionado y la
/// clave de traducción de su etiqueta. Se comparten entre el raíl lateral
/// y la barra inferior para que ambos menús quedén idénticos.
class _Destino {
  final IconData icono;
  final IconData iconoSel;
  final String clave;
  const _Destino(this.icono, this.iconoSel, this.clave);
}

/// Los 7 destinos, en el mismo orden que el IndexedStack de main.dart.
const List<_Destino> _destinos = [
  _Destino(Icons.home_outlined, Icons.home, 'inicio'),
  _Destino(Icons.menu_book_outlined, Icons.menu_book, 'mangas'),
  _Destino(Icons.calendar_month_outlined, Icons.calendar_month, 'calendario'),
  _Destino(Icons.favorite_outline, Icons.favorite, 'favoritos'),
  _Destino(Icons.visibility_outlined, Icons.visibility, 'vistos'),
  _Destino(Icons.edit_note_outlined, Icons.edit_note, 'notas'),
  _Destino(Icons.settings_outlined, Icons.settings, 'ajustes'),
];

/// Menú lateral fijo con las siete secciones (pantalla ancha: Windows,
/// Linux, macOS o tablet en horizontal).
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
        for (final d in _destinos)
          NavigationRailDestination(
            icon: Icon(d.icono),
            selectedIcon: Icon(d.iconoSel),
            label: Text(t(d.clave, idioma)),
          ),
      ],
    );
  }
}

/// Barra inferior de navegación para móvil (Android/iOS): los mismos 7
/// destinos que el raíl, pero en iconos sueltos para que quepan en
/// pantalla pequeña.
class MenuInferior extends StatelessWidget {
  final int indice;
  final ValueChanged<int> onSeleccionar;
  final String idioma;

  const MenuInferior({
    super.key,
    required this.indice,
    required this.onSeleccionar,
    required this.idioma,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: indice,
      onDestinationSelected: onSeleccionar,
      // Con 7 destinos solo se muestran iconos (la etiqueta sigue
      // disponible para los lectores de pantalla).
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      destinations: [
        for (final d in _destinos)
          NavigationDestination(
            icon: Icon(d.icono),
            selectedIcon: Icon(d.iconoSel),
            label: t(d.clave, idioma),
          ),
      ],
    );
  }
}

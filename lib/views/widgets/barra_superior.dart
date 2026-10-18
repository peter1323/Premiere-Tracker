import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../l10n/app_strings.dart';

/// Barra superior: nombre de la app, botón de tema y menú del usuario.
class BarraSuperior extends StatelessWidget implements PreferredSizeWidget {
  const BarraSuperior({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final idioma = app.idioma;

    return AppBar(
      title: Text(t('appName', idioma)),
      actions: [
        // Botón para cambiar entre modo claro y oscuro
        IconButton(
          tooltip: t('cambiarTema', idioma),
          icon: Icon(app.esOscuro
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined),
          onPressed: () => context.read<AppController>().cambiarTema(),
        ),
        const SizedBox(width: 4),
        // Círculo con la inicial del usuario actual
        PopupMenuButton<String>(
          tooltip: app.nombreUsuario,
          onSelected: (valor) {
            if (valor == 'usuario') {
              // Vuelve a la pantalla de usuarios
              context.read<AppController>().cerrarSesion();
            } else if (valor == 'salir') {
              context.read<AppController>().cerrarAplicacion();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'usuario',
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 8),
                  Text(t('cambiarUsuario', idioma)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'salir',
              child: Row(
                children: [
                  const Icon(Icons.close),
                  const SizedBox(width: 8),
                  Text(t('cerrarApp', idioma)),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CircleAvatar(child: Text(app.inicial)),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

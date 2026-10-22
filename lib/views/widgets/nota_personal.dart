// WIDGET compartido de las fichas (series, películas y mangas): "Tu nota"
// 1-10, aparte de la de TMDB/TVMaze. Solo aparece si la obra está en
// Favoritos o Vistos. Además apunta en lo guardado el estado que da la
// base de datos (En emisión, Finalizado...), que se ve en las listas.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/favorito_model.dart';

/// Nota personal de una obra guardada (nada si no está guardada).
class NotaPersonal extends StatelessWidget {
  final String fuente;
  final String tipo; // 'serie', 'pelicula', 'manga' o 'novela'
  final int id;
  final String titulo;
  final String estadoApi; // estado de la ficha (SerieModel.estado...)

  const NotaPersonal({
    super.key,
    required this.fuente,
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.estadoApi,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final idioma = app.idioma;
    final guardado = app.guardado(fuente, tipo, id, titulo);
    if (guardado == null) return const SizedBox.shrink();

    // Estado al día con la base de datos (tras el build: no se puede
    // notificar durante él; si no cambió, no se guarda nada)
    final estado = FavoritoModel.estadoDeApi(estadoApi);
    if (estado != null && estado != guardado.estado) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => app.actualizarEstado(guardado, estado),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber),
          const SizedBox(width: 6),
          Text('${t('tuNota', idioma)}: '),
          DropdownButton<int?>(
            value: guardado.puntuacion,
            items: [
              DropdownMenuItem(child: Text(t('sinPuntuar', idioma))),
              for (var n = 10; n >= 1; n--)
                DropdownMenuItem(value: n, child: Text('$n/10')),
            ],
            onChanged: (nota) => app.cambiarNota(guardado, nota),
          ),
        ],
      ),
    );
  }
}

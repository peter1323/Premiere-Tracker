// VISTA de la pantalla Favoritos (sección 3 del menú). Muestra la lista
// de favoritos del usuario con un buscador por nombre y un filtro de 5
// pestañas (Todo / Series / Películas / Manga-Manhwa-Manhua / Novelas).
// Al tocar una tarjeta abre su ficha. Solo dibuja y llama a
// FavoritosController; la lista le llega de AppController. Vive en el
// IndexedStack.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/favoritos_controller.dart';
import '../l10n/app_strings.dart';
import '../models/favorito_model.dart';
import 'detalle_view.dart';
import 'widgets/tarjeta_resultado.dart';

/// Pantalla de Favoritos: series y películas guardadas por el usuario
/// actual, con buscador por nombre y filtro Todo / Series / Películas.
class FavoritosView extends StatefulWidget {
  const FavoritosView({super.key});

  @override
  State<FavoritosView> createState() => _FavoritosViewState();
}

class _FavoritosViewState extends State<FavoritosView> {
  final TextEditingController _buscador = TextEditingController();

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El controlador vive con esta pantalla
    return ChangeNotifierProvider(
      create: (_) => FavoritosController(),
      child: _CuerpoFavoritos(buscador: _buscador),
    );
  }
}

class _CuerpoFavoritos extends StatefulWidget {
  final TextEditingController buscador;
  const _CuerpoFavoritos({required this.buscador});

  @override
  State<_CuerpoFavoritos> createState() => _CuerpoFavoritosState();
}

class _CuerpoFavoritosState extends State<_CuerpoFavoritos> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<FavoritosController>();
    final idioma = app.idioma;

    // Mantiene la lista al día con los favoritos del usuario actual.
    // Se hace tras el build para no notificar durante el mismo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FavoritosController>().syncFavoritos(app.favoritos);
      }
    });

    final favoritos = control.favoritosFiltrados;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, medidas) {
          // En alturas bajas (móvil horizontal) la página entera se
          // desplaza y la lista ocupa una altura fija para no quedar
          // comprimida a píxeles; en alturas normales, igual que siempre.
          final fijo = <Widget>[
            Text(
              t('favoritos', idioma),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Buscador por nombre
            TextField(
              controller: widget.buscador,
              onChanged: control.cambiarConsulta,
              decoration: InputDecoration(
                hintText: t('buscarFavoritosHint', idioma),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: t('cerrar', idioma),
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.buscador.clear();
                    control.cambiarConsulta('');
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Filtro: Todo | Series | Películas | Manga / Manhwa / Manhua |
            // Novelas. El scroll horizontal evita que se corte en pantallas
            // estrechas; en escritorio, donde cabe, no se ve ningún desliz.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'todo', label: Text(t('todo', idioma))),
                  ButtonSegment(
                    value: 'serie',
                    label: Text(t('series', idioma)),
                  ),
                  ButtonSegment(
                    value: 'pelicula',
                    label: Text(t('peliculas', idioma)),
                  ),
                  ButtonSegment(
                    value: 'manga',
                    label: Text(t('pestanaManga', idioma)),
                  ),
                  ButtonSegment(
                    value: 'novela',
                    label: Text(t('pestanaNovelas', idioma)),
                  ),
                ],
                selected: {control.filtro},
                onSelectionChanged: (nuevo) {
                  if (nuevo.isNotEmpty) control.cambiarFiltro(nuevo.first);
                },
              ),
            ),
            const SizedBox(height: 16),
          ];

          // Lista o estado vacío
          final lista = !control.hayFavoritos
              ? _EstadoVacio(
                  icono: Icons.favorite_border,
                  texto: t('sinFavoritos', idioma),
                )
              : favoritos.isEmpty
              ? _EstadoVacio(
                  icono: Icons.search_off,
                  texto: t('sinCoincidencias', idioma),
                )
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: favoritos
                        .map((f) => _tarjeta(f, app, idioma))
                        .toList(),
                  ),
                );

          if (medidas.maxHeight < 360) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...fijo,
                  SizedBox(height: 360, child: lista),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...fijo,
              Expanded(child: lista),
            ],
          );
        },
      ),
    );
  }

  /// Tarjeta del favorito: al pulsar abre el detalle; el corazón lo quita
  /// y el ojo lo marca como visto (o lo quita de vistos si ya lo era).
  Widget _tarjeta(FavoritoModel favorito, AppController app, String idioma) {
    final language = idioma == 'es' ? 'es-ES' : 'en-US';
    return TarjetaResultado(
      titulo: favorito.titulo,
      anio: favorito.anio,
      posterUrl: favorito.posterUrl,
      esFavorito: true, // en esta pantalla todo está en favoritos
      onFavorito: () => app.quitarFavorito(favorito.idUnico),
      esVisto: app.esVisto(
        favorito.fuente,
        favorito.tipo,
        favorito.id,
        titulo: favorito.titulo,
      ),
      onVisto: () => app.alternarVisto(favorito),
      onAbrir: () => DetalleView.abrirFavorito(context, favorito, language),
    );
  }
}

/// Estado vacío centrado de la pantalla de favoritos.
class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _EstadoVacio({required this.icono, required this.texto});

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

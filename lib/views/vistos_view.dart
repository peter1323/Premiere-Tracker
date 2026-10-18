import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/vistos_controller.dart';
import '../l10n/app_strings.dart';
import '../models/favorito_model.dart';
import 'detalle_view.dart';
import 'widgets/tarjeta_resultado.dart';

/// Pantalla de Vistos: series y películas que el usuario actual ha
/// marcado como vistas, con buscador por nombre y filtro Todo /
/// Series / Películas (mismo estilo que Favoritos).
class VistosView extends StatefulWidget {
  const VistosView({super.key});

  @override
  State<VistosView> createState() => _VistosViewState();
}

class _VistosViewState extends State<VistosView> {
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
      create: (_) => VistosController(),
      child: _CuerpoVistos(buscador: _buscador),
    );
  }
}

class _CuerpoVistos extends StatefulWidget {
  final TextEditingController buscador;
  const _CuerpoVistos({required this.buscador});

  @override
  State<_CuerpoVistos> createState() => _CuerpoVistosState();
}

class _CuerpoVistosState extends State<_CuerpoVistos> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<VistosController>();
    final idioma = app.idioma;

    // Mantiene la lista al día con los vistos del usuario actual.
    // Se hace tras el build para no notificar durante el mismo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VistosController>().syncVistos(app.vistos);
      }
    });

    final vistos = control.vistosFiltrados;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('vistos', idioma),
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
          // Novelas
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'todo', label: Text(t('todo', idioma))),
              ButtonSegment(
                  value: 'serie', label: Text(t('series', idioma))),
              ButtonSegment(
                  value: 'pelicula', label: Text(t('peliculas', idioma))),
              ButtonSegment(
                  value: 'manga', label: Text(t('pestanaManga', idioma))),
              ButtonSegment(
                  value: 'novela', label: Text(t('pestanaNovelas', idioma))),
            ],
            selected: {control.filtro},
            onSelectionChanged: (nuevo) {
              if (nuevo.isNotEmpty) control.cambiarFiltro(nuevo.first);
            },
          ),
          const SizedBox(height: 16),
          // Lista o estado vacío
          Expanded(
            child: !control.hayVistos
                ? _EstadoVacio(
                    icono: Icons.visibility_outlined,
                    texto: t('sinVistos', idioma),
                  )
                : vistos.isEmpty
                    ? _EstadoVacio(
                        icono: Icons.search_off,
                        texto: t('sinCoincidencias', idioma),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: vistos
                              .map((v) => _tarjeta(v, app, idioma))
                              .toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta del visto: al pulsar abre el detalle; el ojo lo quita de
  /// vistos y el corazón alterna su estado de favorito.
  Widget _tarjeta(FavoritoModel visto, AppController app, String idioma) {
    final language = idioma == 'es' ? 'es-ES' : 'en-US';
    return TarjetaResultado(
      titulo: visto.titulo,
      anio: visto.anio,
      posterUrl: visto.posterUrl,
      esFavorito:
          app.esFavorito(visto.fuente, visto.tipo, visto.id, titulo: visto.titulo),
      onFavorito: () => app.alternarFavorito(visto),
      esVisto: true, // en esta pantalla todo está marcado como visto
      onVisto: () => app.quitarVisto(visto.idUnico),
      onAbrir: () => DetalleView.abrirFavorito(context, visto, language),
    );
  }
}

/// Estado vacío centrado de la pantalla de vistos.
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

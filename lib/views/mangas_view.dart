// VISTA de la pantalla Lectura (sección 1 del menú). Es el buscador de
// mangas, manhwas, manhuas y novelas: dos pestañas (cómics y novelas) que
// buscan contra AniList y muestran resultados en tarjetas. Al tocar uno
// abre su ficha (MangaDetalleView). Solo dibuja y llama a
// MangasController. Vive en el IndexedStack.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/mangas_controller.dart';
import '../l10n/app_strings.dart';
import 'manga_detalle_view.dart';
import 'widgets/tarjeta_manga.dart';

/// Pantalla de Mangas: buscador sobre AniList con tarjetas de los mangas
/// encontrados. Es la misma idea que la búsqueda de Inicio pero solo para
/// mangas, y sin favoritos, vistos, notas ni calendario.
class MangasView extends StatefulWidget {
  const MangasView({super.key});

  @override
  State<MangasView> createState() => _MangasViewState();
}

class _MangasViewState extends State<MangasView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textoBuscador = TextEditingController();
  // Dos pestañas: Manga (con manhwas y manhuas) y Novelas.
  late final TabController _pestanas = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _textoBuscador.dispose();
    _pestanas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final strings = app.idioma;
    return ChangeNotifierProvider(
      create: (_) => MangasController(),
      child: Consumer<MangasController>(
        builder: (context, controlador, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, medidas) {
              // En alturas bajas (móvil horizontal) la página entera se
              // desplaza y los resultados ocupan una altura fija, para que
              // no queden comprimidos; en el resto, igual que siempre.
              final fijo = <Widget>[
                Text(
                  t('mangas', strings),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  t('mangasAyuda', strings),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                // Buscador (escribir con Enter o pulsar el botón)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textoBuscador,
                        decoration: InputDecoration(
                          labelText: t('buscarMangas', strings),
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (texto) => controlador.buscar(texto),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => controlador.buscar(_textoBuscador.text),
                      child: Text(t('buscar', strings)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _pestanas,
                  tabs: [
                    Tab(text: t('pestanaManga', strings)),
                    Tab(text: t('pestanaNovelas', strings)),
                  ],
                ),
                const SizedBox(height: 8),
              ];

              final vistas = TabBarView(
                controller: _pestanas,
                children: [
                  _Resultados(controlador: controlador, tipo: 'MANGA'),
                  _Resultados(controlador: controlador, tipo: 'NOVEL'),
                ],
              );

              if (medidas.maxHeight < 360) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...fijo,
                      SizedBox(height: 360, child: vistas),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...fijo,
                  Expanded(child: vistas),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Zona de resultados de una pestaña: cargando, vacío, error o rejilla.
class _Resultados extends StatelessWidget {
  final MangasController controlador;
  final String tipo; // 'MANGA' (manga/manhwa/manhua) o 'NOVEL'
  const _Resultados({required this.controlador, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final strings = app.idioma;
    // Resultados de la pestaña actual.
    final lista = tipo == 'MANGA'
        ? controlador.resultadosManga
        : controlador.resultadosNovela;

    if (controlador.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lista.isEmpty) {
      // O falló esta categoría, o no hubo coincidencias, o aún no se ha
      // buscado nada (en ese orden).
      if (controlador.huboError) {
        return Center(
          child: Text(
            t('errorBuscarMangas', strings),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }
      return Center(
        child: Text(
          controlador.busquedaHecha
              ? t('sinResultados', strings)
              : t('buscarMangasVacio', strings),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 290,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final manga = lista[i];
        return TarjetaManga(
          manga: manga,
          idioma: strings,
          onAbrir: () => MangaDetalleView.abrir(
            context,
            manga: manga,
            language: idiomaApi(strings),
          ),
        );
      },
    );
  }
}

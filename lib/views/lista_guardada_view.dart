// VISTA de las pantallas Favoritos (sección 3) y Vistos (sección 4): son
// la misma pantalla con distinta lista. Muestra la lista del usuario con
// un buscador por nombre, un filtro por tipo (Todo / Series / Películas /
// Manga / Novelas y, en Favoritos, Personas), un filtro por estado y el
// orden (añadido o por tu nota). Cada tarjeta lleva sus insignias. Al
// tocar una tarjeta abre su ficha. Solo dibuja y llama a
// ListaGuardadaController; la lista le llega de AppController. Vive en el
// IndexedStack.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/lista_guardada_controller.dart';
import '../l10n/app_strings.dart';
import '../models/favorito_model.dart';
import 'detalle_view.dart';
import 'widgets/estado_vacio.dart';
import 'widgets/insignias.dart';
import 'widgets/tarjeta_resultado.dart';

/// Pantalla de Favoritos.
class FavoritosView extends StatelessWidget {
  const FavoritosView({super.key});

  @override
  Widget build(BuildContext context) =>
      const ListaGuardadaView(esVistos: false);
}

/// Pantalla de Vistos (o Leídos, para los mangas).
class VistosView extends StatelessWidget {
  const VistosView({super.key});

  @override
  Widget build(BuildContext context) => const ListaGuardadaView(esVistos: true);
}

/// Lista guardada del usuario: favoritos o vistos según [esVistos].
class ListaGuardadaView extends StatefulWidget {
  final bool esVistos;
  const ListaGuardadaView({super.key, required this.esVistos});

  @override
  State<ListaGuardadaView> createState() => _ListaGuardadaViewState();
}

class _ListaGuardadaViewState extends State<ListaGuardadaView> {
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
      create: (_) => ListaGuardadaController(),
      child: _Cuerpo(buscador: _buscador, esVistos: widget.esVistos),
    );
  }
}

/// Filtros por tipo: valor del filtro y clave de su texto.
const _tipos = [
  ('todo', 'todo'),
  ('serie', 'series'),
  ('pelicula', 'peliculas'),
  ('manga', 'pestanaManga'),
  ('novela', 'pestanaNovelas'),
  ('persona', 'personas'),
];

/// Clave del texto de cada orden de la lista.
const _textosOrden = {
  'anadido': 'ordenAnadido',
  'nota': 'ordenPuntuacion',
  'az': 'ordenAZ',
  'za': 'ordenZA',
};

class _Cuerpo extends StatelessWidget {
  final TextEditingController buscador;
  final bool esVistos;
  const _Cuerpo({required this.buscador, required this.esVistos});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<ListaGuardadaController>();
    final idioma = app.idioma;

    // Mantiene la lista al día con la del usuario actual y completa los
    // estados que falten.
    // Se hace tras el build para no notificar durante el mismo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.read<ListaGuardadaController>().sincronizar(
          esVistos ? app.vistos : app.favoritos,
        );
        // Lo guardado sin estado lo completa desde la base de datos
        app.completarEstados();
      }
    });

    final elementos = control.filtrados;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, medidas) {
          // En alturas bajas (móvil horizontal) la página entera se
          // desplaza y la lista ocupa una altura fija para no quedar
          // comprimida a píxeles; en alturas normales, igual que siempre.
          final fijo = <Widget>[
            Text(
              t(esVistos ? 'vistos' : 'favoritos', idioma),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Buscador por nombre
            TextField(
              controller: buscador,
              onChanged: control.cambiarConsulta,
              decoration: InputDecoration(
                hintText: t('buscarFavoritosHint', idioma),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: t('cerrar', idioma),
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    buscador.clear();
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
                // Cada tipo con cuántos hay entre paréntesis: "Series (10)";
                // sin número si no hay ninguno. Personas solo en Favoritos
                // (no se marcan como vistas).
                segments: [
                  for (final (valor, clave) in _tipos)
                    if (valor != 'persona' || !esVistos)
                      ButtonSegment(
                        value: valor,
                        label: Text(
                          control.cuantos(valor) > 0
                              ? '${t(clave, idioma)} (${control.cuantos(valor)})'
                              : t(clave, idioma),
                        ),
                      ),
                ],
                selected: {control.filtro},
                onSelectionChanged: (nuevo) {
                  if (nuevo.isNotEmpty) control.cambiarFiltro(nuevo.first);
                },
              ),
            ),
            const SizedBox(height: 8),
            // Filtro de estado (no en Personas) y orden
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (!control.esPersonas)
                  DropdownButton<String>(
                    value: control.filtroEstado,
                    items: [
                      for (final e in [
                        'todos',
                        ...FavoritoModel.estados,
                        'sin',
                      ])
                        DropdownMenuItem(
                          value: e,
                          child: Text(
                            e == 'todos'
                                ? t('todosEstados', idioma)
                                : e == 'sin'
                                ? t('sinEstado', idioma)
                                : textoEstado(e, idioma),
                          ),
                        ),
                    ],
                    onChanged: (e) {
                      if (e != null) control.cambiarFiltroEstado(e);
                    },
                  ),
                DropdownButton<String>(
                  value: control.orden,
                  items: [
                    for (final o in control.ordenes)
                      DropdownMenuItem(
                        value: o,
                        child: Text(t(_textosOrden[o]!, idioma)),
                      ),
                  ],
                  onChanged: (o) {
                    if (o != null) control.cambiarOrden(o);
                  },
                ),
              ],
            ),
          ];

          // Lista o estado vacío
          final lista = !control.hayElementos
              ? EstadoVacio(
                  icono: esVistos
                      ? Icons.visibility_outlined
                      : Icons.favorite_border,
                  texto: t(esVistos ? 'sinVistos' : 'sinFavoritos', idioma),
                )
              : elementos.isEmpty
              // Sin personas guardadas: aviso propio; si no, sin coincidencias
              ? control.filtro == 'persona'
                    ? EstadoVacio(
                        icono: Icons.person_outline,
                        texto: t('sinPersonasFavoritas', idioma),
                      )
                    : EstadoVacio(
                        icono: Icons.search_off,
                        texto: t('sinCoincidencias', idioma),
                      )
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: elementos
                        .map((f) => _tarjeta(context, f, app, idioma))
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

  /// Tarjeta: al pulsar abre el detalle. En Favoritos el corazón lo quita
  /// y el ojo alterna visto; en Vistos el ojo lo quita y el corazón
  /// alterna favorito. Las personas no tienen ojo ni insignias.
  Widget _tarjeta(
    BuildContext context,
    FavoritoModel item,
    AppController app,
    String idioma,
  ) {
    final esPersona = item.tipo == 'persona';
    return TarjetaResultado(
      titulo: item.titulo,
      anio: item.anio,
      posterUrl: item.posterUrl,
      iconoMarcador: esPersona ? Icons.person_outline : Icons.movie_outlined,
      insignias: esPersona
          ? const []
          : insigniasDe(
              estado: item.estado,
              puntuacion: item.puntuacion,
              fechaEstreno: item.fechaEstreno,
              idioma: idioma,
            ),
      esFavorito:
          !esVistos ||
          app.esFavorito(item.fuente, item.tipo, item.id, titulo: item.titulo),
      onFavorito: esVistos
          ? () => app.alternarFavorito(item)
          : () => app.quitarFavorito(item.idUnico),
      esVisto:
          esVistos ||
          app.esVisto(item.fuente, item.tipo, item.id, titulo: item.titulo),
      onVisto: esPersona
          ? null
          : esVistos
          ? () => app.quitarVisto(item.idUnico)
          : () => app.alternarVisto(item),
      onAbrir: () =>
          DetalleView.abrirFavorito(context, item, idiomaApi(idioma)),
    );
  }
}

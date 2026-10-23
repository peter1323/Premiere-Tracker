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
import 'widgets/rejilla_tarjetas.dart';
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
  // Páginas de tipos (Todo, Series...): se pasa de una a otra deslizando
  final PageController _paginas = PageController();
  // Una clave por botón de tipo, para hacer visible el elegido
  final Map<String, GlobalKey> _botones = {
    for (final (valor, _) in _tipos) valor: GlobalKey(),
  };

  @override
  void dispose() {
    _buscador.dispose();
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El controlador vive con esta pantalla
    return ChangeNotifierProvider(
      create: (_) => ListaGuardadaController(),
      child: _Cuerpo(
        buscador: _buscador,
        esVistos: widget.esVistos,
        paginas: _paginas,
        botones: _botones,
      ),
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
  final PageController paginas;
  final Map<String, GlobalKey> botones;
  const _Cuerpo({
    required this.buscador,
    required this.esVistos,
    required this.paginas,
    required this.botones,
  });

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
        // Completa estados y fechas de estreno desde la base de datos
        app.completarDatos();
      }
    });

    // Tipos de esta lista (Personas solo en Favoritos: no se marcan como
    // vistas); cada uno es una página
    final tipos = [
      for (final tipo in _tipos)
        if (tipo.$1 != 'persona' || !esVistos) tipo,
    ];

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
                  for (final (valor, clave) in tipos)
                    ButtonSegment(
                      value: valor,
                      label: Text(
                        key: botones[valor],
                        control.cuantos(valor) > 0
                            ? '${t(clave, idioma)} (${control.cuantos(valor)})'
                            : t(clave, idioma),
                      ),
                    ),
                ],
                selected: {control.filtro},
                // Al tocar un tipo se salta a su página (y esta cambia el filtro)
                onSelectionChanged: (nuevo) {
                  if (nuevo.isEmpty) return;
                  // Sin páginas (lista vacía) solo cambia el filtro
                  if (!paginas.hasClients) {
                    control.cambiarFiltro(nuevo.first);
                    return;
                  }
                  paginas.jumpToPage(
                    tipos.indexWhere((tipo) => tipo.$1 == nuevo.first),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Filtro de estado (no en Personas) y orden, uno al lado del
            // otro: en el móvil se reparten el ancho (el texto largo se
            // corta con "…"); en escritorio no pasan de 560 px entre los dos.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                children: [
                  if (!control.esPersonas) ...[
                    // Icono delante: así basta un texto corto ("Todos")
                    const Icon(Icons.filter_alt_outlined, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (e) {
                          if (e != null) control.cambiarFiltroEstado(e);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: control.orden,
                      items: [
                        for (final o in control.ordenes)
                          DropdownMenuItem(
                            value: o,
                            child: Text(
                              t(_textosOrden[o]!, idioma),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (o) {
                        if (o != null) control.cambiarOrden(o);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ];

          // Sin nada guardado: aviso; si no, una página por tipo que se
          // pasa deslizando (en el móvil) y mueve el filtro de arriba
          final lista = !control.hayElementos
              ? EstadoVacio(
                  icono: esVistos
                      ? Icons.visibility_outlined
                      : Icons.favorite_border,
                  texto: t(esVistos ? 'sinVistos' : 'sinFavoritos', idioma),
                )
              : PageView(
                  controller: paginas,
                  onPageChanged: (i) {
                    final antes = tipos.indexWhere(
                      (tipo) => tipo.$1 == control.filtro,
                    );
                    control.cambiarFiltro(tipos[i].$1);
                    // Que el botón del tipo nuevo se vea si la barra no
                    // cabe, moviéndola lo justo hacia el lado al que se va
                    final boton = botones[tipos[i].$1]?.currentContext;
                    if (boton != null) {
                      Scrollable.ensureVisible(
                        boton,
                        alignmentPolicy: i > antes
                            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
                        duration: const Duration(milliseconds: 250),
                      );
                    }
                  },
                  children: [
                    for (final (valor, _) in tipos)
                      _pagina(context, valor, app, control, idioma),
                  ],
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

  /// Página de un tipo: sus tarjetas o, si no hay, el aviso que toque.
  Widget _pagina(
    BuildContext context,
    String tipo,
    AppController app,
    ListaGuardadaController control,
    String idioma,
  ) {
    final elementos = control.filtradosDe(tipo);
    if (elementos.isNotEmpty) {
      return RejillaTarjetas(
        tarjetas: [
          for (final f in elementos) _tarjeta(context, f, app, idioma),
        ],
      );
    }
    // Sin personas guardadas: aviso propio; si no, sin coincidencias
    return tipo == 'persona'
        ? EstadoVacio(
            icono: Icons.person_outline,
            texto: t('sinPersonasFavoritas', idioma),
          )
        : EstadoVacio(
            icono: Icons.search_off,
            texto: t('sinCoincidencias', idioma),
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

// WIDGET compartido de las fichas: fila horizontal de tarjetas con imagen,
// título y subtítulo (el reparto y las recomendaciones). Se mueve
// arrastrando, con la barra siempre visible y con la rueda del ratón en
// escritorio. Solo dibuja; al tocar una tarjeta llama a su onTap.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Una tarjeta de la fila: [imagen] (URL o null), [titulo], [subtitulo]
/// opcional y [onTap] (null = no se puede abrir).
typedef ElementoFila = ({
  String? imagen,
  String titulo,
  String subtitulo,
  VoidCallback? onTap,
});

/// Fila horizontal de [elementos]; [iconoSinImagen] si falta la imagen.
class FilaHorizontal extends StatefulWidget {
  final List<ElementoFila> elementos;
  final IconData iconoSinImagen;
  const FilaHorizontal({
    super.key,
    required this.elementos,
    required this.iconoSinImagen,
  });

  @override
  State<FilaHorizontal> createState() => _FilaHorizontalState();
}

class _FilaHorizontalState extends State<FilaHorizontal> {
  final ScrollController _control = ScrollController();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // La rueda del ratón (vertical) se convierte en desplazamiento
      // horizontal. Al registrarse en el resolver antes que la página,
      // esta no se desplaza al mismo tiempo.
      onPointerSignal: (evento) {
        if (evento is PointerScrollEvent && _control.hasClients) {
          GestureBinding.instance.pointerSignalResolver.register(
            evento,
            (e) => _control.position.pointerScroll(
              (e as PointerScrollEvent).scrollDelta.dy,
            ),
          );
        }
      },
      child: Scrollbar(
        controller: _control,
        thumbVisibility: true, // barra siempre visible (escritorio)
        child: SizedBox(
          height: 220,
          child: ListView.builder(
            controller: _control,
            scrollDirection: Axis.horizontal,
            itemCount: widget.elementos.length,
            itemBuilder: (context, i) => _tarjeta(context, widget.elementos[i]),
          ),
        ),
      ),
    );
  }

  /// Tarjeta: imagen, título (una línea) y subtítulo (dos líneas).
  Widget _tarjeta(BuildContext context, ElementoFila e) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final sinImagen = Container(
      color: esquema.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(widget.iconoSinImagen, size: 44, color: esquema.outline),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: e.onTap,
        child: SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 110,
                  height: 150,
                  child: e.imagen == null
                      ? sinImagen
                      : Image.network(
                          e.imagen!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => sinImagen,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                e.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (e.subtitulo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  e.subtitulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: esquema.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// WIDGET de tarjeta para un resultado (serie, película, manga o persona).
// Muestra la imagen, el título, el año, insignias opcionales (estado,
// nota, cuenta atrás) y dos botones: favoritos y visto (este último se
// omite en personas). Los botones solo avisan con onFavorito()/onVisto();
// quién guarda es la vista que la usa (Inicio, Favoritos o Vistos).
import 'package:flutter/material.dart';

/// Tarjeta de un resultado: póster, título, año y botones de favoritos
/// (corazón) y vistos (ojo). Si no hay póster (o no carga) se muestra
/// un icono de marcador.
class TarjetaResultado extends StatelessWidget {
  final String titulo;
  final int? anio;
  final String? posterUrl;
  final bool esFavorito;
  final VoidCallback onFavorito;
  final bool esVisto;
  final VoidCallback? onVisto; // null: sin botón de visto (personas)
  final VoidCallback onAbrir;
  final List<Widget> insignias; // estado, nota, cuenta atrás...
  final IconData iconoMarcador; // icono si no hay imagen

  const TarjetaResultado({
    super.key,
    required this.titulo,
    this.anio,
    this.posterUrl,
    required this.esFavorito,
    required this.onFavorito,
    required this.esVisto,
    this.onVisto,
    this.insignias = const [],
    this.iconoMarcador = Icons.movie_outlined,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onAbrir,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Póster (2:3) o marcador si no hay imagen
              AspectRatio(
                aspectRatio: 2 / 3,
                child: posterUrl == null
                    ? _marcador(esquema)
                    : Image.network(
                        posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            _marcador(esquema),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (anio != null)
                            Text(
                              '$anio',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    // Botón de añadir/quitar de favoritos
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        esFavorito ? Icons.favorite : Icons.favorite_border,
                        color: esFavorito ? Colors.red : null,
                      ),
                      onPressed: onFavorito,
                    ),
                    // Botón de marcar como visto / quitar de vistos
                    if (onVisto != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          esVisto
                              ? Icons.visibility
                              : Icons.visibility_outlined,
                          color: esVisto ? esquema.primary : null,
                        ),
                        onPressed: onVisto,
                      ),
                  ],
                ),
              ),
              // Insignias (estado, nota, cuenta atrás) si las hay
              if (insignias.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Wrap(spacing: 4, runSpacing: 4, children: insignias),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Icono de marcador cuando no hay póster.
  Widget _marcador(ColorScheme esquema) {
    return Container(
      color: esquema.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(iconoMarcador, size: 48, color: esquema.outline),
    );
  }
}

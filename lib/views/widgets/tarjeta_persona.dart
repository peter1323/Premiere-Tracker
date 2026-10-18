import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// Tarjeta de una persona en los resultados: foto, nombre y departamento
/// (por qué es conocida, p. ej. "Actuación").
/// Si no hay foto (o no carga) se muestra un icono de marcador.
class TarjetaPersona extends StatelessWidget {
  final String nombre;
  final String? fotoUrl;
  final String departamento; // en inglés (TMDB); se traduce aquí
  final String idioma;
  final VoidCallback onAbrir;

  const TarjetaPersona({
    super.key,
    required this.nombre,
    this.fotoUrl,
    this.departamento = '',
    required this.idioma,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final dept = traducirDepartamento(departamento, idioma);
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
              // Foto de perfil (2:3) o marcador si no hay imagen
              AspectRatio(
                aspectRatio: 2 / 3,
                child: fotoUrl == null
                    ? _marcador(esquema)
                    : Image.network(
                        fotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            _marcador(esquema),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (dept.isNotEmpty)
                      Text(
                        dept,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Icono de marcador cuando no hay foto.
  Widget _marcador(ColorScheme esquema) {
    return Container(
      color: esquema.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 48, color: esquema.outline),
    );
  }
}

// WIDGET de tarjeta para un resultado de manga (de AniList). Muestra la
// portada, el título y el estado traducido. Al tocarla avisa con
// onTap() para abrir la ficha. La usan la pantalla Lectura y los
// resultados de búsqueda.
import 'package:flutter/material.dart';

import '../../models/manga_model.dart';

/// Color de cada estado del manga (punto y texto).
Color colorEstadoManga(String estado) {
  switch (estado) {
    case 'emision':
      return const Color(0xFF2E7D32); // verde
    case 'finalizado':
      return const Color(0xFF1565C0); // azul
    case 'parado':
      return const Color(0xFFF9A825); // ámbar
    case 'cancelado':
      return const Color(0xFFC62828); // rojo
    default:
      return const Color(0xFF6A1B9A); // morado (próximamente o desconocido)
  }
}

/// Texto del estado del manga según el idioma de la app.
String estadoManga(String estado, String idioma) {
  final textos = {
    'es': {
      'emision': 'En emisión',
      'finalizado': 'Finalizado',
      'parado': 'En pausa',
      'cancelado': 'Cancelado',
      'proximamente': 'Próximamente',
    },
    'en': {
      'emision': 'Ongoing',
      'finalizado': 'Finished',
      'parado': 'On hold',
      'cancelado': 'Cancelled',
      'proximamente': 'Upcoming',
    },
  };
  return textos[idioma]?[estado] ?? estado;
}

/// País del manga (código de AniList) traducido: JP, KR, CN, TW...
String traducirPais(String codigo, String idioma) {
  final textos = {
    'es': {
      'JP': 'Japón',
      'KR': 'Corea',
      'CN': 'China',
      'TW': 'Taiwán',
      'HK': 'Hong Kong',
    },
    'en': {
      'JP': 'Japan',
      'KR': 'South Korea',
      'CN': 'China',
      'TW': 'Taiwan',
      'HK': 'Hong Kong',
    },
  };
  return textos[idioma]?[codigo] ?? codigo;
}

/// Punto de color + texto del estado (En emisión, Finalizado, En pausa...).
class ChipEstadoManga extends StatelessWidget {
  final String estado;
  final String idioma;

  const ChipEstadoManga({
    super.key,
    required this.estado,
    required this.idioma,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoManga(estado);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          estadoManga(estado, idioma),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Tarjeta de un manga en los resultados: portada, título y estado.
class TarjetaManga extends StatelessWidget {
  final MangaModel manga;
  final String idioma;
  final VoidCallback onAbrir;

  const TarjetaManga({
    super.key,
    required this.manga,
    required this.idioma,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onAbrir,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Portada
            Expanded(
              child: manga.portada.isEmpty
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: const Icon(Icons.menu_book_rounded, size: 40),
                    )
                  : Image.network(
                      manga.portada,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Icon(Icons.menu_book_rounded, size: 40),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  ChipEstadoManga(estado: manga.estado, idioma: idioma),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

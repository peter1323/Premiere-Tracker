// VISTA de la ficha de una persona (se abre con Navigator.push). Muestra
// foto, nombre, cumpleaños, lugar y su filmografía en tarjetas (al tocar
// una se abre la ficha de esa serie o película). Crea su
// PersonaController, que carga y fusiona los datos de TMDB y TVMaze y se
// destruye al volver atrás. Solo dibuja; la lógica está en el controlador.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/persona_controller.dart';
import '../l10n/app_strings.dart';
import '../models/persona_model.dart';
import '../services/enlace_service.dart';
import 'detalle_view.dart';

/// Pantalla de detalle de una persona: foto, por qué es conocida,
/// biografía y en qué ha aparecido (filmografía).
/// Se abre desde la pestaña Personas de Inicio.
class PersonaView extends StatefulWidget {
  final PersonaModel persona;
  final String language; // 'es-ES' o 'en-US'

  const PersonaView({super.key, required this.persona, required this.language});

  /// Abre la ficha de una persona.
  static void abrir(BuildContext context, PersonaModel persona, String language) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PersonaView(persona: persona, language: language),
    ));
  }

  @override
  State<PersonaView> createState() => _PersonaViewState();
}

class _PersonaViewState extends State<PersonaView> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PersonaController(
        personaInicial: widget.persona,
        language: widget.language,
      )..cargar(),
      child: _CuerpoPersona(
        nombreInicial: widget.persona.nombre,
        language: widget.language,
      ),
    );
  }
}

class _CuerpoPersona extends StatelessWidget {
  final String nombreInicial;
  final String language;

  const _CuerpoPersona({required this.nombreInicial, required this.language});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<PersonaController>();
    final idioma = app.idioma;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    final persona = control.persona;
    final nombre = persona?.nombre ?? nombreInicial;

    // Datos ya cargados (o aún no): se muestran aunque siga cargando
    final dept = traducirDepartamento(persona?.departamento ?? '', idioma);
    final bio = persona?.biografia.trim() ?? '';
    final creditos = control.creditos;

    return Scaffold(
      appBar: AppBar(title: Text(nombre, overflow: TextOverflow.ellipsis)),
      body: control.persona == null && control.cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avisos: sin conexión o API key
                      if (control.aviso != null) ...[
                        _Aviso(texto: t(control.aviso!, idioma)),
                        const SizedBox(height: 16),
                      ],

                      // Cabecera: foto + nombre + por qué es conocido
                      _cabecera(context, persona, nombre, dept, idioma),

                      const SizedBox(height: 24),

                      // Biografía
                      Text(t('biografia', idioma),
                          style: tema.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        bio.isEmpty ? t('sinBiografia', idioma) : bio,
                        style: tema.textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 24),

                      // Aparece en: filmografía
                      Text(t('apareceEn', idioma),
                          style: tema.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (creditos.isEmpty)
                        Text(
                          t('sinCreditos', idioma),
                          style: tema.textTheme.bodyMedium,
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: creditos
                              .map((c) => _tarjetaCredito(context, c, idioma))
                              .toList(),
                        ),

                      // Enlaces a las fichas originales (si se conocen)
                      if (persona?.urlPagina != null) ...[
                        const SizedBox(height: 24),
                        _enlaces(context, persona!, idioma, esquema),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Cabecera con la foto, el nombre y el departamento (conocido por).
  Widget _cabecera(BuildContext context, PersonaModel? persona, String nombre,
      String dept, String idioma) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final fallecimiento = persona?.fallecimiento;
    final cumpleanos = persona?.cumpleanos;
    final lugar = persona?.lugarNacimiento ?? persona?.pais;

    // Datos junto a la foto: nombre, departamento y fechas.
    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre, style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        // Por qué es conocido
        if (dept.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.star_outline, size: 18),
            label: Text('${t('conocidoPor', idioma)}: $dept'),
          ),
        const SizedBox(height: 8),
        if (cumpleanos != null)
          Text('${t('nacido', idioma)}: $cumpleanos',
              style: tema.textTheme.bodyMedium),
        if (fallecimiento != null)
          Text('${t('fallecido', idioma)}: $fallecimiento',
              style: tema.textTheme.bodyMedium),
        if (lugar != null && lugar.isNotEmpty)
          Text('${t('lugarNacimiento', idioma)}: $lugar',
              style: tema.textTheme.bodyMedium),
      ],
    );

    // En pantallas estrechas (móvil vertical) la foto se pone arriba y
    // el texto ocupa todo el ancho; en anchas, la foto queda al lado.
    return LayoutBuilder(builder: (context, medidas) {
      final estrecho = medidas.maxWidth < 600;
      final alturaBaja = MediaQuery.of(context).size.height < 520;
      final anchoFoto = estrecho
          ? (medidas.maxWidth * 0.35).clamp(110.0, 150.0)
          : (alturaBaja ? 110.0 : 140.0);

      final foto = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: anchoFoto,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: persona?.fotoUrl == null
                ? _marcadorFoto(esquema)
                : Image.network(
                    persona!.fotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        _marcadorFoto(esquema),
                  ),
          ),
        ),
      );

      if (estrecho) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: foto),
            const SizedBox(height: 16),
            datos,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          foto,
          const SizedBox(width: 20),
          Expanded(child: datos),
        ],
      );
    });
  }

  /// Tarjeta de un crédito: abre el detalle de la serie o película.
  Widget _tarjetaCredito(BuildContext context, CreditoPersonaModel credito,
      String idioma) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return SizedBox(
      width: 170,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _abrirCredito(context, credito),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Póster (2:3) o marcador si no hay imagen
              AspectRatio(
                aspectRatio: 2 / 3,
                child: credito.posterUrl == null
                    ? _marcadorPoster(esquema)
                    : Image.network(
                        credito.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            _marcadorPoster(esquema),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credito.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleSmall,
                    ),
                    if (credito.personaje.isNotEmpty)
                      Text(
                        '${t('comoPersonaje', idioma)} ${credito.personaje}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall,
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

  /// Abre el detalle de la serie o película del crédito.
  void _abrirCredito(BuildContext context, CreditoPersonaModel credito) {
    // Solo TMDB tiene películas; TVMaze siempre es serie
    final tipo = credito.fuente == 'tmdb' ? credito.tipo : 'serie';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetalleView(
        tipo: tipo,
        id: credito.id,
        fuente: credito.fuente,
        tituloInicial: credito.titulo,
        language: language,
      ),
    ));
  }

  /// Enlaces a las fichas originales de la persona (TMDB y TVMaze).
  Widget _enlaces(BuildContext context, PersonaModel persona, String idioma,
      ColorScheme esquema) {
    // TMDB no guarda la URL, pero se arma desde el id.
    final urlTmdb = persona.fuente == 'tmdb'
        ? 'https://www.themoviedb.org/person/${persona.id}'
        : null;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (urlTmdb != null)
          TextButton.icon(
            onPressed: () => EnlaceService.abrir(urlTmdb),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(t('verTmdb', idioma)),
          ),
        if (persona.urlPagina != null)
          TextButton.icon(
            onPressed: () => EnlaceService.abrir(persona.urlPagina!),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(t('verTvmaze', idioma)),
          ),
      ],
    );
  }


  /// Icono de marcador cuando no hay foto de perfil.
  Widget _marcadorFoto(ColorScheme esquema) {
    return Container(
      color: esquema.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 64, color: esquema.outline),
    );
  }

  /// Icono de marcador cuando no hay póster.
  Widget _marcadorPoster(ColorScheme esquema) {
    return Container(
      color: esquema.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.movie_outlined, size: 48, color: esquema.outline),
    );
  }
}

/// Banner de aviso (fuente caída, sin conexión, API key...).
class _Aviso extends StatelessWidget {
  final String texto;
  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: esquema.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: esquema.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: esquema.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

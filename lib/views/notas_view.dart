// VISTA de la pantalla Notas (sección 5 del menú). Muestra las notas del
// usuario con un buscador por título. Una nota guarda el título del
// título, dónde se quedó (p. ej. 'T4 E2') y un campo libre de datos. El
// diálogo para crear/editar una nota es StatefulWidget que libera su
// TextEditingController en dispose(). Solo dibuja y llama a
// NotasController; las notas le llegan de AppController. Vive en el
// IndexedStack.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../controllers/notas_controller.dart';
import '../l10n/app_strings.dart';
import '../models/nota_model.dart';

/// Pantalla de Notas: tabla con Título | Última vista | Más datos para
/// recordar dónde se dejó cada serie o película. Solo el título es
/// obligatorio; las otras dos columnas son campos libres opcionales.
/// Las notas se ordenan por edición reciente y se exportan junto con
/// favoritos y vistos en la copia de seguridad.
class NotasView extends StatefulWidget {
  const NotasView({super.key});

  @override
  State<NotasView> createState() => _NotasViewState();
}

class _NotasViewState extends State<NotasView> {
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
      create: (_) => NotasController(),
      child: _CuerpoNotas(buscador: _buscador),
    );
  }
}

class _CuerpoNotas extends StatefulWidget {
  final TextEditingController buscador;
  const _CuerpoNotas({required this.buscador});

  @override
  State<_CuerpoNotas> createState() => _CuerpoNotasState();
}

class _CuerpoNotasState extends State<_CuerpoNotas> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<NotasController>();
    final idioma = app.idioma;

    // Mantiene la lista al día con las notas del usuario actual.
    // Se hace tras el build para no notificar durante el mismo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotasController>().syncNotas(app.notas);
      }
    });

    final notas = control.notasFiltradas;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t('notas', idioma),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              // Botón de añadir nota
              FilledButton.icon(
                onPressed: () => _abrirDialogo(app, idioma),
                icon: const Icon(Icons.add),
                label: Text(t('anadirNota', idioma)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buscador por texto (título, última vista o datos extra)
          TextField(
            controller: widget.buscador,
            onChanged: control.cambiarConsulta,
            decoration: InputDecoration(
              hintText: t('buscarNotasHint', idioma),
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
          const SizedBox(height: 16),
          // Tabla o estado vacío
          Expanded(
            child: !control.hayNotas
                ? _EstadoVacio(
                    icono: Icons.edit_note,
                    texto: t('sinNotas', idioma),
                  )
                : notas.isEmpty
                    ? _EstadoVacio(
                        icono: Icons.search_off,
                        texto: t('sinCoincidencias', idioma),
                      )
                    : _tabla(notas, app, idioma),
          ),
        ],
      ),
    );
  }

  /// Tabla con las notas: Título | Última vista | Más datos | acciones.
  Widget _tabla(List<NotaModel> notas, AppController app, String idioma) {
    final esquema = Theme.of(context).colorScheme;
    // La tabla puede ser más ancha que la pantalla en móvil, así que
    // permite desplazar en horizontal (ver todas las columnas) y en
    // vertical (ver todas las filas). En escritorio, donde cabe, no se
    // ve ningún deslizamiento.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(esquema.surfaceContainerHigh),
          columnSpacing: 32,
          columns: [
            DataColumn(label: Text(t('titulo', idioma))),
            DataColumn(label: Text(t('ultimaVista', idioma))),
            DataColumn(label: Text(t('masDatos', idioma))),
            const DataColumn(label: SizedBox.shrink()), // acciones
          ],
          rows: [
            for (final nota in notas)
              DataRow(cells: [
                DataCell(Text(nota.titulo)),
                DataCell(Text(nota.ultimaVista)),
                // "Más datos" en crudo: lo que sea ancho lo cubre el
                // desplazamiento horizontal de la tabla
                DataCell(Text(nota.masDatos)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: t('editarNota', idioma),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _abrirDialogo(app, idioma, nota),
                    ),
                    IconButton(
                      tooltip: t('eliminarNota', idioma),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline, color: esquema.error),
                      onPressed: () => app.quitarNota(nota.id),
                    ),
                  ],
                )),
              ]),
          ],
        ),
      ),
    );
  }

  /// Abre el diálogo de nueva nota o de edición (si viene [existente]).
  Future<void> _abrirDialogo(AppController app, String idioma,
      [NotaModel? existente]) async {
    final resultado = await showDialog<NotaModel>(
      context: context,
      builder: (_) => _DialogoNota(idioma: idioma, nota: existente),
    );
    if (resultado == null) return;
    if (existente == null) {
      await app.agregarNota(resultado);
    } else {
      await app.editarNota(resultado);
    }
  }
}

/// Diálogo para crear o editar una nota: solo el título es obligatorio.
class _DialogoNota extends StatefulWidget {
  final String idioma;
  final NotaModel? nota; // null = nota nueva
  const _DialogoNota({required this.idioma, this.nota});

  @override
  State<_DialogoNota> createState() => _DialogoNotaState();
}

class _DialogoNotaState extends State<_DialogoNota> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo =
      TextEditingController(text: widget.nota?.titulo ?? '');
  late final TextEditingController _ultimaVista =
      TextEditingController(text: widget.nota?.ultimaVista ?? '');
  late final TextEditingController _masDatos =
      TextEditingController(text: widget.nota?.masDatos ?? '');

  @override
  void dispose() {
    _titulo.dispose();
    _ultimaVista.dispose();
    _masDatos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idioma = widget.idioma;
    return AlertDialog(
      title: Text(widget.nota == null
          ? t('anadirNota', idioma)
          : t('editarNota', idioma)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Único campo obligatorio: el título
              TextFormField(
                controller: _titulo,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: t('titulo', idioma),
                  hintText: t('notaHintTitulo', idioma),
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return t('tituloRequerido', idioma);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Opcional: dónde se quedó (p. ej. 'T4 E2')
              TextFormField(
                controller: _ultimaVista,
                decoration: InputDecoration(
                  labelText: t('ultimaVista', idioma),
                  hintText: t('notaHintTemporada', idioma),
                ),
              ),
              const SizedBox(height: 12),
              // Opcional: campo libre para datos extra
              TextFormField(
                controller: _masDatos,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: t('masDatos', idioma),
                  hintText: t('notaHintMasDatos', idioma),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cerrar', idioma)),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(t('guardar', idioma)),
        ),
      ],
    );
  }

  /// Valida (solo el título) y devuelve la nota al cerrar el diálogo.
  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final titulo = _titulo.text.trim();
    final ultimaVista = _ultimaVista.text.trim();
    final masDatos = _masDatos.text.trim();
    final nota = widget.nota == null
        ? NotaModel.nueva(
            titulo: titulo, ultimaVista: ultimaVista, masDatos: masDatos)
        : widget.nota!.copiarCon(
            titulo: titulo, ultimaVista: ultimaVista, masDatos: masDatos);
    Navigator.pop(context, nota);
  }
}

/// Estado vacío centrado de la pantalla de notas.
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

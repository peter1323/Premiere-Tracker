import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/ajustes_controller.dart';
import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';

/// Pantalla de Ajustes: idioma, tema, copia de seguridad, gestión de
/// usuarios y créditos (TMDB y TVMaze).
class AjustesView extends StatefulWidget {
  const AjustesView({super.key});

  @override
  State<AjustesView> createState() => _AjustesViewState();
}

class _AjustesViewState extends State<AjustesView> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    // El controlador necesita el AppController para el usuario actual
    return ChangeNotifierProvider(
      create: (_) => AjustesController(app: app),
      child: _CuerpoAjustes(),
    );
  }
}

class _CuerpoAjustes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final control = context.watch<AjustesController>();
    final idioma = app.idioma;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('ajustes', idioma),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // ===== Idioma =====
              Text(t('idioma', idioma),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'es', label: Text(t('espanol', idioma))),
                  ButtonSegment(
                      value: 'en', label: Text(t('ingles', idioma))),
                ],
                selected: {app.idioma},
                onSelectionChanged: (nuevo) {
                  if (nuevo.isNotEmpty) app.cambiarIdioma(nuevo.first);
                },
              ),
              const SizedBox(height: 24),

              // ===== Tema =====
              Text(t('tema', idioma),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'claro', label: Text(t('modoClaro', idioma))),
                  ButtonSegment(
                      value: 'oscuro', label: Text(t('modoOscuro', idioma))),
                ],
                selected: {app.esOscuro ? 'oscuro' : 'claro'},
                onSelectionChanged: (nuevo) {
                  if (nuevo.isNotEmpty) app.cambiarTemaA(nuevo.first);
                },
              ),
              const SizedBox(height: 24),

              // ===== Copia de seguridad =====
              Text(t('copiaSeguridad', idioma),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: control.ocupado
                        ? null
                        : () => _exportar(context, control, idioma),
                    icon: const Icon(Icons.upload),
                    label: Text(t('exportarFavoritos', idioma)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: control.ocupado
                        ? null
                        : () => _importar(context, control, idioma),
                    icon: const Icon(Icons.download),
                    label: Text(t('importarFavoritos', idioma)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ===== Gestión de usuarios =====
              Text(t('gestionUsuarios', idioma),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(app.nombreUsuario,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _dialogoNombre(context, idioma),
                    icon: const Icon(Icons.edit),
                    label: Text(t('cambiarNombre', idioma)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _dialogoPin(context, control, idioma),
                    icon: const Icon(Icons.pin),
                    label: Text(t('cambiarPin', idioma)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () => _confirmarBorrar(context, control, idioma),
                    icon: const Icon(Icons.delete),
                    label: Text(t('borrarUsuario', idioma)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ===== Créditos =====
              Text(t('creditos', idioma),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _creditos(context, idioma),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Copia de seguridad =====

  Future<void> _exportar(BuildContext context,
      AjustesController control, String idioma) async {
    final clave = await control.exportarFavoritos();
    if (!context.mounted) return;
    // Avisa tanto del éxito como de un fallo real (no del cancelar)
    if (clave == 'exportadoOk' || clave == 'error') {
      _aviso(context, t(clave, idioma));
    }
  }

  Future<void> _importar(BuildContext context,
      AjustesController control, String idioma) async {
    final resultado = await control.importarFavoritos();
    if (!context.mounted) return;
    if (resultado.clave.isEmpty) return; // cancelado
    _aviso(context, t(resultado.clave, idioma));
  }

  // ===== Gestión de usuarios =====

  /// Pide el nuevo nombre del usuario.
  ///
  /// El diálogo es un widget propio ([_DialogoNombre]) para que sus
  /// controladores se liberen en su `dispose()` (al desmontarse), y no
  /// justo al cerrar `showDialog`: el diálogo sigue montado mientras
  /// dura su animación de salida y se usarían controladores ya
  /// liberados, lo que rompía el árbol de widgets.
  Future<void> _dialogoNombre(BuildContext context, String idioma) async {
    final app = context.read<AppController>();
    final control = context.read<AjustesController>();

    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoNombre(
        inicial: app.nombreUsuario,
        control: control,
        idioma: idioma,
      ),
    );
    if (guardado == true && context.mounted) {
      _aviso(context, t('nombreCambiado', idioma));
    }
  }

  /// Pide el PIN actual y el nuevo para cambiarlo.
  Future<void> _dialogoPin(BuildContext context,
      AjustesController control, String idioma) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCambiarPin(control: control, idioma: idioma),
    );
    if (guardado == true && context.mounted) {
      _aviso(context, t('pinCambiado', idioma));
    }
  }

  Future<void> _confirmarBorrar(BuildContext context,
      AjustesController control, String idioma) async {
    final borrar = await showDialog<bool>(
      context: context,
      builder: (contextDialog) => AlertDialog(
        title: Text(t('borrarUsuario', idioma)),
        content: Text(t('borrarUsuarioConfirm', idioma)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contextDialog).pop(false),
            child: Text(t('cancelar', idioma)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(contextDialog).pop(true),
            child: Text(t('aceptar', idioma)),
          ),
        ],
      ),
    );
    if (borrar == true) {
      // Borra el usuario y vuelve a la pantalla de usuarios
      await control.borrarUsuario();
    }
  }

  // ===== Créditos =====

  Widget _creditos(BuildContext context, String idioma) {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo de TMDB (con marcador mientras no exista el archivo)
        Image.asset(
          'assets/images/tmdb_logo.png',
          height: 40,
          errorBuilder: (context, error, stack) => Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: esquema.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              'TMDB',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: esquema.outline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Texto obligatorio por las condiciones de uso de TMDB
        Text(
          t('tmdbAviso', idioma),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        // Crédito de TVMaze con enlace clicable
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _abrirTvmaze(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              t('tvmazeCredit', idioma),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: esquema.primary,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  /// Abre la web de TVMaze en el navegador.
  Future<void> _abrirTvmaze() async {
    final uri = Uri.parse('https://www.tvmaze.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ===== Utilidades =====

  void _aviso(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }
}

/// Diálogo para cambiar el nombre del usuario.
///
/// Los `TextEditingController` se crean aquí y se liberan en [dispose],
/// cuando el diálogo ya se ha desmontado (nunca al cerrar `showDialog`:
/// mientras dura la animación de salida los TextField siguen montados).
class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre({
    required this.inicial,
    required this.control,
    required this.idioma,
  });

  final String inicial;
  final AjustesController control;
  final String idioma;

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final TextEditingController texto;
  String? error;

  @override
  void initState() {
    super.initState();
    texto = TextEditingController(text: widget.inicial);
  }

  @override
  void dispose() {
    texto.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    final err = await widget.control.cambiarNombre(texto.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => error = t(err, widget.idioma));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = widget.idioma;
    return AlertDialog(
      title: Text(t('cambiarNombre', idioma)),
      content: SizedBox(
        width: 300,
        child: TextField(
          controller: texto,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t('nombreUsuario', idioma),
            errorText: error,
          ),
          onSubmitted: (_) => guardar(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('cancelar', idioma)),
        ),
        FilledButton(
          onPressed: guardar,
          child: Text(t('aceptar', idioma)),
        ),
      ],
    );
  }
}

/// Diálogo para cambiar el PIN del usuario (actual + nuevo).
class _DialogoCambiarPin extends StatefulWidget {
  const _DialogoCambiarPin({required this.control, required this.idioma});

  final AjustesController control;
  final String idioma;

  @override
  State<_DialogoCambiarPin> createState() => _DialogoCambiarPinState();
}

class _DialogoCambiarPinState extends State<_DialogoCambiarPin> {
  late final TextEditingController actual;
  late final TextEditingController nuevo;
  String? error;

  @override
  void initState() {
    super.initState();
    actual = TextEditingController();
    nuevo = TextEditingController();
  }

  @override
  void dispose() {
    actual.dispose();
    nuevo.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    final err = await widget.control.cambiarPin(actual.text, nuevo.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => error = t(err, widget.idioma));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = widget.idioma;
    return AlertDialog(
      title: Text(t('cambiarPin', idioma)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: actual,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('pinActual', idioma),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nuevo,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('nuevoPin', idioma),
                errorText: error,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('cancelar', idioma)),
        ),
        FilledButton(
          onPressed: guardar,
          child: Text(t('aceptar', idioma)),
        ),
      ],
    );
  }
}

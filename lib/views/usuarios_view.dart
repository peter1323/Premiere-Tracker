// VISTA de la pantalla de usuarios (la primera que se ve, antes de iniciar
// sesión). Muestra los usuarios del equipo para elegir uno y entrar con su
// PIN, y permite crear usuarios nuevos. Los diálogos (login con PIN y
// creación de usuario) son StatefulWidget que liberan sus
// TextEditingController en dispose() (antes se liberaban al cerrar
// showDialog y eso causaba un fallo de pantalla roja). Al validar el PIN
// llama a AppController.establecerUsuario() para entrar a la app.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/app_controller.dart';
import '../../controllers/usuarios_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/usuario_model.dart';

/// Pantalla inicial: lista de usuarios y creación de usuarios con PIN.
class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  // Estado de la sección de clave TMDB
  final TextEditingController _claveCtrl = TextEditingController();
  bool _editandoClave = false;
  bool _mostrarClave = false;
  String? _errorClave;

  @override
  void initState() {
    super.initState();
    // Carga los usuarios guardados cuando termine el primer frame
    // (no se puede notificar durante el build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UsuariosController>().cargarUsuarios();
    });
  }

  @override
  void dispose() {
    _claveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final controlador = context.watch<UsuariosController>();
    final idioma = app.idioma;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Icon(
                  Icons.live_tv_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  t('appName', idioma),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  t('usuarios', idioma),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                if (controlador.cargando)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controlador.errorCarga != null) ...[
                  // No se pudieron leer los datos locales: aviso y reintento
                  // (en vez de quedarse en carga eterna)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          t(controlador.errorCarga!, idioma),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: controlador.cargarUsuarios,
                          icon: const Icon(Icons.refresh),
                          label: Text(t('reintentar', idioma)),
                        ),
                      ],
                    ),
                  ),
                ] else if (controlador.usuarios.isEmpty)
                  Text(t('sinUsuarios', idioma), textAlign: TextAlign.center)
                else
                  ...controlador.usuarios.map(
                    (u) => _tarjetaUsuario(u, idioma),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _mostrarDialogoCrear(idioma),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(t('crearUsuario', idioma)),
                ),
                const SizedBox(height: 24),
                // Clave TMDB: se inserta y guarda en esta pantalla
                _seccionClave(controlador, idioma),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta de un usuario: círculo con la inicial + nombre.
  Widget _tarjetaUsuario(UsuarioModel usuario, String idioma) {
    final inicial = usuario.nombre.trim().isEmpty
        ? '?'
        : usuario.nombre.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pedirPin(usuario, idioma),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(child: Text(inicial)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    usuario.nombre,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pide el PIN del usuario. Si es incorrecto muestra el aviso sin
  /// cerrar y, a partir del segundo fallo, una pista con los dos
  /// primeros dígitos. Desde el propio diálogo también se puede cambiar
  /// el PIN (siempre validando primero el actual, por seguridad).
  Future<void> _pedirPin(UsuarioModel usuario, String idioma) async {
    final usuarioEntrar = await showDialog<UsuarioModel>(
      context: context,
      builder: (_) => _DialogoPin(usuario: usuario, idioma: idioma),
    );

    // PIN correcto (o recién cambiado): entra con el usuario
    if (usuarioEntrar != null && mounted) {
      context.read<AppController>().establecerUsuario(usuarioEntrar);
    }
  }

  /// Diálogo para crear un usuario (nombre + PIN de 4 dígitos).
  Future<void> _mostrarDialogoCrear(String idioma) async {
    final creado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCrear(idioma: idioma),
    );

    if (creado == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('usuarioCreado', idioma))));
    }
  }

  /// Sección de la clave TMDB: estado actual, campo para insertarla y
  /// botón para modificarla. La clave se guarda en el dispositivo y nunca
  /// se muestra completa.
  Widget _seccionClave(UsuariosController control, String idioma) {
    final esquema = Theme.of(context).colorScheme;
    // Sin clave se muestra el campo directamente (modo edición)
    final editando = _editandoClave || !control.hayClaveTmdb;
    final origen = t('claveGuardadaApp', idioma);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_outlined, color: esquema.primary),
                const SizedBox(width: 8),
                Text(
                  t('claveTmdb', idioma),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!editando) ...[
              // Clave activa: origen y cuatro últimos caracteres
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: esquema.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$origen · ${control.claveTmdbEnmascarada}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _editandoClave = true;
                    _errorClave = null;
                    _mostrarClave = false;
                  }),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(t('modificarClave', idioma)),
                ),
              ),
            ] else ...[
              TextField(
                controller: _claveCtrl,
                enabled: !control.comprobandoClave,
                obscureText: !_mostrarClave,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _guardarClave(control),
                decoration: InputDecoration(
                  labelText: t('claveInsertar', idioma),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _mostrarClave = !_mostrarClave),
                    icon: Icon(
                      _mostrarClave ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              if (control.comprobandoClave) ...[
                const SizedBox(height: 8),
                Text(
                  t('claveComprobando', idioma),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_errorClave != null) ...[
                const SizedBox(height: 8),
                Text(
                  t(_errorClave!, idioma),
                  style: TextStyle(color: esquema.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: control.comprobandoClave
                        ? null
                        : () => _guardarClave(control),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(t('guardar', idioma)),
                  ),
                  if (control.hayClaveTmdb)
                    TextButton(
                      onPressed: control.comprobandoClave
                          ? null
                          : () => setState(() {
                              _editandoClave = false;
                              _errorClave = null;
                              _claveCtrl.clear();
                            }),
                      child: Text(t('cancelar', idioma)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _abrirPaginaClave,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(t('obtenerClave', idioma)),
            ),
          ],
        ),
      ),
    );
  }

  /// Comprueba la clave con TMDB y, si es válida, la guarda en la app.
  Future<void> _guardarClave(UsuariosController control) async {
    final error = await control.guardarClaveTmdb(_claveCtrl.text);
    if (!mounted) return;
    setState(() {
      _errorClave = error;
      if (error == null) {
        _editandoClave = false;
        _claveCtrl.clear();
        _mostrarClave = false;
      }
    });
  }

  /// Abre la página de TMDB donde se solicita la API key.
  Future<void> _abrirPaginaClave() async {
    final uri = Uri.parse('https://www.themoviedb.org/settings/api');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Diálogo de login: pide el PIN del usuario (y permite cambiarlo).
///
/// Los `TextEditingController` viven aquí y se liberan en [dispose],
/// es decir, cuando el diálogo ya se ha desmontado. Antes se liberaban
/// al cerrar `showDialog`, pero el diálogo sigue montado mientras dura
/// su animación de salida y los TextField volvían a registrar escuchas
/// en un controlador ya liberado (era la causa del fallo de la app).
class _DialogoPin extends StatefulWidget {
  const _DialogoPin({required this.usuario, required this.idioma});

  final UsuarioModel usuario;
  final String idioma;

  @override
  State<_DialogoPin> createState() => _DialogoPinState();
}

class _DialogoPinState extends State<_DialogoPin> {
  late final TextEditingController textoPin;
  late final TextEditingController textoPinActual;
  late final TextEditingController textoPinNuevo;

  String paso = 'entrar'; // 'entrar' (login) o 'cambiar' (PIN nuevo)
  String? errorEntrar; // aviso de PIN incorrecto
  String? errorPinActual; // aviso al validar el PIN actual
  String? errorNuevoPin; // aviso sobre el PIN nuevo
  String? pista; // pista con los dos primeros dígitos (tras 2 fallos)
  int fallos = 0;

  @override
  void initState() {
    super.initState();
    textoPin = TextEditingController();
    textoPinActual = TextEditingController();
    textoPinNuevo = TextEditingController();
  }

  @override
  void dispose() {
    textoPin.dispose();
    textoPinActual.dispose();
    textoPinNuevo.dispose();
    super.dispose();
  }

  /// Intenta entrar; si el PIN está mal, muestra el aviso y
  /// limpia el campo para reescribirlo. A partir del segundo
  /// fallo se enseña la pista con los dos primeros dígitos.
  void intentarEntrar() {
    final correcto = context.read<UsuariosController>().validarPin(
      widget.usuario,
      textoPin.text,
    );
    if (correcto) {
      Navigator.of(context).pop(widget.usuario);
      return;
    }
    fallos++;
    if (fallos >= 2 && pista == null) {
      final digitos = context.read<UsuariosController>().pistaPin(
        widget.usuario,
      );
      if (digitos.isNotEmpty) {
        pista = '${t('pinPista', widget.idioma)} $digitos';
      }
    }
    setState(() {
      errorEntrar = t('pinIncorrecto', widget.idioma);
      textoPin.clear();
    });
  }

  /// Cambia el PIN tras validar el actual; si todo bien se
  /// cierra y se entra con el usuario que trae el PIN nuevo.
  Future<void> intentarCambiar() async {
    setState(() {
      errorPinActual = null;
      errorNuevoPin = null;
    });
    final cambio = await context.read<UsuariosController>().cambiarPinDeUsuario(
      widget.usuario,
      textoPinActual.text,
      textoPinNuevo.text,
    );
    if (!mounted) return;
    if (cambio.error != null) {
      setState(() {
        if (cambio.error == 'pinIncorrecto') {
          errorPinActual = t('pinIncorrecto', widget.idioma);
        } else {
          errorNuevoPin = t(cambio.error!, widget.idioma);
        }
      });
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('pinCambiado', widget.idioma))));
    Navigator.of(context).pop(cambio.usuario);
  }

  @override
  Widget build(BuildContext context) {
    final idioma = widget.idioma;

    // Contenido según el paso: login o cambio de PIN
    final Widget contenido;
    if (paso == 'entrar') {
      contenido = SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('escribePin', idioma)),
            const SizedBox(height: 12),
            TextField(
              controller: textoPin,
              autofocus: true,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              // Al llegar a los 4 dígitos se intenta entrar solo
              // (con Enter o el botón también, por si acaso)
              onChanged: (valor) {
                // El aviso se quita al volver a escribir
                if (errorEntrar != null) {
                  setState(() => errorEntrar = null);
                }
                if (valor.length == 4) intentarEntrar();
              },
              onSubmitted: (_) => intentarEntrar(),
              decoration: InputDecoration(
                labelText: t('pin', idioma),
                errorText: errorEntrar,
                counterText: '',
              ),
            ),
            // Tras dos fallos: pista con los dos primeros dígitos
            if (pista != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pista!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            // Opción de cambiar el PIN desde este diálogo
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  textoPin.clear();
                  errorEntrar = null;
                  paso = 'cambiar';
                }),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(t('cambiarPin', idioma)),
              ),
            ),
          ],
        ),
      );
    } else {
      contenido = SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textoPinActual,
              autofocus: true,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('pinActual', idioma),
                errorText: errorPinActual,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textoPinNuevo,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => intentarCambiar(),
              decoration: InputDecoration(
                labelText: t('nuevoPin', idioma),
                errorText: errorNuevoPin,
                counterText: '',
              ),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      // Con el móvil en horizontal y el teclado abierto no cabe: se desliza
      scrollable: true,
      title: Text(
        paso == 'entrar' ? widget.usuario.nombre : t('cambiarPin', idioma),
      ),
      content: contenido,
      actions: [
        TextButton(
          onPressed: () {
            if (paso == 'entrar') {
              Navigator.of(context).pop(); // cancelar
            } else {
              // Vuelve al paso de entrar
              setState(() {
                errorPinActual = null;
                errorNuevoPin = null;
                paso = 'entrar';
              });
            }
          },
          child: Text(
            paso == 'entrar' ? t('cancelar', idioma) : t('volver', idioma),
          ),
        ),
        FilledButton(
          onPressed: paso == 'entrar'
              ? intentarEntrar
              : () => intentarCambiar(),
          child: Text(
            paso == 'entrar' ? t('entrar', idioma) : t('guardar', idioma),
          ),
        ),
      ],
    );
  }
}

/// Diálogo para crear un usuario (nombre + PIN de 4 dígitos).
///
/// Igual que [_DialogoPin], los controladores se liberan en [dispose]
/// y no al cerrar `showDialog`, para no usarlos con el diálogo aún
/// montado durante su animación de salida.
class _DialogoCrear extends StatefulWidget {
  const _DialogoCrear({required this.idioma});

  final String idioma;

  @override
  State<_DialogoCrear> createState() => _DialogoCrearState();
}

class _DialogoCrearState extends State<_DialogoCrear> {
  late final TextEditingController textoNombre;
  late final TextEditingController textoPin;

  String? errorNombre;
  String? errorPin;
  String? errorGeneral; // fallo del almacenamiento del dispositivo

  @override
  void initState() {
    super.initState();
    textoNombre = TextEditingController();
    textoPin = TextEditingController();
  }

  @override
  void dispose() {
    textoNombre.dispose();
    textoPin.dispose();
    super.dispose();
  }

  /// Valida con el controlador; si hay error lo muestra en el campo
  Future<void> intentar() async {
    final idioma = widget.idioma;
    setState(() => errorGeneral = null);
    final errorClave = await context.read<UsuariosController>().crearUsuario(
      textoNombre.text,
      textoPin.text,
    );
    if (!mounted) return;
    if (errorClave == null) {
      Navigator.of(context).pop(true);
    } else if (errorClave == 'errorAlmacenamiento') {
      // Fallo del dispositivo: se avisa sin cerrar el diálogo
      setState(() => errorGeneral = t(errorClave, idioma));
    } else {
      setState(() {
        if (errorClave == 'nombreRequerido') {
          errorNombre = t(errorClave, idioma);
        } else {
          errorPin = t(errorClave, idioma);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = widget.idioma;

    return AlertDialog(
      // Con el móvil en horizontal y el teclado abierto no cabe: se desliza
      scrollable: true,
      title: Text(t('crearUsuario', idioma)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorGeneral != null) ...[
              Text(
                errorGeneral!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: textoNombre,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t('nombreUsuario', idioma),
                errorText: errorNombre,
              ),
              onSubmitted: (_) => intentar(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textoPin,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('pin', idioma),
                errorText: errorPin,
                counterText: '',
              ),
              onSubmitted: (_) => intentar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('cancelar', idioma)),
        ),
        FilledButton(onPressed: intentar, child: Text(t('aceptar', idioma))),
      ],
    );
  }
}

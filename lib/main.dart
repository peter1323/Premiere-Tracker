import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'controllers/app_controller.dart';
import 'controllers/usuarios_controller.dart';
import 'l10n/app_strings.dart';
import 'views/ajustes_view.dart';
import 'views/calendario_view.dart';
import 'views/favoritos_view.dart';
import 'views/inicio_view.dart';
import 'views/notas_view.dart';
import 'views/usuarios_view.dart';
import 'views/vistos_view.dart';
import 'views/widgets/barra_superior.dart';
import 'views/widgets/menu_lateral.dart';

/// Punto de entrada de la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga la API key de TMDB desde el archivo .env.
  // Si falta el archivo, la app sigue funcionando y se mostrará un aviso.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Aviso mostrado en la búsqueda (Fase 2 en adelante)
  }

  runApp(const PremiereTrackerApp());
}

/// Raíz de la aplicación con los controladores globales.
class PremiereTrackerApp extends StatelessWidget {
  const PremiereTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Estado global: usuario actual, tema, idioma y favoritos
        // (cargarTemaInicial aplica el último tema en la pantalla de usuarios)
        ChangeNotifierProvider(
            create: (_) => AppController()..cargarTemaInicial()),
        // Pantalla de usuarios
        ChangeNotifierProvider(create: (_) => UsuariosController()),
      ],
      child: const _Aplicacion(),
    );
  }
}

/// Construye el MaterialApp usando el tema y el idioma del usuario actual.
class _Aplicacion extends StatelessWidget {
  const _Aplicacion();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return MaterialApp(
      title: t('appName', app.idioma),
      debugShowCheckedModeBanner: false,
      theme: crearTemaClaro(),
      darkTheme: crearTemaOscuro(),
      themeMode: app.modoTema,
      // Sin usuario: pantalla de usuarios. Con usuario: la app principal
      // (en la Fase 4 se sustituye por el menú lateral con Inicio/Ajustes)
      home: app.hayUsuario
          ? const _VistaPrincipalProvisional()
          : const UsuariosView(),
    );
  }
}

/// Tema claro (Material 3).
ThemeData crearTemaClaro() {
  final esquema = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C3FE0), // Violeta
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: const Color(0xFFF6F4FB),
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      foregroundColor: esquema.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: esquema.surface,
      indicatorColor: esquema.secondaryContainer,
    ),
    cardTheme: CardThemeData(
      color: esquema.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    extensions: _extensionesCalendario(esquema),
  );
}

/// Tema oscuro (Material 3).
ThemeData crearTemaOscuro() {
  final esquema = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C3FE0), // Violeta
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: const Color(0xFF131018),
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      foregroundColor: esquema.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: esquema.surface,
      indicatorColor: esquema.secondaryContainer,
    ),
    cardTheme: CardThemeData(
      color: esquema.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    extensions: _extensionesCalendario(esquema),
  );
}

/// Extensiones de color del paquete calendar_view con la paleta de la
/// app, para que las vistas de calendario sigan el tema claro/oscuro.
List<ThemeExtension<dynamic>> _extensionesCalendario(ColorScheme esquema) {
  return [
    WeekViewThemeData(
      weekDayTileColor: esquema.surfaceContainerHigh,
      weekDayTextColor: esquema.onSurface,
      hourLineColor: esquema.outlineVariant,
      halfHourLineColor: esquema.outlineVariant,
      quarterHourLineColor: esquema.outlineVariant,
      liveIndicatorColor: esquema.primary,
      pageBackgroundColor: esquema.surface,
      headerIconColor: esquema.onPrimary,
      headerTextColor: esquema.onPrimary,
      headerBackgroundColor: esquema.primary,
      timelineTextColor: esquema.onSurfaceVariant,
      borderColor: esquema.outlineVariant,
      verticalLinesColor: esquema.outlineVariant,
    ),
    DayViewThemeData(
      hourLineColor: esquema.outlineVariant,
      halfHourLineColor: esquema.outlineVariant,
      quarterHourLineColor: esquema.outlineVariant,
      liveIndicatorColor: esquema.primary,
      pageBackgroundColor: esquema.surface,
      headerIconColor: esquema.onPrimary,
      headerTextColor: esquema.onPrimary,
      headerBackgroundColor: esquema.primary,
      timelineTextColor: esquema.onSurfaceVariant,
    ),
  ];
}

/// Estructura principal: menú lateral, barra superior y las tres pantallas.
class _VistaPrincipalProvisional extends StatefulWidget {
  const _VistaPrincipalProvisional();

  @override
  State<_VistaPrincipalProvisional> createState() =>
      _VistaPrincipalProvisionalState();
}

class _VistaPrincipalProvisionalState
    extends State<_VistaPrincipalProvisional> {
  int _indice =
      0; // 0 Inicio, 1 Calendario, 2 Favoritos, 3 Vistos, 4 Notas, 5 Ajustes

  @override
  Widget build(BuildContext context) {
    final idioma = context.watch<AppController>().idioma;

    // Las pantallas se mantienen vivas para no perder el estado
    final pantallas = const [
      InicioView(),
      CalendarioView(),
      FavoritosView(),
      VistosView(),
      NotasView(),
      AjustesView(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Menú lateral fijo a la izquierda
          MenuLateral(
            indice: _indice,
            onSeleccionar: (i) => setState(() => _indice = i),
            idioma: idioma,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Contenido: barra superior + pantalla seleccionada
          Expanded(
            child: Column(
              children: [
                const BarraSuperior(),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: IndexedStack(index: _indice, children: pantallas),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

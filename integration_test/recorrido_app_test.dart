// PRUEBA DE INTEGRACIÓN: recorre la app entera como lo haría una persona,
// en el dispositivo real (Windows o Android). Se ejecuta con:
//
//   flutter test integration_test/recorrido_app_test.dart -d windows
//   flutter test integration_test/recorrido_app_test.dart -d <id del móvil>
//
// Opcional, para probar también TMDB, se le pasa la clave al ejecutar (así
// no queda escrita en ningún archivo):
//   ... --dart-define=TMDB_KEY=<tu clave>
//   ... --dart-define=HORIZONTAL=true   (móvil: prueba la app en horizontal)
//
// Los datos se guardan en memoria (SharedPreferences simulado), así que la
// prueba NO toca los usuarios, favoritos ni notas reales del equipo.
// Sin clave, las búsquedas usan TVMaze (no necesita clave). En los dos
// casos hace falta conexión a internet. Cualquier error de Flutter durante
// el recorrido (overflow, excepción...) hace fallar la prueba.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:premiere_tracker/main.dart';
import 'package:premiere_tracker/services/clave_service.dart';
import 'package:premiere_tracker/views/widgets/tarjeta_resultado.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _claveTmdb = String.fromEnvironment('TMDB_KEY');
const _horizontal = bool.fromEnvironment('HORIZONTAL');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recorrido completo de la app', (tester) async {
    SharedPreferences.setMockInitialValues(
      _claveTmdb.isEmpty ? {} : {'tmdb_key': _claveTmdb},
    );
    await ClaveService.cargar();
    if (_horizontal) {
      // Gira la app a horizontal en el dispositivo real (y la deja libre al final)
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
      addTearDown(() => SystemChrome.setPreferredOrientations([]));
      await Future<void>.delayed(const Duration(seconds: 2)); // que gire
    }
    await tester.pumpWidget(const PremiereTrackerApp());
    await tester.pumpAndSettle();

    // Espera a que aparezca algo que depende de la red (máx. 20 s).
    Future<void> esperar(Finder finder) async {
      for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
        // Espera real: en el dispositivo pump() no deja pasar el tiempo
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(finder, findsWidgets);
    }

    // Pulsa como una persona: si el elemento no se ve (móvil en horizontal,
    // tabla ancha...), primero desliza hasta él.
    Future<void> pulsar(Finder finder) async {
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
    }

    // Pulsa una sección del menú (lateral en Windows, inferior en móvil).
    Future<void> ir(String etiqueta) async {
      final menu = find.byWidgetPredicate(
        (w) => w is NavigationRail || w is NavigationBar,
      );
      await tester.tap(
        find.descendant(of: menu, matching: find.text(etiqueta)),
      );
      await tester.pumpAndSettle();
    }

    // Escribe en el campo de texto que tiene esa etiqueta.
    Future<void> escribir(String etiqueta, String texto) async {
      await tester.enterText(
        find.widgetWithText(TextField, etiqueta).first,
        texto,
      );
      await tester.pump();
    }

    // Busca en Inicio y espera a que aparezca [esperado].
    Future<void> buscar(String texto, Finder esperado) async {
      await ir('Inicio');
      await pulsar(find.byType(TextField));
      await tester.enterText(find.byType(TextField).first, texto);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await esperar(esperado);
    }

    // Botón (icono) dentro de una tarjeta de resultado.
    Finder enTarjeta(Finder tarjeta, IconData icono) =>
        find.descendant(of: tarjeta, matching: find.byIcon(icono));

    // --- 1. Crear usuario y entrar con su PIN ---
    await pulsar(find.text('Crear usuario'));
    await escribir('Nombre de usuario', 'Prueba');
    await escribir('PIN', '1234');
    await pulsar(find.text('Aceptar'));
    expect(find.text('Prueba'), findsOneWidget);

    await pulsar(find.text('Prueba'));
    // PIN incorrecto: avisa y no entra
    await tester.enterText(find.byType(TextField).last, '0000');
    await tester.pumpAndSettle();
    expect(find.text('PIN incorrecto'), findsOneWidget);
    // PIN correcto: entra solo al escribir los 4 dígitos
    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.pumpAndSettle();
    expect(find.text('Crear usuario'), findsNothing);

    // --- 2. Listas vacías ---
    await ir('Favoritos');
    expect(find.text('No tienes favoritos todavía'), findsOneWidget);
    await ir('Vistos');
    expect(
      find.text('No tienes nada marcado como visto todavía'),
      findsOneWidget,
    );

    // --- 3. Notas: crear, buscar y borrar ---
    await ir('Notas');
    expect(find.text('No tienes notas todavía'), findsOneWidget);
    await pulsar(find.text('Añadir nota'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Breaking Bad',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Última vista'),
      'T4 E2',
    );
    await pulsar(find.text('Guardar'));
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('T4 E2'), findsOneWidget);

    final buscadorNotas = find.widgetWithText(
      TextField,
      'Buscar en tus notas...',
    );
    await tester.enterText(buscadorNotas, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No hay coincidencias'), findsOneWidget);
    await tester.enterText(buscadorNotas, '');
    await tester.pumpAndSettle();

    await pulsar(find.byTooltip('Eliminar nota'));
    expect(find.text('No tienes notas todavía'), findsOneWidget);

    // --- 4. Calendario: todas las vistas ---
    await ir('Calendario');
    final selectorModo = find.byType(SegmentedButton<String>).first;
    for (final icono in [
      Icons.view_day_outlined,
      Icons.view_week_outlined,
      Icons.calendar_month_outlined,
      Icons.grid_view_outlined,
    ]) {
      await pulsar(
        find.descendant(of: selectorModo, matching: find.byIcon(icono)),
      );
    }
    await pulsar(find.text('Hoy'));

    // --- 5. Buscar una serie y guardarla en favoritos y vistos ---
    await buscar('Breaking Bad', find.byType(TarjetaResultado));
    final tarjeta = find.byType(TarjetaResultado).first;
    await pulsar(enTarjeta(tarjeta, Icons.favorite_border));
    await pulsar(enTarjeta(tarjeta, Icons.visibility_outlined));

    await ir('Favoritos');
    expect(find.text('No tienes favoritos todavía'), findsNothing);
    expect(find.textContaining('Breaking Bad'), findsWidgets);
    await ir('Vistos');
    expect(find.textContaining('Breaking Bad'), findsWidgets);

    // El calendario carga sus episodios sin romperse
    await ir('Calendario');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Abrir la ficha desde Favoritos y volver
    await ir('Favoritos');
    await pulsar(
      find.descendant(
        of: find.byType(TarjetaResultado),
        matching: find.textContaining('Breaking Bad'),
      ),
    );
    await esperar(find.byType(BackButton));
    await pulsar(find.byType(BackButton));

    // Quitar de favoritos desde su propia pantalla
    await pulsar(enTarjeta(find.byType(TarjetaResultado), Icons.favorite));
    expect(find.text('No tienes favoritos todavía'), findsOneWidget);

    // --- 5b. Serie semanal (Dragon Ball Super: Beerus, sale cada domingo):
    // al guardarla en favoritos sus episodios deben salir en el calendario.
    await buscar('Dragon Ball Super Beerus', find.textContaining('Beerus'));
    final tarjetaDbs = find.ancestor(
      of: find.textContaining('Beerus'),
      matching: find.byType(TarjetaResultado),
    );
    await pulsar(enTarjeta(tarjetaDbs.first, Icons.favorite_border));

    await ir('Calendario');
    await pulsar(
      find.descendant(
        of: find.byType(SegmentedButton<String>).first,
        matching: find.byIcon(Icons.calendar_month_outlined),
      ),
    );
    final episodioDbs = find.textContaining('· Dragon Ball Super');
    await esperar(episodioDbs);
    // Al pulsar el episodio se abre la ficha de la serie
    await pulsar(episodioDbs);
    await esperar(find.byType(BackButton));
    await pulsar(find.byType(BackButton));

    // También en Semana (en Android es la lista por días): sale el domingo
    // y se abre su ficha al pulsarlo
    await pulsar(
      find.descendant(
        of: find.byType(SegmentedButton<String>).first,
        matching: find.byIcon(Icons.view_week_outlined),
      ),
    );
    await esperar(episodioDbs);
    await pulsar(episodioDbs);
    await esperar(find.byType(BackButton));
    await pulsar(find.byType(BackButton));

    // --- 6. Ajustes: idioma y tema ---
    await ir('Ajustes');
    await pulsar(find.text('English'));
    expect(find.text('Settings'), findsWidgets);
    await pulsar(find.text('Español'));
    expect(find.text('Ajustes'), findsWidgets);

    await pulsar(find.byTooltip('Cambiar entre modo claro y oscuro'));
    await pulsar(find.byTooltip('Cambiar entre modo claro y oscuro'));

    // --- 7. Cambiar de usuario: vuelve a la pantalla de usuarios ---
    await pulsar(find.byTooltip('Prueba'));
    await pulsar(find.text('Cambiar de usuario'));
    expect(find.text('Crear usuario'), findsOneWidget);
    expect(find.text('Prueba'), findsOneWidget);
  });
}

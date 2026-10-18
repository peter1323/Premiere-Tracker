import 'package:flutter_test/flutter_test.dart';
import 'package:premiere_tracker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('La app muestra la pantalla de usuarios', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PremiereTrackerApp());
    await tester.pumpAndSettle();
    expect(find.text('Crear usuario'), findsOneWidget);
  });
}

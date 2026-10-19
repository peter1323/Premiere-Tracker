// Test manual para reproducir el fallo al introducir el PIN de un usuario.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premiere_tracker/main.dart';
import 'package:premiere_tracker/services/almacenamiento_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('entrar con el PIN correcto de un usuario creado', (tester) async {
    final errores = <FlutterErrorDetails>[];
    FlutterError.onError = (details) => errores.add(details);

    SharedPreferences.setMockInitialValues({
      'usuarios': jsonEncode([
        {
          'id': 'u1',
          'nombre': 'Ana',
          'pinHash': AlmacenamientoService.hashPin('1234'),
          'tema': 'claro',
          'idioma': 'es',
          'favoritos': <dynamic>[],
          'vistos': <dynamic>[],
          'notas': <dynamic>[],
        }
      ]),
    });

    Future<void> paso(String nombre, Future<void> Function() accion) async {
      final antes = errores.length;
      try {
        await accion();
      } catch (e) {
        // ignore: avoid_print
        print('[$nombre] EXCEPCION SINCrona: $e');
      }
      if (errores.length > antes) {
        // ignore: avoid_print
        print('[$nombre] ${errores.length - antes} error(es) capturados');
      }
    }

    await paso('pumpApp', () => tester.pumpWidget(const PremiereTrackerApp()));
    await paso('settleInicial', () => tester.pumpAndSettle());
    await paso('tapUsuario', () => tester.tap(find.text('Ana')));
    await paso('settleDialogo', () => tester.pumpAndSettle());
    await paso(
        'escribePin', () => tester.enterText(find.byType(TextField).first, '1234'));
    await paso('settleFinal', () => tester.pumpAndSettle());

    for (var i = 0; i < errores.length; i++) {
      final e = errores[i];
      // ignore: avoid_print
      print('\n===== ERROR ${i + 1} =====');
      // ignore: avoid_print
      print('EXCEPCION: ${e.exception}');
      // ignore: avoid_print
      print('CONTEXTO: ${e.context}');
      final st = e.stack?.toString().split('\n').take(25).join('\n');
      // ignore: avoid_print
      print('STACK:\n$st');
    }

    expect(errores, isEmpty,
        reason: 'La app lanza ${errores.length} errores al entrar con el PIN');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

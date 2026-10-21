// TESTS de la lógica con más riesgo de perder o estropear datos:
// leer copias de seguridad, no duplicar obras entre TMDB y TVMaze,
// importar sin duplicar, validar el PIN y no borrar usuarios si los datos
// guardados están corruptos. Se ejecutan con `flutter test`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:premiere_tracker/controllers/app_controller.dart';
import 'package:premiere_tracker/models/favorito_model.dart';
import 'package:premiere_tracker/models/nota_model.dart';
import 'package:premiere_tracker/models/usuario_model.dart';
import 'package:premiere_tracker/services/almacenamiento_service.dart';
import 'package:premiere_tracker/services/copia_seguridad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

FavoritoModel _fav(String fuente, int id, String titulo) =>
    FavoritoModel(tipo: 'serie', fuente: fuente, id: id, titulo: titulo);

/// Entra con un usuario nuevo guardado en unas preferencias simuladas.
Future<AppController> _appConUsuario() async {
  const usuario = UsuarioModel(id: 'u1', nombre: 'Ana', pinHash: 'x');
  SharedPreferences.setMockInitialValues({
    'usuarios': jsonEncode([usuario.toJson()]),
  });
  return AppController()..establecerUsuario(usuario);
}

void main() {
  group('Copia de seguridad', () {
    test(
      'una copia antigua (solo favoritos) con una entrada rota se importa',
      () {
        final r = CopiaSeguridadService.leerCopia(
          jsonEncode({
            'favoritos': [
              _fav('tmdb', 1, 'Breaking Bad').toJson(),
              {'tipo': 'serie'}, // corrupta: le faltan campos
            ],
          }),
        );
        expect(r.valido, isTrue);
        expect(r.favoritos.map((f) => f.titulo), ['Breaking Bad']);
        expect(r.vistos, isEmpty);
        expect(r.notas, isEmpty);
      },
    );

    test('un archivo que no es una copia se marca como inválido', () {
      expect(CopiaSeguridadService.leerCopia('no es json').valido, isFalse);
      expect(CopiaSeguridadService.leerCopia('[1, 2]').valido, isFalse);
      expect(
        CopiaSeguridadService.leerCopia(
          jsonEncode({
            'favoritos': [
              {'tipo': 'serie'},
            ],
          }),
        ).valido,
        isFalse,
      );
    });
  });

  group('Favoritos', () {
    test('la misma serie desde TMDB y TVMaze no se duplica', () async {
      final app = await _appConUsuario();
      await app.alternarFavorito(_fav('tmdb', 1, 'Breaking Bad'));
      expect(
        app.esFavorito('tvmaze', 'serie', 169, titulo: 'breaking bad '),
        isTrue,
      );
      // Pulsar el corazón en la versión de TVMaze la quita, no la duplica
      await app.alternarFavorito(_fav('tvmaze', 169, 'Breaking Bad'));
      expect(app.favoritos, isEmpty);
    });

    test('importar no duplica y guarda todo', () async {
      final app = await _appConUsuario();
      await app.alternarFavorito(_fav('tmdb', 1, 'Breaking Bad'));
      final nota = NotaModel.nueva(titulo: 'Dark', ultimaVista: 'T1 E3');
      await app.importar(
        [
          _fav('tmdb', 1, 'Breaking Bad'),
          _fav('tvmaze', 169, 'Breaking Bad'), // misma serie desde TVMaze
          _fav('tvmaze', 2, 'Dark'),
        ],
        [_fav('tvmaze', 2, 'Dark')],
        [nota, nota],
      );
      expect(app.favoritos.map((f) => f.titulo), ['Breaking Bad', 'Dark']);
      expect(app.vistos, hasLength(1));
      expect(app.notas, hasLength(1));
      final guardados = await AlmacenamientoService.cargarUsuarios();
      expect(guardados.single.favoritos, hasLength(2));
    });
  });

  group('Almacenamiento', () {
    test('el PIN solo admite 4 dígitos', () {
      expect(AlmacenamientoService.pinValido('0123'), isTrue);
      for (final malo in ['123', '12345', '+123', '-123', ' 123', '12a4']) {
        expect(AlmacenamientoService.pinValido(malo), isFalse, reason: malo);
      }
    });

    test(
      'datos corruptos: falla en vez de sobrescribir a los usuarios',
      () async {
        const corrupto = '[{"id": "u1"}]'; // usuario sin nombre ni PIN
        SharedPreferences.setMockInitialValues({'usuarios': corrupto});
        await expectLater(
          AlmacenamientoService.cargarUsuarios(),
          throwsA(anything),
        );
        await expectLater(
          AlmacenamientoService.agregarUsuario(
            const UsuarioModel(id: 'u2', nombre: 'Nuevo', pinHash: 'x'),
          ),
          throwsA(anything),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('usuarios'), corrupto); // intacto
      },
    );
  });
}

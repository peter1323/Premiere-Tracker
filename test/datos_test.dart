// TESTS de la lógica con más riesgo de perder o estropear datos:
// leer copias de seguridad, no duplicar obras entre TMDB y TVMaze,
// importar sin duplicar, validar el PIN y no borrar usuarios si los datos
// guardados están corruptos. Se ejecutan con `flutter test`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:premiere_tracker/controllers/app_controller.dart';
import 'package:premiere_tracker/controllers/avisos_controller.dart';
import 'package:premiere_tracker/controllers/calendario_controller.dart';
import 'package:premiere_tracker/controllers/lista_guardada_controller.dart';
import 'package:premiere_tracker/models/favorito_model.dart';
import 'package:premiere_tracker/models/nota_model.dart';
import 'package:premiere_tracker/models/serie_model.dart';
import 'package:premiere_tracker/models/usuario_model.dart';
import 'package:premiere_tracker/services/almacenamiento_service.dart';
import 'package:premiere_tracker/services/avisos_service.dart';
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

  group('Estrenos', () {
    test('dónde verlo: plataformas de España sin repetir, o null', () {
      Map<String, dynamic> netflix(int id) => {
        'provider_id': id,
        'provider_name': 'Netflix',
        'logo_path': '/n.png',
      };
      final dondeVer = TmdbRefs.dondeVerDe({
        'results': {
          'US': {
            'flatrate': [netflix(99)],
          },
          'ES': {
            'link': 'https://tmdb/watch',
            'flatrate': [netflix(8)],
            'ads': [netflix(8)], // la misma: no se repite
            'buy': [netflix(10)], // compra: no se muestra
          },
        },
      });
      expect(dondeVer?.enlace, 'https://tmdb/watch');
      expect(dondeVer?.plataformas.single.logo, endsWith('/w92/n.png'));
      expect(TmdbRefs.dondeVerDe({'results': {}}), isNull);
      expect(TmdbRefs.dondeVerDe(null), isNull);
    });

    test('los estrenos se ordenan por día y hora (sin hora al final)', () {
      EntradaCalendario e(String dia, String hora) => EntradaCalendario(
        tipo: 'serie',
        fuente: 'tvmaze',
        id: 1,
        titulo: '$dia $hora',
        hora: hora,
        claveDia: dia,
      );
      final lista = [
        e('2026-10-26', '09:00'),
        e('2026-10-25', ''),
        e('2026-10-25', '23:00'),
      ]..sort(compararEstrenos);
      expect(lista.map((x) => x.titulo), [
        '2026-10-25 23:00',
        '2026-10-25 ',
        '2026-10-26 09:00',
      ]);
    });
  });

  group('Estados, notas y personas', () {
    test('datos antiguos sin estado ni nota cargan con null; '
        'los nuevos se guardan y valores inválidos se ignoran', () {
      final antiguo = FavoritoModel.fromJson(
        _fav('tmdb', 1, 'Dark').toJson()
          ..remove('estado')
          ..remove('puntuacion'),
      );
      expect(antiguo.estado, isNull);
      expect(antiguo.puntuacion, isNull);
      final valorado = _fav(
        'tmdb',
        1,
        'Dark',
      ).conValoracion(estado: 'enEspera', puntuacion: 8);
      final ida = FavoritoModel.fromJson(valorado.toJson());
      expect((ida.estado, ida.puntuacion), ('enEspera', 8));
      final raro = FavoritoModel.fromJson(
        valorado.toJson()
          ..['estado'] = 'inventado'
          ..['puntuacion'] = 99,
      );
      expect((raro.estado, raro.puntuacion), (null, null));
    });

    test('la copia de seguridad conserva estados, notas y personas', () {
      final persona = FavoritoModel(
        tipo: 'persona',
        fuente: 'tmdb',
        id: 17419,
        titulo: 'Bryan Cranston',
      );
      final r = CopiaSeguridadService.leerCopia(
        jsonEncode({
          'favoritos': [
            _fav(
              'tmdb',
              1,
              'Dark',
            ).conValoracion(estado: 'planeado', puntuacion: 9).toJson(),
            persona.toJson(),
          ],
        }),
      );
      expect(r.favoritos.first.estado, 'planeado');
      expect(r.favoritos.first.puntuacion, 9);
      expect(r.favoritos.last.tipo, 'persona');
    });

    test('el estado (de la base de datos) y la nota se guardan en Favoritos '
        'y Vistos a la vez, y se heredan al marcar como visto', () async {
      final app = await _appConUsuario();
      final dark = _fav('tmdb', 1, 'Dark');
      await app.alternarFavorito(dark);
      await app.actualizarDesdeFicha(dark, estado: 'enEmision');
      await app.cambiarNota(dark, 7);
      await app.alternarVisto(dark); // hereda estado y nota de Favoritos
      expect(app.vistos.single.estado, 'enEmision');
      expect(app.vistos.single.puntuacion, 7);
      await app.actualizarDesdeFicha(dark, estado: 'finalizado');
      await app.cambiarNota(dark, null);
      expect(app.favoritos.single.estado, 'finalizado');
      expect(app.vistos.single.puntuacion, isNull);
      expect(app.guardado('tmdb', 'serie', 1, 'Dark')?.estado, 'finalizado');
    });

    test('la fecha de una película es la de España (sin festivales); si no '
        'la hay, la principal', () {
      Map<String, dynamic> pais(String iso, List<(String, int)> fechas) => {
        'iso_3166_1': iso,
        'release_dates': [
          for (final (fecha, tipo) in fechas)
            {'release_date': '${fecha}T00:00:00.000Z', 'type': tipo},
        ],
      };
      final json = {
        'release_date': '2026-10-19',
        'release_dates': {
          'results': [
            pais('US', [('2026-10-19', 3)]),
            pais('ES', [
              ('2026-12-01', 4),
              ('2026-10-23', 3),
              ('2026-09-05', 1),
            ]),
          ],
        },
      };
      expect(TmdbRefs.fechaEstrenoEnRegion(json), '2026-10-23');
      expect(
        TmdbRefs.fechaEstrenoEnRegion({'release_date': '2026-10-19'}),
        '2026-10-19',
      );
    });

    test('el estado de la base de datos se traduce al de la app', () {
      expect(
        FavoritoModel.estadoDeApi(SerieModel.estadoEnEmision),
        'enEmision',
      );
      expect(FavoritoModel.estadoDeApi('parado'), 'enEspera'); // manga
      expect(
        FavoritoModel.estadoDeApi(SerieModel.estadoCancelada),
        'abandonado',
      );
      expect(FavoritoModel.estadoDeApi(SerieModel.estadoPlaneada), 'planeado');
      expect(FavoritoModel.estadoDeApi('lanzada'), 'finalizado'); // película
      expect(FavoritoModel.estadoDeApi(SerieModel.estadoDesconocida), isNull);
    });

    test('en Personas no hay filtro de estado y se ordena por nombre', () {
      FavoritoModel persona(int id, String nombre) => FavoritoModel(
        tipo: 'persona',
        fuente: 'tmdb',
        id: id,
        titulo: nombre,
      );
      final control = ListaGuardadaController()
        ..sincronizar([persona(1, 'Zendaya'), persona(2, 'aaron Paul')])
        ..cambiarOrden('nota') // no existe en Personas: vuelve a "añadido"
        ..cambiarFiltroEstado('planeado') // se ignora en Personas
        ..cambiarFiltro('persona');
      expect(control.orden, 'anadido');
      expect(control.filtrados.length, 2);
      control.cambiarOrden('az');
      expect(control.filtrados.map((f) => f.titulo), ['aaron Paul', 'Zendaya']);
      control.cambiarOrden('za');
      expect(control.filtrados.first.titulo, 'Zendaya');
    });

    test('la lista filtra por estado y ordena por nota', () {
      final control = ListaGuardadaController()
        ..sincronizar([
          _fav('tmdb', 1, 'A').conValoracion(estado: 'planeado', puntuacion: 5),
          _fav('tmdb', 2, 'B'),
          _fav('tmdb', 3, 'C').conValoracion(estado: null, puntuacion: 9),
        ]);
      control.cambiarFiltroEstado('sin');
      expect(control.filtrados.map((f) => f.titulo), ['B', 'C']);
      control
        ..cambiarFiltroEstado('todos')
        ..cambiarOrden('nota');
      expect(control.filtrados.map((f) => f.titulo), ['C', 'A', 'B']);
    });
  });

  group('Cuenta atrás y avisos', () {
    test('días hasta el estreno: hoy 0, futuro N, pasado o sin fecha null', () {
      final hoy = DateTime(2026, 10, 22, 23, 30);
      expect(diasParaEstreno('2026-10-22', hoy), 0);
      expect(diasParaEstreno('2026-10-25', hoy), 3);
      expect(diasParaEstreno('2026-10-21', hoy), isNull);
      expect(diasParaEstreno('', hoy), isNull);
    });

    test('se avisa de los favoritos y de lo planeado o en emisión', () {
      final dark = _fav('tmdb', 1, 'Dark');
      final avisables = AvisosController.avisables(
        [dark],
        [
          dark.conValoracion(estado: 'planeado', puntuacion: null), // repetida
          _fav(
            'tmdb',
            2,
            'B',
          ).conValoracion(estado: 'enEmision', puntuacion: null),
          _fav(
            'tmdb',
            3,
            'C',
          ).conValoracion(estado: 'abandonado', puntuacion: null),
        ],
      );
      expect(avisables.map((f) => f.titulo), ['Dark', 'B']);
    });

    test('solo los estrenos de hoy y una sola vez', () {
      EntradaCalendario e(String dia) => EntradaCalendario(
        tipo: 'serie',
        fuente: 'tvmaze',
        id: 1,
        titulo: 'Beerus',
        etiqueta: 'T1E4',
        claveDia: dia,
      );
      final hoy = e('2026-10-25');
      expect(
        AvisosService.pendientes([hoy, e('2026-10-26')], {}, '2026-10-25'),
        [hoy],
      );
      expect(
        AvisosService.pendientes(
          [hoy],
          {AvisosService.claveAviso(hoy)},
          '2026-10-25',
        ),
        isEmpty,
      );
      expect(
        AvisosService.textoAviso(hoy, 'es'),
        'Hoy sale el episodio T1E4 de Beerus',
      );
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

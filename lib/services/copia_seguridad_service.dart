// SERVICIO de copia de seguridad. Exporta los favoritos, vistos y notas
// de un usuario a un archivo .json que el usuario elige (con file_picker),
// y los importa de vuelta en otro equipo. Es genérico sobre
// List<FavoritoModel>, así que los mangas se exportan e importan sin tocar
// nada (mismo formato que las series y películas). No dibuja nada.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/favorito_model.dart';
import '../models/nota_model.dart';

/// Resultado de intentar importar una copia de seguridad.
class ResultadoImportacion {
  final bool cancelado; // el usuario cerró el diálogo
  final bool valido; // el archivo era un .json correcto
  final List<FavoritoModel> favoritos;
  final List<FavoritoModel> vistos; // vacío en copias antiguas
  final List<NotaModel> notas; // vacío en copias antiguas

  const ResultadoImportacion({
    required this.cancelado,
    required this.valido,
    this.favoritos = const [],
    this.vistos = const [],
    this.notas = const [],
  });
}

/// Exporta e importa los favoritos, vistos y notas de un usuario a un
/// archivo .json en el propio equipo (sin servidor).
class CopiaSeguridadService {
  /// Exporta favoritos, vistos y notas a un .json elegido por el
  /// usuario. Devuelve false si se canceló el diálogo.
  static Future<bool> exportarFavoritos(
      String nombreUsuario,
      List<FavoritoModel> favoritos,
      List<FavoritoModel> vistos,
      List<NotaModel> notas) async {
    final destino = await FilePicker.platform.saveFile(
      dialogTitle: 'Premiere Tracker',
      fileName: 'premiere_tracker_favoritos.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (destino == null) return false; // el usuario canceló

    final datos = {
      'app': 'Premiere Tracker',
      'version': 1,
      'usuario': nombreUsuario,
      'exportado': DateTime.now().toIso8601String(),
      'favoritos': favoritos.map((f) => f.toJson()).toList(),
      'vistos': vistos.map((f) => f.toJson()).toList(),
      'notas': notas.map((n) => n.toJson()).toList(),
    };
    final texto = const JsonEncoder.withIndent('  ').convert(datos);
    await File(destino).writeAsString(texto);
    return true;
  }

  /// Importa favoritos desde un .json. El archivo se valida antes de nada:
  /// si no es un JSON correcto de Premiere Tracker, se marca como inválido.
  static Future<ResultadoImportacion> importarFavoritos() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (resultado == null || resultado.files.isEmpty) {
      return const ResultadoImportacion(cancelado: true, valido: false);
    }
    final ruta = resultado.files.first.path;
    if (ruta == null || ruta.isEmpty) {
      return const ResultadoImportacion(cancelado: true, valido: false);
    }

    String texto;
    try {
      texto = await File(ruta).readAsString();
    } catch (_) {
      return const ResultadoImportacion(cancelado: false, valido: false);
    }

    try {
      final datos = jsonDecode(texto);
      if (datos is! Map<String, dynamic>) {
        return const ResultadoImportacion(cancelado: false, valido: false);
      }
      final lista = datos['favoritos'];
      if (lista is! List) {
        return const ResultadoImportacion(cancelado: false, valido: false);
      }
      // Cada entrada se valida por separada; las corruptas se ignoran
      final favoritos = <FavoritoModel>[];
      for (final item in lista) {
        try {
          favoritos.add(FavoritoModel.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // entrada corrupta: se ignora
        }
      }
      // Vistos: campo nuevo, opcional (las copias antiguas no lo traen)
      final vistos = <FavoritoModel>[];
      final listaVistos = datos['vistos'];
      if (listaVistos is List) {
        for (final item in listaVistos) {
          try {
            vistos.add(FavoritoModel.fromJson(item as Map<String, dynamic>));
          } catch (_) {
            // entrada corrupta: se ignora
          }
        }
      }
      // Notas: campo nuevo, opcional (las copias antiguas no lo traen)
      final notas = <NotaModel>[];
      final listaNotas = datos['notas'];
      if (listaNotas is List) {
        for (final item in listaNotas) {
          try {
            notas.add(NotaModel.fromJson(item as Map<String, dynamic>));
          } catch (_) {
            // entrada corrupta: se ignora
          }
        }
      }
      // Si había entradas pero ninguna es válida, el archivo no sirve
      if (lista.isNotEmpty && favoritos.isEmpty) {
        return const ResultadoImportacion(cancelado: false, valido: false);
      }
      return ResultadoImportacion(
        cancelado: false,
        valido: true,
        favoritos: favoritos,
        vistos: vistos,
        notas: notas,
      );
    } catch (_) {
      // JSON incorrecto
      return const ResultadoImportacion(cancelado: false, valido: false);
    }
  }
}

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

    // En móvil no se puede elegir una ruta arbitraria: se pasan los bytes
    // al sistema y él guarda el archivo. En escritorio el diálogo devuelve
    // la ruta y se escribe aquí. null = el usuario canceló.
    final esMovil = Platform.isAndroid || Platform.isIOS;
    final destino = await FilePicker.platform.saveFile(
      dialogTitle: 'Premiere Tracker',
      fileName: 'premiere_tracker_favoritos.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: esMovil ? utf8.encode(texto) : null,
    );
    if (destino == null) return false;
    if (!esMovil) await File(destino).writeAsString(texto);
    return true;
  }

  /// Lee una lista de la copia: cada entrada se valida por separado y las
  /// corruptas se ignoran. Si el campo no existe (copias antiguas sin
  /// vistos ni notas), lista vacía.
  static List<T> _leerLista<T>(
      Object? lista, T Function(Map<String, dynamic>) desdeJson) {
    final salida = <T>[];
    if (lista is! List) return salida;
    for (final item in lista) {
      try {
        salida.add(desdeJson(item as Map<String, dynamic>));
      } catch (_) {
        // entrada corrupta: se ignora
      }
    }
    return salida;
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
    return leerCopia(texto);
  }

  /// Interpreta el texto de una copia (separado del diálogo de archivos
  /// para poder probarlo en los tests).
  static ResultadoImportacion leerCopia(String texto) {
    try {
      final datos = jsonDecode(texto);
      if (datos is! Map<String, dynamic>) {
        return const ResultadoImportacion(cancelado: false, valido: false);
      }
      final lista = datos['favoritos'];
      if (lista is! List) {
        return const ResultadoImportacion(cancelado: false, valido: false);
      }
      final favoritos = _leerLista(lista, FavoritoModel.fromJson);
      final vistos = _leerLista(datos['vistos'], FavoritoModel.fromJson);
      final notas = _leerLista(datos['notas'], NotaModel.fromJson);
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

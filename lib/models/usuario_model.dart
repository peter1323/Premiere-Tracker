import 'favorito_model.dart';
import 'nota_model.dart';

/// Datos de un usuario local de la app.
class UsuarioModel {
  final String id;
  final String nombre;
  final String pinHash; // SHA-256 en hexadecimal, nunca el PIN en texto plano
  final String tema; // 'claro' u 'oscuro'
  final String idioma; // 'es' o 'en'
  final List<FavoritoModel> favoritos;
  final List<FavoritoModel> vistos; // marcados como vistos (mismo modelo)
  final List<NotaModel> notas; // notas personales del usuario

  const UsuarioModel({
    required this.id,
    required this.nombre,
    required this.pinHash,
    this.tema = 'claro',
    this.idioma = 'es',
    this.favoritos = const [],
    this.vistos = const [],
    this.notas = const [],
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      pinHash: json['pinHash'] as String,
      tema: json['tema'] as String? ?? 'claro',
      idioma: json['idioma'] as String? ?? 'es',
      favoritos: (json['favoritos'] as List<dynamic>? ?? [])
          .map((f) => FavoritoModel.fromJson(f as Map<String, dynamic>))
          .toList(),
      vistos: (json['vistos'] as List<dynamic>? ?? [])
          .map((f) => FavoritoModel.fromJson(f as Map<String, dynamic>))
          .toList(),
      notas: (json['notas'] as List<dynamic>? ?? [])
          .map((n) => NotaModel.fromJson(n as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'pinHash': pinHash,
        'tema': tema,
        'idioma': idioma,
        'favoritos': favoritos.map((f) => f.toJson()).toList(),
        'vistos': vistos.map((f) => f.toJson()).toList(),
        'notas': notas.map((n) => n.toJson()).toList(),
      };

  UsuarioModel copyWith({
    String? nombre,
    String? pinHash,
    String? tema,
    String? idioma,
    List<FavoritoModel>? favoritos,
    List<FavoritoModel>? vistos,
    List<NotaModel>? notas,
  }) {
    return UsuarioModel(
      id: id,
      nombre: nombre ?? this.nombre,
      pinHash: pinHash ?? this.pinHash,
      tema: tema ?? this.tema,
      idioma: idioma ?? this.idioma,
      favoritos: favoritos ?? this.favoritos,
      vistos: vistos ?? this.vistos,
      notas: notas ?? this.notas,
    );
  }
}

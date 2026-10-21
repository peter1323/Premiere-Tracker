// UTILIDAD de los servicios de APIs: caché en memoria que guarda la
// PETICIÓN (el Future), no solo la respuesta. Así, si dos pantallas piden
// lo mismo a la vez (p. ej. el Calendario y Próximamente al entrar), se
// hace una sola petición a internet y las dos esperan la misma respuesta.
// Si la petición falla, no se guarda: la próxima vez se reintenta.

/// Caché de peticiones por clave (p. ej. 'episodios-169').
class CacheFuturos {
  final Map<String, Future<Object?>> _peticiones = {};

  /// Devuelve la petición de [clave] si ya existe (terminada o en curso);
  /// si no, la lanza con [pedir] y la guarda.
  Future<T> obtener<T>(String clave, Future<T> Function() pedir) {
    final existente = _peticiones[clave];
    if (existente != null) return existente.then((valor) => valor as T);
    final peticion = pedir();
    _peticiones[clave] = peticion;
    // Un error no se queda en caché (se olvida y se reintenta otro día)
    peticion.then(
      (_) {},
      onError: (_) {
        _peticiones.remove(clave);
      },
    );
    return peticion;
  }
}

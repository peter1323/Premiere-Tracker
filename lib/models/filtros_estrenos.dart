// MODELO de los filtros de la pantalla Estrenos (próximos estrenos de
// series y películas de TMDB, no solo los favoritos). Hay uno para series
// y otro para películas: comparten fechas y disponibilidad, y cada uno usa
// además lo suyo (tipos de estreno y países en películas; todos los
// episodios o solo series nuevas en series). Solo datos, sin red.

/// Tipos de disponibilidad de TMDB (with_watch_monetization_types), en el
/// orden de la pantalla de filtros.
const List<String> disponibilidades = [
  'flatrate',
  'free',
  'ads',
  'rent',
  'buy',
];

/// Tipos de estreno de películas de TMDB (with_release_type), en el orden
/// de la pantalla de filtros: en cines (limitado), en cines, estreno,
/// digital, físico y TV.
const List<int> tiposEstreno = [2, 3, 1, 4, 5, 6];

/// Filtros de un tipo (series o películas) de la pantalla Estrenos.
class FiltrosEstrenos {
  final DateTime desde;
  final DateTime hasta;
  // true: cualquier disponibilidad (no se filtra); false: solo [monetizacion]
  final bool todasDisponibilidades;
  final Set<String> monetizacion; // de [disponibilidades]
  // Películas: true = estrenos de cualquier país; false = solo de España
  final bool todosPaises;
  final Set<int> tipos; // de [tiposEstreno] (solo películas)
  // Series: true = cualquier episodio en las fechas; false = solo series
  // que empiezan (su primer episodio cae en las fechas)
  final bool todosEpisodios;

  const FiltrosEstrenos({
    required this.desde,
    required this.hasta,
    this.todasDisponibilidades = true,
    this.monetizacion = const {'flatrate', 'free', 'rent', 'buy'},
    this.todosPaises = false,
    this.tipos = const {3, 1, 4},
    this.todosEpisodios = true,
  });

  /// Los de por defecto (como la web de TMDB): de hoy a 30 días vista y,
  /// en series, solo lo que se puede ver en España (retransmisión, gratis,
  /// alquiler o compra); en películas, cualquier disponibilidad.
  factory FiltrosEstrenos.inicial({required bool esSerie}) {
    final hoy = DateTime.now();
    return FiltrosEstrenos(
      desde: DateTime(hoy.year, hoy.month, hoy.day),
      hasta: DateTime(hoy.year, hoy.month, hoy.day + 30),
      todasDisponibilidades: !esSerie,
    );
  }

  /// Los mismos filtros sin días pasados: si "desde" quedó antes de hoy
  /// (la app siguió abierta de un día para otro), empieza hoy.
  FiltrosEstrenos get desdeHoy {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    if (!desde.isBefore(hoy)) return this;
    return copyWith(desde: hoy, hasta: hasta.isBefore(hoy) ? hoy : null);
  }

  FiltrosEstrenos copyWith({
    DateTime? desde,
    DateTime? hasta,
    bool? todasDisponibilidades,
    Set<String>? monetizacion,
    bool? todosPaises,
    Set<int>? tipos,
    bool? todosEpisodios,
  }) => FiltrosEstrenos(
    desde: desde ?? this.desde,
    hasta: hasta ?? this.hasta,
    todasDisponibilidades: todasDisponibilidades ?? this.todasDisponibilidades,
    monetizacion: monetizacion ?? this.monetizacion,
    todosPaises: todosPaises ?? this.todosPaises,
    tipos: tipos ?? this.tipos,
    todosEpisodios: todosEpisodios ?? this.todosEpisodios,
  );
}

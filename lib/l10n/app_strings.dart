/// Textos de la app por idioma.
/// Ningún texto se escribe directamente en las vistas: todo pasa por [t].
const Map<String, Map<String, String>> cadenas = {
  'es': {
    // General
    'appName': 'Premiere Tracker',
    'error': 'Error',
    'aceptar': 'Aceptar',
    'cancelar': 'Cancelar',
    'cerrar': 'Cerrar',
    'guardar': 'Guardar',
    'volver': 'Volver',

    // Usuarios
    'usuarios': 'Usuarios',
    'crearUsuario': 'Crear usuario',
    'nombreUsuario': 'Nombre de usuario',
    'pin': 'PIN',
    'pin4digitos': 'El PIN debe tener 4 dígitos',
    'pinSoloNumeros': 'El PIN solo puede contener números',
    'escribePin': 'Escribe tu PIN',
    'pinIncorrecto': 'PIN incorrecto',
    'pinPista': 'Tu PIN empieza por',
    'nombreRequerido': 'El nombre es obligatorio',
    'entrar': 'Entrar',
    'sinUsuarios': 'Aún no hay usuarios. Crea el primero.',
    'usuarioCreado': 'Usuario creado',
    'errorAlmacenamiento':
        'No se pueden leer o guardar los datos en este dispositivo',
    'reintentar': 'Reintentar',

    // Menú lateral y barra superior
    'inicio': 'Inicio',
    'favoritos': 'Favoritos',
    'vistos': 'Vistos',
    'notas': 'Notas',
    'ajustes': 'Ajustes',
    'cambiarTema': 'Cambiar entre modo claro y oscuro',
    'cambiarUsuario': 'Cambiar de usuario',
    'cerrarApp': 'Cerrar app',
    'tema': 'Tema',
    'modoClaro': 'Claro',
    'modoOscuro': 'Oscuro',
    'idioma': 'Idioma',
    'espanol': 'Español',
    'ingles': 'English',

    // Inicio: buscador y resultados
    'buscarHint': 'Buscar series, películas o personas...',
    // En Favoritos solo hay series y películas, así que sin personas
    'buscarFavoritosHint': 'Buscar series y películas...',
    'buscar': 'Buscar',
    'series': 'Series',
    'peliculas': 'Películas',
    'personas': 'Personas',
    'sinResultados': 'No se han encontrado resultados',
    'mangas': 'Lectura',
    'mangasAyuda': 'Busca mangas, manhwas, manhuas y novelas: ficha, estado y últimos capítulos',
    'buscarMangas': 'Título del manga, manhwa, manhua o novela',
    'buscarMangasVacio': 'Escribe un título para buscar',
    'pestanaManga': 'Manga / Manhwa / Manhua',
    'pestanaNovelas': 'Novelas',
    'errorBuscarMangas':
        'No se ha podido buscar en AniList. Comprueba tu conexión.',
    'capitulos': 'Capítulos',
    'tomos': 'Tomos',
    'formato': 'Formato',
    'pais': 'País',
    'fechaInicio': 'Inicio',
    'capitulo': 'Capítulo',
    'ultimoCapitulo': 'Último capítulo por idioma',
    'buscandoCapitulo': 'Buscando los últimos capítulos…',
    'esEspana': 'Español (España)',
    'esLatino': 'Español (Latino)',
    'idiomaIngles': 'Inglés',
    'sinDatosIdioma': 'No hay datos en ese idioma',
    'verEnAniList': 'Ver en AniList',
    'verEnMangaDex': 'Ver en MangaDex',
    'anadirLeidos': 'Marcar como leído',
    'quitarLeidos': 'Quitar de leídos',
    'errorCargarManga': 'No se ha podido cargar la ficha del manga',
    'inicioVacio': 'Busca series, películas o personas para empezar',
    'anadirFavoritos': 'Añadir a favoritos',
    'quitarFavoritos': 'Quitar de favoritos',
    'anadirVistos': 'Añadir a vistos',
    'quitarVistos': 'Quitar de vistos',

    // Notas
    'anadirNota': 'Añadir nota',
    'editarNota': 'Editar nota',
    'eliminarNota': 'Eliminar nota',
    'titulo': 'Título',
    'ultimaVista': 'Última vista',
    'masDatos': 'Más datos',
    'notaHintTitulo': 'Título (p. ej. Dragon Ball)',
    'notaHintTemporada': 'Última vista (p. ej. T4 E2)',
    'notaHintMasDatos': 'Más datos (opcional)',
    'sinNotas': 'No tienes notas todavía',
    'tituloRequerido': 'Escribe el título',
    'buscarNotasHint': 'Buscar en tus notas...',

    // Avisos de API
    'sinConexion': 'Sin conexión o servicios no disponibles',
    'avisoTvmaze': 'TVMaze no está disponible, mostrando datos de TMDB',
    'avisoTmdb': 'TMDB no está disponible, mostrando datos de TVMaze',
    'avisoTmdbKey': 'Falta la API key de TMDB o es incorrecta. Ve a la pantalla de usuarios para configurarla.',

    // Calendario
    'calendario': 'Calendario',
    'hoy': 'Hoy',
    'dia': 'Día',
    'semana': 'Semana',
    'mes': 'Mes',
    'anio': 'Año',
    'noHayEstrenos': 'No hay estrenos en este periodo',
    'sinEstrenos': 'Sin estrenos',
    'cantEstreno': 'estreno',
    'cantEstrenos': 'estrenos',
    'lunesCorto': 'Lun',
    'martesCorto': 'Mar',
    'miercolesCorto': 'Mié',
    'juevesCorto': 'Jue',
    'viernesCorto': 'Vie',
    'sabadoCorto': 'Sáb',
    'domingoCorto': 'Dom',

    // Detalle
    'sinopsis': 'Sinopsis',
    'sinSinopsis': 'Sin sinopsis disponible.',
    'estreno': 'Estreno',
    'puntuacion': 'Puntuación',
    'generos': 'Géneros',
    'autores': 'Autores',
    'canales': 'Canales',
    'reparto': 'Reparto',
    'proximoEpisodio': 'Próximo episodio',
    'temporadas': 'Temporadas',
    'temporada': 'Temporada',
    'episodio': 'Episodio',
    'enEmision': 'En emisión',
    'finalizada': 'Finalizada',
    'cancelada': 'Cancelada',
    'enProduccion': 'En producción',
    'planeada': 'Planeada',
    'lanzada': 'Lanzada',
    'estadoDesconocido': 'Desconocido',
    'fuente': 'Fuente',
    'sinEpisodios': 'No hay episodios disponibles',
    'proximamente': 'Próximamente',
    'noEnTvmaze': 'Esta serie no está disponible en TVMaze',

    // Detalle de personas
    'conocidoPor': 'Conocido por',
    'biografia': 'Biografía',
    'sinBiografia': 'Sin biografía disponible.',
    'apareceEn': 'Aparece en',
    'sinCreditos': 'Sin filmografía disponible.',
    'nacido': 'Nacido',
    'fallecido': 'Fallecido',
    'lugarNacimiento': 'Lugar de nacimiento',
    'comoPersonaje': 'como',
    'verTmdb': 'Ver en TMDB',
    'verTvmaze': 'Ver en TVMaze',

    // Favoritos
    'todo': 'Todo',
    'sinFavoritos': 'No tienes favoritos todavía',
    'sinVistos': 'No tienes nada marcado como visto todavía',
    'sinCoincidencias': 'No hay coincidencias',

    // Ajustes
    'copiaSeguridad': 'Copia de seguridad',
    'exportarFavoritos': 'Exportar favoritos, vistos y notas',
    'importarFavoritos': 'Importar favoritos, vistos y notas',
    'exportadoOk': 'Favoritos, vistos y notas exportados correctamente',
    'importadoOk': 'Favoritos, vistos y notas importados correctamente',
    'archivoInvalido': 'El archivo no es válido',
    'errorImportar': 'No se pudo importar el archivo',
    'gestionUsuarios': 'Gestión de usuarios',
    'cambiarNombre': 'Cambiar nombre',
    'cambiarPin': 'Cambiar PIN',
    'pinActual': 'PIN actual',
    'nuevoPin': 'Nuevo PIN',
    'nombreCambiado': 'Nombre cambiado',
    'pinCambiado': 'PIN cambiado',
    'borrarUsuario': 'Borrar usuario',
    'borrarUsuarioConfirm':
        '¿Borrar este usuario? Se eliminarán todos sus datos.',
    'creditos': 'Créditos',
    'tmdbAviso': 'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    'tvmazeCredit': 'Datos de series proporcionados por TVMaze',

    // Clave TMDB (se configura en la pantalla de usuarios)
    'claveTmdb': 'Clave TMDB',
    'claveInsertar': 'Inserte aquí su clave TMDB',
    'claveGuardadaApp': 'Guardada en la app',
    'claveComprobando': 'Comprobando la clave…',
    'claveNoValida': 'La clave no es válida, revísala',
    'claveVacia': 'Escribe una clave',
    'modificarClave': 'Modificar clave',
    'obtenerClave': 'Obtener clave',
  },
  'en': {
    // General
    'appName': 'Premiere Tracker',
    'error': 'Error',
    'aceptar': 'OK',
    'cancelar': 'Cancel',
    'cerrar': 'Close',
    'guardar': 'Save',
    'volver': 'Back',

    // Users
    'usuarios': 'Users',
    'crearUsuario': 'Create user',
    'nombreUsuario': 'User name',
    'pin': 'PIN',
    'pin4digitos': 'The PIN must have 4 digits',
    'pinSoloNumeros': 'The PIN can only contain numbers',
    'escribePin': 'Enter your PIN',
    'pinIncorrecto': 'Incorrect PIN',
    'pinPista': 'Your PIN starts with',
    'nombreRequerido': 'The name is required',
    'entrar': 'Enter',
    'sinUsuarios': 'No users yet. Create the first one.',
    'usuarioCreado': 'User created',
    'errorAlmacenamiento': 'Data cannot be read or saved on this device',
    'reintentar': 'Try again',

    // Side menu and top bar
    'inicio': 'Home',
    'favoritos': 'Favorites',
    'vistos': 'Watched',
    'notas': 'Notes',
    'ajustes': 'Settings',
    'cambiarTema': 'Toggle light/dark mode',
    'cambiarUsuario': 'Switch user',
    'cerrarApp': 'Close app',
    'tema': 'Theme',
    'modoClaro': 'Light',
    'modoOscuro': 'Dark',
    'idioma': 'Language',
    'espanol': 'Español',
    'ingles': 'English',

    // Home: search and results
    'buscarHint': 'Search series, movies or people...',
    // Favorites only has series and movies, so no people
    'buscarFavoritosHint': 'Search series and movies...',
    'buscar': 'Search',
    'series': 'Series',
    'peliculas': 'Movies',
    'personas': 'People',
    'sinResultados': 'No results found',
    'mangas': 'Reading',
    'mangasAyuda':
        'Search manga, manhwa, manhua and novels: details, status and chapters',
    'buscarMangas': 'Manga, manhwa, manhua or novel title',
    'buscarMangasVacio': 'Type a title to search',
    'pestanaManga': 'Manga / Manhwa / Manhua',
    'pestanaNovelas': 'Novels',
    'errorBuscarMangas': 'Search on AniList failed. Check your connection.',
    'capitulos': 'Chapters',
    'tomos': 'Volumes',
    'formato': 'Format',
    'pais': 'Country',
    'fechaInicio': 'Started',
    'capitulo': 'Chapter',
    'ultimoCapitulo': 'Latest chapter per language',
    'buscandoCapitulo': 'Looking for the latest chapters…',
    'esEspana': 'Spanish (Spain)',
    'esLatino': 'Spanish (LatAm)',
    'idiomaIngles': 'English',
    'sinDatosIdioma': 'No data available in this language',
    'verEnAniList': 'View on AniList',
    'verEnMangaDex': 'View on MangaDex',
    'anadirLeidos': 'Mark as read',
    'quitarLeidos': 'Unmark as read',
    'errorCargarManga': 'Could not load the manga details',
    'inicioVacio': 'Search series, movies or people to get started',
    'anadirFavoritos': 'Add to favorites',
    'quitarFavoritos': 'Remove from favorites',
    'anadirVistos': 'Mark as watched',
    'quitarVistos': 'Remove from watched',

    // Notes
    'anadirNota': 'Add note',
    'editarNota': 'Edit note',
    'eliminarNota': 'Delete note',
    'titulo': 'Title',
    'ultimaVista': 'Last seen',
    'masDatos': 'More data',
    'notaHintTitulo': 'Title (e.g. Dragon Ball)',
    'notaHintTemporada': 'Last seen (e.g. S4 E2)',
    'notaHintMasDatos': 'More data (optional)',
    'sinNotas': 'You have no notes yet',
    'tituloRequerido': 'Enter the title',
    'buscarNotasHint': 'Search your notes...',

    // API warnings
    'sinConexion': 'No connection or services unavailable',
    'avisoTvmaze': 'TVMaze is unavailable, showing TMDB data',
    'avisoTmdb': 'TMDB is unavailable, showing TVMaze data',
    'avisoTmdbKey': 'The TMDB API key is missing or incorrect. Set it up on the users screen.',

    // Calendar
    'calendario': 'Calendar',
    'hoy': 'Today',
    'dia': 'Day',
    'semana': 'Week',
    'mes': 'Month',
    'anio': 'Year',
    'noHayEstrenos': 'No releases in this period',
    'sinEstrenos': 'No releases',
    'cantEstreno': 'release',
    'cantEstrenos': 'releases',
    'lunesCorto': 'Mon',
    'martesCorto': 'Tue',
    'miercolesCorto': 'Wed',
    'juevesCorto': 'Thu',
    'viernesCorto': 'Fri',
    'sabadoCorto': 'Sat',
    'domingoCorto': 'Sun',

    // Details
    'sinopsis': 'Overview',
    'sinSinopsis': 'No overview available.',
    'estreno': 'Release date',
    'puntuacion': 'Rating',
    'generos': 'Genres',
    'autores': 'Authors',
    'canales': 'Networks',
    'reparto': 'Cast',
    'proximoEpisodio': 'Next episode',
    'temporadas': 'Seasons',
    'temporada': 'Season',
    'episodio': 'Episode',
    'enEmision': 'Airing',
    'finalizada': 'Ended',
    'cancelada': 'Canceled',
    'enProduccion': 'In production',
    'planeada': 'Planned',
    'lanzada': 'Released',
    'estadoDesconocido': 'Unknown',
    'fuente': 'Source',
    'sinEpisodios': 'No episodes available',
    'proximamente': 'Coming soon',
    'noEnTvmaze': 'This show is not available on TVMaze',

    // People details
    'conocidoPor': 'Known for',
    'biografia': 'Biography',
    'sinBiografia': 'No biography available.',
    'apareceEn': 'Appears in',
    'sinCreditos': 'No filmography available.',
    'nacido': 'Born',
    'fallecido': 'Died',
    'lugarNacimiento': 'Place of birth',
    'comoPersonaje': 'as',
    'verTmdb': 'View on TMDB',
    'verTvmaze': 'View on TVMaze',

    // Favorites
    'todo': 'All',
    'sinFavoritos': 'You have no favorites yet',
    'sinVistos': 'You have nothing marked as watched yet',
    'sinCoincidencias': 'No matches',

    // Settings
    'copiaSeguridad': 'Backup',
    'exportarFavoritos': 'Export favorites, watched and notes',
    'importarFavoritos': 'Import favorites, watched and notes',
    'exportadoOk': 'Favorites, watched and notes exported successfully',
    'importadoOk': 'Favorites, watched and notes imported successfully',
    'archivoInvalido': 'The file is not valid',
    'errorImportar': 'Could not import the file',
    'gestionUsuarios': 'User management',
    'cambiarNombre': 'Change name',
    'cambiarPin': 'Change PIN',
    'pinActual': 'Current PIN',
    'nuevoPin': 'New PIN',
    'nombreCambiado': 'Name changed',
    'pinCambiado': 'PIN changed',
    'borrarUsuario': 'Delete user',
    'borrarUsuarioConfirm': 'Delete this user? All their data will be removed.',
    'creditos': 'Credits',
    'tmdbAviso': 'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    'tvmazeCredit': 'Series data provided by TVMaze',

    // TMDB API key (set up on the users screen)
    'claveTmdb': 'TMDB API key',
    'claveInsertar': 'Insert your TMDB API key here',
    'claveGuardadaApp': 'Saved in the app',
    'claveComprobando': 'Verifying the key…',
    'claveNoValida': 'The key is not valid, check it',
    'claveVacia': 'Enter a key',
    'modificarClave': 'Change key',
    'obtenerClave': 'Get key',
  },
};

/// Idioma de la app ('es' o 'en') en el formato que piden las APIs
/// (TMDB): 'es-ES' o 'en-US'. Único sitio con esta regla.
String idiomaApi(String idioma) => idioma == 'es' ? 'es-ES' : 'en-US';

/// Devuelve el texto de [clave] en el [idioma].
/// Si falta, usa el español; y si tampoco está, devuelve la propia clave.
String t(String clave, String idioma) {
  return cadenas[idioma]?[clave] ?? cadenas['es']?[clave] ?? clave;
}

/// Géneros en inglés (TVMaze siempre, TMDB en inglés) traducidos al español.
const Map<String, String> generosEnEspanol = {
  'Action': 'Acción',
  'Adventure': 'Aventura',
  'Animation': 'Animación',
  'Comedy': 'Comedia',
  'Crime': 'Crimen',
  'Documentary': 'Documental',
  'Drama': 'Drama',
  'Family': 'Familia',
  'Fantasy': 'Fantasía',
  'History': 'Historia',
  'Horror': 'Terror',
  'Kids': 'Infantil',
  'Music': 'Música',
  'Mystery': 'Misterio',
  'Reality': 'Telerrealidad',
  'Romance': 'Romance',
  'Sci-Fi': 'Ciencia ficción',
  'Science Fiction': 'Ciencia ficción',
  'Sports': 'Deportes',
  'Supernatural': 'Sobrenatural',
  'Thriller': 'Suspense',
  'War': 'Bélico',
  'Western': 'Western',
  // Variantes compuestas que usa TMDB
  'Action & Adventure': 'Acción y aventura',
  'Sci-Fi & Fantasy': 'Ciencia ficción y fantasía',
  'War & Politics': 'Guerra y política',
};

/// Traduce un género al español si procede (en inglés se queda tal cual).
String traducirGenero(String genero, String idioma) {
  if (idioma != 'es') return genero;
  return generosEnEspanol[genero] ?? genero;
}

/// Departamentos de personas en inglés (TMDB los da en inglés aunque se
/// pida español) traducidos al español.
const Map<String, String> departamentosEnEspanol = {
  'Acting': 'Actuación',
  'Directing': 'Dirección',
  'Writing': 'Guion',
  'Production': 'Producción',
  'Creator': 'Creación',
  'Camera': 'Cámara',
  'Editing': 'Montaje',
  'Sound': 'Sonido',
  'Art': 'Arte',
  'Costume & Make Up': 'Vestuario y maquillaje',
  'Visual Effects': 'Efectos visuales',
  'Crew': 'Equipo',
  'Lighting': 'Iluminación',
};

/// Traduce un departamento de persona al español si procede.
String traducirDepartamento(String departamento, String idioma) {
  if (idioma != 'es') return departamento;
  return departamentosEnEspanol[departamento] ?? departamento;
}

/// Nombres de los meses (el índice 0 es enero).
const List<String> mesesEs = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const List<String> mesesEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Nombre del mes (1-12) en el idioma indicado.
String nombreMes(int mes, String idioma) {
  final lista = idioma == 'en' ? mesesEn : mesesEs;
  return lista[mes < 1 || mes > 12 ? 0 : mes - 1];
}

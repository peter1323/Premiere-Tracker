// WIDGET del calendario de estrenos. Dibuja las vistas de día, semana y
// mes con el paquete calendar_view, adaptando los colores al tema claro u
// oscuro de la app. Lo usa calendario_view.dart y le pasa las entradas ya
// calculadas por CalendarioController (solo series y películas).
import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/calendario_controller.dart';
import '../../l10n/app_strings.dart';

/// Calendario de estrenos con vistas de día, semana, mes y año (las
/// tres primeras con el paquete calendar_view; año es propia). Incluye
/// pestañas Series | Películas, botón "Hoy" y flechas de navegación.
class CalendarioFavoritos extends StatefulWidget {
  final Map<String, List<EntradaCalendario>> seriesPorDia;
  final Map<String, List<EntradaCalendario>> peliculasPorDia;
  final bool cargando;
  final String pestana; // 'series' o 'peliculas'
  final String modo; // 'dia', 'semana' o 'mes'
  final DateTime fechaVisible;
  final String? aviso; // clave de traducción o null
  final String idioma;
  final ValueChanged<DateTime> onFecha; // la vista cambió de periodo
  final VoidCallback onHoy;
  final ValueChanged<String> onModo;
  final ValueChanged<String> onPestana;
  final ValueChanged<EntradaCalendario> onAbrirEntrada;

  const CalendarioFavoritos({
    super.key,
    required this.seriesPorDia,
    required this.peliculasPorDia,
    required this.cargando,
    required this.pestana,
    required this.modo,
    required this.fechaVisible,
    required this.aviso,
    required this.idioma,
    required this.onFecha,
    required this.onHoy,
    required this.onModo,
    required this.onPestana,
    required this.onAbrirEntrada,
  });

  @override
  State<CalendarioFavoritos> createState() => _CalendarioFavoritosState();
}

class _CalendarioFavoritosState extends State<CalendarioFavoritos>
    with SingleTickerProviderStateMixin {
  // Los paquetes no limitan el rango: aquí se acota a 2 años atrás y 6
  // adelante (los datos se cargan por periodo visible, sin precargar).
  static final DateTime _limiteInferior = DateTime(
    DateTime.now().year - 2,
    1,
    1,
  );
  static final DateTime _limiteSuperior = DateTime(
    DateTime.now().year + 6,
    12,
    31,
  );

  static const List<String> _diasCortos = [
    'lunesCorto',
    'martesCorto',
    'miercolesCorto',
    'juevesCorto',
    'viernesCorto',
    'sabadoCorto',
    'domingoCorto',
  ];

  late final TabController _pestanas = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.pestana == 'series' ? 0 : 1,
  );

  // Eventos del paquete: se recrean cuando cambian datos, pestaña o tema.
  EventController<EntradaCalendario>? _eventos;
  String _firmaEventos = '';

  final _claveDia = GlobalKey<DayViewState<EntradaCalendario>>();
  final _claveSemana = GlobalKey<WeekViewState<EntradaCalendario>>();

  @override
  void initState() {
    super.initState();
    _pestanas.addListener(_alCambiarPestana);
  }

  void _alCambiarPestana() {
    if (_pestanas.indexIsChanging) return;
    final pestana = _pestanas.index == 0 ? 'series' : 'peliculas';
    if (pestana != widget.pestana) widget.onPestana(pestana);
  }

  @override
  void dispose() {
    _pestanas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Localización del paquete: días, "Más" y números según el idioma.
    PackageStrings.setLocale(widget.idioma);

    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    // Los eventos se regeneran solo si cambian los datos, la pestaña
    // o el tema (los colores dependen del esquema).
    final firma =
        '${widget.pestana}|${widget.seriesPorDia.hashCode}|'
        '${widget.peliculasPorDia.hashCode}|${esquema.brightness}';
    if (_firmaEventos != firma) {
      _firmaEventos = firma;
      _eventos = EventController<EntradaCalendario>()
        ..addAll(_crearEventos(esquema));
    }

    final entradas = widget.pestana == 'series'
        ? widget.seriesPorDia
        : widget.peliculasPorDia;
    final hayEntradas = entradas.values.any((lista) => lista.isNotEmpty);

    // Cabecera compartida: título + modos, pestañas y aviso opcional.
    final cabecera = <Widget>[
      // Título + selector Día | Semana | Mes + botón Hoy. En anchos
      // estrechos (móvil vertical) el selector va solo con iconos y en
      // su propia fila para no salirse por el borde ni perder "Hoy".
      LayoutBuilder(
        builder: (context, medidasCaja) {
          final estrecho = medidasCaja.maxWidth < 600;
          final segmentos = <ButtonSegment<String>>[
            ButtonSegment(
              value: 'dia',
              icon: const Icon(Icons.view_day_outlined),
              label: estrecho ? null : Text(t('dia', widget.idioma)),
            ),
            ButtonSegment(
              value: 'semana',
              icon: const Icon(Icons.view_week_outlined),
              label: estrecho ? null : Text(t('semana', widget.idioma)),
            ),
            ButtonSegment(
              value: 'mes',
              icon: const Icon(Icons.calendar_month_outlined),
              label: estrecho ? null : Text(t('mes', widget.idioma)),
            ),
            ButtonSegment(
              value: 'anio',
              icon: const Icon(Icons.grid_view_outlined),
              label: estrecho ? null : Text(t('anio', widget.idioma)),
            ),
          ];
          final selector = SegmentedButton<String>(
            segments: segmentos,
            selected: {widget.modo},
            onSelectionChanged: (seleccion) => widget.onModo(seleccion.first),
          );
          // Fondo morado (primario) para que destaque y se encuentre
          // rápido, igual que la cabecera de las vistas del calendario.
          final hoy = FilledButton.icon(
            onPressed: _irAHoy,
            icon: const Icon(Icons.today),
            label: Text(t('hoy', widget.idioma)),
          );
          final titulo = Text(
            t('calendario', widget.idioma),
            style: tema.textTheme.titleMedium,
          );
          if (!estrecho) {
            return Row(
              children: [
                titulo,
                const Spacer(),
                selector,
                const SizedBox(width: 8),
                hoy,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [titulo, const Spacer(), hoy]),
              const SizedBox(height: 8),
              selector,
            ],
          );
        },
      ),
      const SizedBox(height: 4),

      // Pestañas Series | Películas
      TabBar(
        controller: _pestanas,
        tabs: [
          Tab(text: t('series', widget.idioma)),
          Tab(text: t('peliculas', widget.idioma)),
        ],
      ),

      // Aviso si TVMaze no estuvo disponible
      if (widget.aviso != null) ...[
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: esquema.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 16,
                color: esquema.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t(widget.aviso!, widget.idioma),
                  style: TextStyle(
                    fontSize: 12,
                    color: esquema.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 6),
    ];

    // En alturas bajas (móvil horizontal) la página entera se desplaza y
    // la vista del calendario queda con una altura mínima para seguir
    // utilizable; en alturas normales ocupa el resto (igual que siempre).
    // El contenido se construye dentro porque en Año necesita saber si
    // la página scrollea (su rejilla entonces no lleva scroll propio).
    return LayoutBuilder(
      builder: (context, medidas) {
        final paginaScrollea = medidas.maxHeight < 360;
        // Vista del calendario (día, semana, mes o año)
        final contenido = Stack(
          children: [
            _vista(paginaScrollea: paginaScrollea),
            if (widget.cargando)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (!widget.cargando && !hayEntradas && widget.modo != 'anio')
              IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: esquema.surfaceContainerHighest.withValues(
                        alpha: 0.92,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(t('noHayEstrenos', widget.idioma)),
                  ),
                ),
              ),
          ],
        );
        if (paginaScrollea) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...cabecera,
                // El Año lleva su altura natural: su rejilla no scrollea
                // sola y la página se encarga de subir y bajar.
                if (widget.modo == 'anio' || _listaEnMovil)
                  contenido
                else
                  SizedBox(height: 340, child: contenido),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...cabecera,
            Expanded(child: contenido),
          ],
        );
      },
    );
  }

  /// Construye la vista del paquete según el modo activo.
  /// [paginaScrollea] indica si la página entera se desplaza (móvil
  /// horizontal); solo lo usa la vista de año.
  Widget _vista({required bool paginaScrollea}) {
    // Android: Día y Semana como lista por días (la rejilla de 24 horas no
    // cabe y las horas salían aplastadas). Windows sigue con la rejilla.
    if (_listaEnMovil) return _vistaLista(paginaScrollea: paginaScrollea);
    switch (widget.modo) {
      case 'dia':
        // LayoutBuilder: la densidad se calcula para que las 24 horas
        // llenen el alto disponible (sin scroll ni saltos al cambiar).
        return LayoutBuilder(
          builder: (context, caja) {
            return _anchoEntero(
              caja,
              (ancho) => DayView<EntradaCalendario>(
                width: ancho,
                key: _claveDia,
                controller: _eventos,
                initialDay: widget.fechaVisible,
                minDay: _limiteInferior,
                maxDay: _limiteSuperior,
                heightPerMinute: _densidad(caja.maxHeight, _altoCabeceraDia),
                // Sin scroll interno: las 24 h ya caben exactas y así el
                // deslizamiento vertical mueve la página (la cabecera de la
                // app nunca queda inaccesible).
                scrollPhysics: const NeverScrollableScrollPhysics(),
                onPageChange: (fecha, pagina) => widget.onFecha(fecha),
                onEventTap: _abrirEventos,
                eventTileBuilder: _tileHora,
                dateStringBuilder: _tituloDia,
                // La navegación ya es con las flechas y el botón "Hoy":
                // sin esto, al pinchar el título se abría el showDatePicker
                // del paquete (pantalla gris que tapaba el calendario).
                onHeaderTitleTap: (_) async {},
              ),
            );
          },
        );
      case 'mes':
        // Vista de mes propia: el MonthView del paquete dimensionaba las
        // celdas con el ancho de la ventana (no el del calendario), salía
        // gris y no llenaba el alto (cambiaba el tamaño al volver).
        return _vistaMes();
      case 'anio':
        // Vista de año propia: los 12 meses con el número de estrenos de
        // cada uno; al pulsar un mes se entra en su vista de mes.
        return _vistaAnio(paginaScrollea: paginaScrollea);
      case 'semana':
      default:
        return LayoutBuilder(
          builder: (context, caja) {
            return _anchoEntero(
              caja,
              (ancho) => WeekView<EntradaCalendario>(
                width: ancho,
                key: _claveSemana,
                controller: _eventos,
                initialDay: widget.fechaVisible,
                minDay: _limiteInferior,
                maxDay: _limiteSuperior,
                heightPerMinute: _densidad(caja.maxHeight, _altoCabeceraSemana),
                // Igual que en Día: sin scroll interno para que la página
                // siempre pueda subir hasta la cabecera de la app.
                scrollPhysics: const NeverScrollableScrollPhysics(),
                onPageChange: (fecha, pagina) => widget.onFecha(fecha),
                onEventTap: _abrirEventos,
                eventTileBuilder: _tileHora,
                headerStringBuilder: _tituloSemana,
                // Sin columna de número de semana (ocupaba una columna entera)
                weekNumberBuilder: (_) => const SizedBox.shrink(),
                // Igual que en Día: el clic en el título no abre el
                // showDatePicker del paquete; se navega con las flechas.
                onHeaderTitleTap: (_) async {},
              ),
            );
          },
        );
    }
  }

  // Alturas fijas de la cabecera interna de calendar_view 2.0.0 (la barra
  // morada con las flechas mide 48 px; la semana añade la fila de días de
  // la semana, de 50 + divisor y borde). Se descuentan del alto para que
  // las 24 horas quepan exactas y no sobre scroll interno.
  static const double _altoCabeceraDia = 48;
  static const double _altoCabeceraSemana = 101;

  /// Densidad de píxeles por minuto para que las 24 horas (1440 min)
  /// llenen el alto disponible sin scroll ni huecos.
  double _densidad(double alto, double ocupado) {
    final horas = alto - ocupado;
    if (!horas.isFinite || horas <= 0) return 0.4;
    return horas / 1440;
  }

  /// Convierte los datos del controlador en eventos del paquete.
  /// Las entradas sin hora ("HH:mm") se muestran como día completo.
  List<CalendarEventData<EntradaCalendario>> _crearEventos(
    ColorScheme esquema,
  ) {
    final color = widget.pestana == 'series'
        ? esquema.primary
        : esquema.tertiary;
    final porDia = widget.pestana == 'series'
        ? widget.seriesPorDia
        : widget.peliculasPorDia;

    final eventos = <CalendarEventData<EntradaCalendario>>[];
    for (final entrada in porDia.values.expand((lista) => lista)) {
      final fecha = DateTime.parse(entrada.claveDia);
      final hora = _horaDe(fecha, entrada.hora);
      // Redondeo a la hora para que el tile de hora ocupe una hora
      // entera (un estreno a las 23:40 no se quedaría en una línea).
      final inicio = hora == null
          ? null
          : DateTime(fecha.year, fecha.month, fecha.day, hora.hour);
      // Fin a la hora siguiente sin cruzar de día (23:00 termina 23:59).
      final fin = inicio == null
          ? null
          : (inicio.hour == 23
                ? DateTime(fecha.year, fecha.month, fecha.day, 23, 59)
                : DateTime(
                    inicio.year,
                    inicio.month,
                    inicio.day,
                    inicio.hour + 1,
                  ));
      final titulo = entrada.etiqueta.isNotEmpty
          ? '${entrada.etiqueta} · ${entrada.titulo}'
          : entrada.titulo;

      eventos.add(
        CalendarEventData<EntradaCalendario>(
          title: titulo,
          date: fecha,
          event: entrada,
          color: color,
          startTime: inicio,
          endTime: fin,
        ),
      );
    }
    return eventos;
  }

  /// Convierte "HH:mm" en un DateTime del propio día (null si no hay hora).
  DateTime? _horaDe(DateTime fecha, String hora) {
    if (hora.length < 4) return null;
    final partes = hora.split(':');
    final h = int.tryParse(partes[0]);
    final m = partes.length > 1 ? int.tryParse(partes[1]) : null;
    if (h == null || m == null) return null;
    return DateTime(fecha.year, fecha.month, fecha.day, h, m);
  }

  /// Día y Semana del paquete calendar_view pasan página a página con un
  /// PageView: con un ancho con decimales (p. ej. 687,33 px en un móvil en
  /// horizontal) el cálculo de páginas no sale exacto y Flutter da error en
  /// modo depuración. Se usa el ancho redondeado hacia abajo (pierde < 1 px).
  Widget _anchoEntero(
    BoxConstraints caja,
    Widget Function(double ancho) vista,
  ) {
    final ancho = caja.maxWidth.floorToDouble();
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: ancho,
        height: caja.maxHeight,
        child: vista(ancho),
      ),
    );
  }

  /// true en Android con Día o Semana: se usa la lista por días.
  bool get _listaEnMovil =>
      defaultTargetPlatform == TargetPlatform.android &&
      (widget.modo == 'dia' || widget.modo == 'semana');

  /// Día y Semana en Android: barra morada con flechas y, debajo, la lista
  /// de estrenos de cada día (el día visible, o los 7 de la semana), con
  /// su hora si la hay. Con [paginaScrollea] (horizontal) la lista va a su
  /// altura natural y es la página la que se desliza.
  Widget _vistaLista({required bool paginaScrollea}) {
    final esquema = Theme.of(context).colorScheme;
    final esSemana = widget.modo == 'semana';
    final inicio = widget.fechaVisible;
    final dias = [
      for (var i = 0; i < (esSemana ? 7 : 1); i++)
        DateTime(inicio.year, inicio.month, inicio.day + i),
    ];
    final paso = esSemana ? 7 : 1;
    final anterior = DateTime(inicio.year, inicio.month, inicio.day - paso);
    final siguiente = DateTime(inicio.year, inicio.month, inicio.day + paso);
    final colorEvento = widget.pestana == 'series'
        ? esquema.primary
        : esquema.tertiary;
    final porDia = widget.pestana == 'series'
        ? widget.seriesPorDia
        : widget.peliculasPorDia;
    final hoy = _claveDe(DateTime.now());

    final filas = <Widget>[
      for (final dia in dias) ...[
        // En Semana, cabecera de cada día ("Lun 19/10/2026"); hoy resaltado
        if (esSemana)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              _tituloDia(dia),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _claveDe(dia) == hoy
                    ? esquema.primary
                    : esquema.onSurface,
              ),
            ),
          ),
        for (final e in _entradasOrdenadas(porDia[_claveDe(dia)]))
          _filaEntrada(e, colorEvento),
        if ((porDia[_claveDe(dia)] ?? const []).isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              t('sinEstrenos', widget.idioma),
              style: TextStyle(color: esquema.outline),
            ),
          ),
      ],
      const SizedBox(height: 8),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra morada con flechas, igual que la del mes
        Container(
          color: esquema.primary,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: anterior.isBefore(_limiteInferior)
                    ? null
                    : () => widget.onFecha(anterior),
                icon: Icon(Icons.chevron_left, color: esquema.onPrimary),
              ),
              Expanded(
                child: Text(
                  esSemana ? _tituloSemana(inicio) : _tituloDia(inicio),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: esquema.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: siguiente.isAfter(_limiteSuperior)
                    ? null
                    : () => widget.onFecha(siguiente),
                icon: Icon(Icons.chevron_right, color: esquema.onPrimary),
              ),
            ],
          ),
        ),
        if (paginaScrollea)
          ...filas
        else
          Expanded(child: ListView(children: filas)),
      ],
    );
  }

  /// Entradas de un día ordenadas por hora (las que no tienen, al final).
  List<EntradaCalendario> _entradasOrdenadas(List<EntradaCalendario>? lista) {
    final copia = [...?lista];
    copia.sort((a, b) {
      if (a.hora.isEmpty != b.hora.isEmpty) return a.hora.isEmpty ? 1 : -1;
      return a.hora.compareTo(b.hora);
    });
    return copia;
  }

  /// Fila de un estreno en la lista: hora (si la hay) y "T1E3 · Título".
  /// Al pulsarla se abre su ficha.
  Widget _filaEntrada(EntradaCalendario entrada, Color color) {
    final colorTexto = _textoClaro(color) ? Colors.white : Colors.black87;
    final titulo = entrada.etiqueta.isNotEmpty
        ? '${entrada.etiqueta} · ${entrada.titulo}'
        : entrada.titulo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onAbrirEntrada(entrada),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (entrada.hora.isNotEmpty) ...[
                  Text(
                    entrada.hora,
                    style: TextStyle(
                      color: colorTexto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorTexto),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Vista de mes propia (widgets propios, sin el paquete): cabecera con
  /// flechas, fila de días y cuadrícula que llena exactamente el alto
  /// disponible, con número de día, "hoy" destacado y chips de estrenos.
  Widget _vistaMes() {
    final esquema = Theme.of(context).colorScheme;
    final fecha = widget.fechaVisible;
    final colorEvento = widget.pestana == 'series'
        ? esquema.primary
        : esquema.tertiary;
    final hoy = DateTime.now();

    // Entradas del mes actual indexadas por "yyyy-MM-dd"
    final porDia = <String, List<EntradaCalendario>>{};
    final origenes = widget.pestana == 'series'
        ? widget.seriesPorDia
        : widget.peliculasPorDia;
    for (final lista in origenes.values) {
      for (final entrada in lista) {
        (porDia[_claveDe(DateTime.parse(entrada.claveDia))] ??= []).add(
          entrada,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con flechas, con el mismo estilo que día y semana.
        // El título abre un selector de mes/año para saltar sin tantos
        // clics (p. ej. de septiembre 2026 a febrero 2027).
        Container(
          color: esquema.primary,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: _mesEnMin ? () => _mesA(-1) : null,
                icon: Icon(Icons.chevron_left, color: esquema.onPrimary),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _abrirSelectorMes,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _tituloMes(fecha),
                        style: TextStyle(
                          color: esquema.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: esquema.onPrimary),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _mesEnMax ? () => _mesA(1) : null,
                icon: Icon(Icons.chevron_right, color: esquema.onPrimary),
              ),
              const Spacer(),
            ],
          ),
        ),
        // Fila con los días de la semana
        Container(
          color: esquema.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              for (final dia in _diasCortos)
                Expanded(
                  child: Center(
                    child: Text(
                      t(dia, widget.idioma),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: esquema.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Cuadrícula: 35 o 42 casillas que ocupan el alto restante exacto
        Expanded(
          child: LayoutBuilder(
            builder: (context, caja) {
              final primero = _lunesDe(fecha);
              final ultimoDelMes = DateTime(fecha.year, fecha.month + 1, 0);
              // Suma de días con el constructor (no Duration): al cruzar el
              // cambio de hora, Duration adelantaba las celdas una hora y
              // algún día se repetía (p. ej. el domingo 25 de octubre).
              final fin = DateTime(
                ultimoDelMes.year,
                ultimoDelMes.month,
                ultimoDelMes.day + (7 - ultimoDelMes.weekday),
              );
              // Diferencia en días de calendario (UTC evita el cambio de hora)
              final totalDias =
                  DateTime.utc(fin.year, fin.month, fin.day)
                      .difference(
                        DateTime.utc(primero.year, primero.month, primero.day),
                      )
                      .inDays +
                  1;
              final filas = totalDias ~/ 7;
              final altoCelda = caja.maxHeight / filas;
              final anchoCelda = caja.maxWidth / 7;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: anchoCelda / altoCelda,
                ),
                itemCount: totalDias,
                itemBuilder: (context, indice) {
                  // Día de calendario (Duration cruzaría el cambio de hora)
                  final dia = DateTime(
                    primero.year,
                    primero.month,
                    primero.day + indice,
                  );
                  final enElMes = dia.month == fecha.month;
                  final esHoy =
                      dia.year == hoy.year &&
                      dia.month == hoy.month &&
                      dia.day == hoy.day;
                  final lista = porDia[_claveDe(dia)] ?? const [];
                  return GestureDetector(
                    onTap: () {
                      // Un toque en el día abre la vista de día
                      widget.onModo('dia');
                      widget.onFecha(dia);
                    },
                    child: _contenidoCeldaMes(
                      dia,
                      lista,
                      esHoy,
                      enElMes,
                      colorEvento,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Vista de año: los 12 meses con su número de estrenos; el mes
  /// actual se resalta con un borde y al pulsar un mes se entra en su
  /// vista de mes. Las flechas cambian de año dentro del rango.
  Widget _vistaAnio({required bool paginaScrollea}) {
    final esquema = Theme.of(context).colorScheme;
    final anio = widget.fechaVisible.year;
    final hoy = DateTime.now();

    // Estrenos del año en la pestaña activa (Series | Películas)
    final entradas = widget.pestana == 'series'
        ? widget.seriesPorDia
        : widget.peliculasPorDia;

    // Rejilla con los 12 meses del año
    final rejilla = LayoutBuilder(
      builder: (context, caja) {
        // En móvil vertical, 2 columnas para que cada mes quepa
        // completo (nombre y estrenos sin solaparse); en pantallas
        // más anchas, igual que siempre.
        final estrecho = caja.maxWidth < 600;
        final columnas = estrecho
            ? 2
            : (caja.maxWidth / 220).floor().clamp(3, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: estrecho ? 2.2 : 2.8,
          ),
          // En móvil horizontal la página scrollea: la rejilla no debe
          // tener scroll propio (igual que la vista de mes) para no
          // robar los gestos y dejar la cabecera inaccesible.
          physics: paginaScrollea ? const NeverScrollableScrollPhysics() : null,
          shrinkWrap: paginaScrollea,
          itemCount: 12,
          itemBuilder: (context, indice) {
            final mes = indice + 1;
            final esMesActual = anio == hoy.year && mes == hoy.month;
            final total = _estrenosDelMes(entradas, anio, mes);
            return _tarjetaMesAnio(mes, total, esMesActual, esquema);
          },
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con el año y flechas, con el estilo de las demás
        Container(
          color: esquema.primary,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: anio > _limiteInferior.year
                    ? () => widget.onFecha(DateTime(anio - 1, 1, 1))
                    : null,
                icon: Icon(Icons.chevron_left, color: esquema.onPrimary),
              ),
              Text(
                '$anio',
                style: TextStyle(
                  color: esquema.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: anio < _limiteSuperior.year
                    ? () => widget.onFecha(DateTime(anio + 1, 1, 1))
                    : null,
                icon: Icon(Icons.chevron_right, color: esquema.onPrimary),
              ),
              const Spacer(),
            ],
          ),
        ),
        // Con página scrolleable la rejilla lleva su altura natural
        // (la página hace de scroll); si no, ocupa el resto.
        if (paginaScrollea) rejilla else Expanded(child: rejilla),
      ],
    );
  }

  /// Número de estrenos de un mes sumando los días "yyyy-MM-dd".
  int _estrenosDelMes(
    Map<String, List<EntradaCalendario>> entradas,
    int anio,
    int mes,
  ) {
    final prefijo = '$anio-${mes.toString().padLeft(2, '0')}';
    var total = 0;
    for (final dia in entradas.entries) {
      if (dia.key.startsWith(prefijo)) total += dia.value.length;
    }
    return total;
  }

  /// Tarjeta de un mes en la vista de año: nombre, número de estrenos
  /// (o "Sin estrenos") y borde si es el mes actual; al pulsarla se
  /// entra en la vista de mes de ese mes.
  Widget _tarjetaMesAnio(
    int mes,
    int total,
    bool esMesActual,
    ColorScheme esquema,
  ) {
    final anio = widget.fechaVisible.year;
    return Material(
      color: esquema.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          widget.onModo('mes');
          widget.onFecha(DateTime(anio, mes, 1));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: esMesActual ? esquema.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                nombreMes(mes, widget.idioma),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: esquema.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                total == 0
                    ? t('sinEstrenos', widget.idioma)
                    : '$total '
                          '${t(total == 1 ? 'cantEstreno' : 'cantEstrenos', widget.idioma)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: total == 0 ? esquema.outline : esquema.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Celda del mes: número de día (círculo si es hoy) y sus estrenos
  /// como chips de color, con los colores de la app.
  Widget _contenidoCeldaMes(
    DateTime dia,
    List<EntradaCalendario> lista,
    bool esHoy,
    bool enElMes,
    Color colorEvento,
  ) {
    final esquema = Theme.of(context).colorScheme;
    final colorTexto = esquema.onSurface.withAlpha(enElMes ? 255 : 130);
    return Container(
      color: enElMes
          ? esquema.surface
          : esquema.surfaceContainerLow.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(3),
      // Celdas bajas (móvil en horizontal): lo que no cabe se recorta por
      // abajo en vez de desbordarse; no se desliza.
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: esHoy ? esquema.primary : null,
              ),
              child: Text(
                dia.day.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: esHoy ? esquema.onPrimary : colorTexto,
                ),
              ),
            ),
            const SizedBox(height: 2),
            for (final entrada in lista.take(3)) _chipDe(entrada, colorEvento),
            if (lista.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text(
                  '+${lista.length - 3}',
                  style: TextStyle(fontSize: 11, color: colorTexto),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Chip de un estreno dentro de la celda del mes.
  Widget _chipDe(EntradaCalendario entrada, Color color) {
    final titulo = entrada.etiqueta.isNotEmpty
        ? '${entrada.etiqueta} · ${entrada.titulo}'
        : entrada.titulo;
    return GestureDetector(
      onTap: () => widget.onAbrirEntrada(entrada),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          titulo,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 11,
            color: _textoClaro(color) ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  /// true si el mes visible no es el primero del rango (flecha ‹ activa).
  bool get _mesEnMin => DateTime(
    widget.fechaVisible.year,
    widget.fechaVisible.month,
  ).isAfter(DateTime(_limiteInferior.year, _limiteInferior.month));

  /// true si el mes visible no es el último del rango (flecha › activa).
  bool get _mesEnMax => DateTime(
    widget.fechaVisible.year,
    widget.fechaVisible.month,
  ).isBefore(DateTime(_limiteSuperior.year, _limiteSuperior.month));

  /// Cambia de mes respecto al visible (+1 adelante, -1 atrás),
  /// sin salirse del rango permitido del calendario.
  void _mesA(int delta) {
    final fecha = widget.fechaVisible;
    final destino = DateTime(fecha.year, fecha.month + delta, 1);
    final min = DateTime(_limiteInferior.year, _limiteInferior.month, 1);
    final max = DateTime(_limiteSuperior.year, _limiteSuperior.month, 1);
    if (destino.isBefore(min) || destino.isAfter(max)) return;
    widget.onFecha(destino);
  }

  /// Abre el selector de mes/año al pulsar el título de la cabecera:
  /// permite ir directo a cualquier mes (p. ej. de septiembre 2026 a
  /// febrero 2027) sin clicar la flecha muchas veces.
  void _abrirSelectorMes() {
    showDialog<void>(
      context: context,
      builder: (_) => _SelectorMes(
        fechaInicial: widget.fechaVisible,
        idioma: widget.idioma,
        anioMin: _limiteInferior.year,
        anioMax: _limiteSuperior.year,
        onSeleccion: (fecha) => widget.onFecha(fecha),
      ),
    );
  }

  /// Lunes de la semana que contiene el día 1 del mes dado.
  DateTime _lunesDe(DateTime fecha) {
    final primero = DateTime(fecha.year, fecha.month, 1);
    return DateTime(
      primero.year,
      primero.month,
      primero.day - (primero.weekday - 1),
    );
  }

  /// Clave "yyyy-MM-dd" para indexar las entradas por día.
  String _claveDe(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';

  /// Tile de una hora en las vistas de día y semana: barra de color
  /// con el título del estreno (el del paquete salía sin texto).
  Widget _tileHora(
    DateTime fecha,
    List<CalendarEventData<EntradaCalendario>> eventos,
    Rect borde,
    DateTime inicio,
    DateTime fin,
  ) {
    if (eventos.isEmpty) return const SizedBox.shrink();
    final evento = eventos.first;
    final entrada = evento.event;
    return GestureDetector(
      onTap: () {
        if (entrada != null) widget.onAbrirEntrada(entrada);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: evento.color,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          evento.title,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _textoClaro(evento.color) ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  /// true si sobre [color] conviene texto blanco (color oscuro).
  bool _textoClaro(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark;

  /// Botón "Hoy": vuelve el controlador y la vista al día de hoy.
  void _irAHoy() {
    widget.onHoy();
    final hoy = DateTime.now();
    switch (widget.modo) {
      case 'dia':
        _claveDia.currentState?.jumpToDate(hoy);
      case 'semana':
        _claveSemana.currentState?.jumpToWeek(hoy);
      case 'mes':
        // La vista de mes propia se actualiza sola con la fecha visible
        break;
      case 'anio':
        // La vista de año propia se actualiza sola con la fecha visible
        break;
    }
  }

  /// Toque sobre los eventos de una hora: si hay uno solo se abre;
  /// si hay varios, se elige en una lista.
  void _abrirEventos(
    List<CalendarEventData<EntradaCalendario>> eventos,
    DateTime fecha,
  ) {
    if (eventos.isEmpty) return;
    final primero = eventos.first.event;
    if (eventos.length == 1) {
      if (primero != null) widget.onAbrirEntrada(primero);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final evento in eventos)
              ListTile(
                leading: Icon(
                  evento.event?.tipo == 'pelicula' ? Icons.movie : Icons.tv,
                ),
                title: Text(evento.title),
                subtitle: evento.event?.hora.isNotEmpty == true
                    ? Text(evento.event!.hora)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  final entrada = evento.event;
                  if (entrada != null) widget.onAbrirEntrada(entrada);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Título de la cabecera del mes: "Octubre 2026".
  String _tituloMes(DateTime fecha) =>
      '${nombreMes(fecha.month, widget.idioma)} ${fecha.year}';

  /// Título de la cabecera de la semana: "12/10/2026 – 18/10/2026".
  String _tituloSemana(DateTime fecha, {DateTime? secondaryDate}) {
    final lunes = secondaryDate != null
        ? fecha
        : DateTime(fecha.year, fecha.month, fecha.day - (fecha.weekday - 1));
    final domingo =
        secondaryDate ?? DateTime(lunes.year, lunes.month, lunes.day + 6);
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(lunes.day)}/${d2(lunes.month)}/${lunes.year} – '
        '${d2(domingo.day)}/${d2(domingo.month)}/${domingo.year}';
  }

  /// Título de la cabecera del día: "Lun 12/10/2026".
  String _tituloDia(DateTime fecha, {DateTime? secondaryDate}) {
    final dia = t(_diasCortos[fecha.weekday - 1], widget.idioma);
    String d2(int n) => n.toString().padLeft(2, '0');
    return '$dia ${d2(fecha.day)}/${d2(fecha.month)}/${fecha.year}';
  }
}

/// Diálogo con los 12 meses del año para saltar directamente a un mes.
/// Flechas para cambiar de año (dentro del rango permitido del calendario)
/// y el mes visible resaltado con el color primario del tema.
class _SelectorMes extends StatefulWidget {
  final DateTime fechaInicial;
  final String idioma;
  final int anioMin;
  final int anioMax;
  final ValueChanged<DateTime> onSeleccion;

  const _SelectorMes({
    required this.fechaInicial,
    required this.idioma,
    required this.anioMin,
    required this.anioMax,
    required this.onSeleccion,
  });

  @override
  State<_SelectorMes> createState() => _SelectorMesState();
}

class _SelectorMesState extends State<_SelectorMes> {
  late int _anio = widget.fechaInicial.year;

  void _cambiarAnio(int delta) {
    final nuevo = _anio + delta;
    if (nuevo < widget.anioMin || nuevo > widget.anioMax) return;
    setState(() => _anio = nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      // Con el móvil en horizontal no cabe entero: se desliza
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila con el año y flechas para cambiarlo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _anio > widget.anioMin
                      ? () => _cambiarAnio(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$_anio',
                  style: tema.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: _anio < widget.anioMax
                      ? () => _cambiarAnio(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Los 12 meses del año en cuadrícula de 3 columnas
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [for (var mes = 1; mes <= 12; mes++) _botonMes(mes)],
            ),
          ],
        ),
      ),
    );
  }

  /// Casilla de un mes: resaltada si es el mes visible; al pulsarla se
  /// cierra el diálogo y se va directamente a ese mes.
  Widget _botonMes(int mes) {
    final esquema = Theme.of(context).colorScheme;
    final hoy = DateTime.now();
    final seleccionado =
        _anio == widget.fechaInicial.year && mes == widget.fechaInicial.month;
    final esMesActual = _anio == hoy.year && mes == hoy.month;

    return Material(
      color: seleccionado ? esquema.primary : esquema.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.pop(context);
          widget.onSeleccion(DateTime(_anio, mes, 1));
        },
        child: Center(
          child: Text(
            nombreMes(mes, widget.idioma),
            style: TextStyle(
              fontSize: 13,
              fontWeight: seleccionado || esMesActual
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: seleccionado ? esquema.onPrimary : esquema.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

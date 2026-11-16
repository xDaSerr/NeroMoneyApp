import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/widgets/boton_con_panel.dart';
import '../data/periodo_reporte.dart';

/// Primer año que se puede elegir (la app no existía antes).
const _primerAnio = 2020;
const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

DateTime _soloDia(DateTime f) => DateTime(f.year, f.month, f.day);
DateTime _lunes(DateTime f) =>
    DateTime(f.year, f.month, f.day - (f.weekday - 1));
bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
int _diasEntre(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// La fecha de Reportes como botón: al tocarla se estira hasta la ventana
/// "Elegir periodo" (misma animación que "Nuevo movimiento").
class BotonPeriodo extends StatelessWidget {
  const BotonPeriodo({
    super.key,
    required this.seleccion,
    required this.tipoBase,
    required this.onAplicar,
    required this.boton,
  });

  final SeleccionPeriodo seleccion;

  /// El tipo marcado en "Día | Semana | Mes | Año".
  final TipoPeriodo tipoBase;
  final ValueChanged<SeleccionPeriodo> onAplicar;
  final Widget Function(BuildContext context, VoidCallback abrir) boton;

  @override
  Widget build(BuildContext context) {
    return BotonConPanel(
      colorBoton: AppColors.surface2Glass,
      radioBoton: 14,
      tamanoPanel: const Size(830, 750),
      boton: boton,
      panel: (context, cerrar) => PanelPeriodo(
        actual: seleccion,
        tipoBase: tipoBase,
        onCerrar: cerrar,
        onAplicar: (s) {
          onAplicar(s);
          cerrar();
        },
      ),
    );
  }
}

/// "Elegir periodo": el tipo actual o un rango personalizado, accesos
/// rápidos, calendario y resumen. Nada se aplica hasta "Aplicar periodo".
class PanelPeriodo extends StatefulWidget {
  const PanelPeriodo({
    super.key,
    required this.actual,
    required this.tipoBase,
    required this.onAplicar,
    required this.onCerrar,
  });

  final SeleccionPeriodo actual;
  final TipoPeriodo tipoBase;
  final ValueChanged<SeleccionPeriodo> onAplicar;
  final VoidCallback onCerrar;

  @override
  State<PanelPeriodo> createState() => _PanelPeriodoState();
}

class _PanelPeriodoState extends State<PanelPeriodo> {
  final _hoy = _soloDia(DateTime.now());

  late TipoPeriodo _tipo = widget.tipoBase;
  late bool _enRango = widget.actual.esPersonalizado;
  late SeleccionPeriodo _pendiente = widget.actual.esPersonalizado
      ? SeleccionPeriodo(widget.tipoBase)
      : widget.actual;

  // Rango personalizado (ambos días incluidos).
  late DateTime? _desde = widget.actual.rango.desde;
  late DateTime? _hasta =
      _soloDia(widget.actual.rango.hasta.subtract(const Duration(days: 1)))
          .isAfter(_hoy)
      ? _hoy
      : _soloDia(widget.actual.rango.hasta.subtract(const Duration(days: 1)));
  bool _editandoHasta = false;

  /// Mes que se ve en el calendario (o año, en Mes/Año).
  late DateTime _mes = DateTime(
    widget.actual.rango.desde.year,
    widget.actual.rango.desde.month,
  );

  // --- Elegir ---

  void _accesoRapido(String cual) => setState(() {
    switch (cual) {
      case 'hoy':
        _tipo = TipoPeriodo.dia;
        _enRango = false;
        _pendiente = const SeleccionPeriodo(TipoPeriodo.dia);
      case 'semana':
        _tipo = TipoPeriodo.semana;
        _enRango = false;
        _pendiente = const SeleccionPeriodo(TipoPeriodo.semana);
      case 'mes':
        _tipo = TipoPeriodo.mes;
        _enRango = false;
        _pendiente = const SeleccionPeriodo(TipoPeriodo.mes);
      case '30':
        _enRango = true;
        _desde = _hoy.subtract(const Duration(days: 29));
        _hasta = _hoy;
        _editandoHasta = false;
    }
    _mes = DateTime(_hoy.year, _hoy.month);
  });

  String? get _accesoActivo {
    if (_enRango) {
      return _desde != null &&
              _hasta != null &&
              _mismoDia(_hasta!, _hoy) &&
              _diasEntre(_desde!, _hasta!) == 29
          ? '30'
          : null;
    }
    if (_pendiente.offset != 0) return null;
    return switch (_pendiente.tipo) {
      TipoPeriodo.dia => 'hoy',
      TipoPeriodo.semana => 'semana',
      TipoPeriodo.mes => 'mes',
      TipoPeriodo.anio => null,
    };
  }

  void _tocarDia(DateTime dia) => setState(() {
    if (_enRango) {
      if (!_editandoHasta || _desde == null) {
        _desde = dia;
        if (_hasta != null && _hasta!.isBefore(dia)) _hasta = null;
        _editandoHasta = true;
      } else if (dia.isBefore(_desde!)) {
        _desde = dia;
      } else {
        _hasta = dia;
      }
      return;
    }
    _pendiente = switch (_tipo) {
      TipoPeriodo.semana => SeleccionPeriodo(
        TipoPeriodo.semana,
        _diasEntre(_lunes(_hoy), _lunes(dia)) ~/ 7,
      ),
      _ => SeleccionPeriodo(TipoPeriodo.dia, _diasEntre(_hoy, dia)),
    };
  });

  void _aplicar() {
    if (_enRango) {
      if (_desde == null) return;
      widget.onAplicar(SeleccionPeriodo.rango(_desde!, _hasta ?? _desde!));
    } else {
      widget.onAplicar(_pendiente);
    }
  }

  // --- Textos ---

  (DateTime, DateTime) get _rangoPendiente {
    if (_enRango) {
      final d = _desde ?? _hoy;
      final h = _hasta ?? d;
      return (d, DateTime(h.year, h.month, h.day + 1));
    }
    final r = _pendiente.rango;
    return (r.desde, r.hasta);
  }

  /// "9–15 noviembre · 7 días".
  String get _resumen {
    final (d, hastaExcl) = _rangoPendiente;
    final h = hastaExcl.subtract(const Duration(days: 1));
    final dias = _diasEntre(d, hastaExcl);
    final anio = h.year == _hoy.year && d.year == _hoy.year ? '' : ' ${h.year}';
    final texto = dias == 1
        ? '${d.day} ${mesesEs[d.month - 1]}$anio'
        : d.month == h.month && d.year == h.year
        ? '${d.day}–${h.day} ${mesesEs[d.month - 1]}$anio'
        : '${d.day} ${mesesEs[d.month - 1].substring(0, 3)} – '
              '${h.day} ${mesesEs[h.month - 1].substring(0, 3)}$anio';
    return '$texto · $dias ${dias == 1 ? 'día' : 'días'}';
  }

  String? get _notaHoy {
    final (d, hastaExcl) = _rangoPendiente;
    if (_hoy.isBefore(d) || !_hoy.isBefore(hastaExcl)) return null;
    if (_diasEntre(d, hastaExcl) == 1) return null;
    return 'Datos registrados hasta hoy, ${_hoy.day} '
        '${mesesEs[_hoy.month - 1].substring(0, 3)}.';
  }

  String get _subtitulo => _enRango
      ? 'Elige una fecha de inicio y una fecha de fin.'
      : switch (_tipo) {
          TipoPeriodo.dia => 'Selecciona el día que quieres consultar.',
          TipoPeriodo.semana =>
            'Selecciona cualquier día de la semana que quieres consultar.',
          TipoPeriodo.mes => 'Selecciona el mes que quieres consultar.',
          TipoPeriodo.anio => 'Selecciona el año que quieres consultar.',
        };

  String get _nombreTipo => switch (_tipo) {
    TipoPeriodo.dia => 'Día',
    TipoPeriodo.semana => 'Semana',
    TipoPeriodo.mes => 'Mes',
    TipoPeriodo.anio => 'Año',
  };

  // --- Vista ---

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 700;
    final margen = angosto ? 18.0 : 26.0;

    final pestanas = _Pestanas(
      izquierda: _nombreTipo,
      enRango: _enRango,
      onCambiar: (rango) => setState(() {
        _enRango = rango;
        if (!rango) {
          _mes = DateTime(
            _pendiente.rango.desde.year,
            _pendiente.rango.desde.month,
          );
        }
      }),
    );

    final accesos = _AccesosRapidos(
      activo: _accesoActivo,
      compacto: angosto,
      onElegir: _accesoRapido,
    );

    final derecha = _enRango
        ? _calendario()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChipSeleccion(
                texto:
                    _pendiente.rango.etiqueta == 'Hoy' ||
                        _pendiente.rango.etiqueta == 'Ayer'
                    ? fechaCorta(_pendiente.rango.desde)
                    : _pendiente.rango.etiqueta,
                enCurso: _pendiente.rango.esActual
                    ? switch (_tipo) {
                        TipoPeriodo.dia => 'Hoy',
                        TipoPeriodo.semana => 'Semana en curso',
                        TipoPeriodo.mes => 'Mes en curso',
                        TipoPeriodo.anio => 'Año en curso',
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              switch (_tipo) {
                TipoPeriodo.dia || TipoPeriodo.semana => _calendario(),
                TipoPeriodo.mes => _Meses(
                  anio: _mes.year,
                  hoy: _hoy,
                  elegido: _pendiente.rango.desde,
                  onAnio: (a) => setState(() => _mes = DateTime(a)),
                  onMes: (m) => setState(
                    () => _pendiente = SeleccionPeriodo(
                      TipoPeriodo.mes,
                      (_mes.year - _hoy.year) * 12 + (m - _hoy.month),
                    ),
                  ),
                ),
                TipoPeriodo.anio => _Anios(
                  hoy: _hoy,
                  elegido: _pendiente.rango.desde.year,
                  onAnio: (a) => setState(
                    () => _pendiente = SeleccionPeriodo(
                      TipoPeriodo.anio,
                      a - _hoy.year,
                    ),
                  ),
                ),
              },
            ],
          );

    final campos = Row(
      children: [
        Expanded(
          child: _CampoFecha(
            etiqueta: 'Desde',
            fecha: _desde,
            activo: !_editandoHasta,
            onTap: () => setState(() => _editandoHasta = false),
          ),
        ),
        SizedBox(width: angosto ? 10 : 24),
        Expanded(
          child: _CampoFecha(
            etiqueta: 'Hasta',
            fecha: _hasta,
            activo: _editandoHasta,
            onTap: () => setState(() => _editandoHasta = true),
          ),
        ),
      ],
    );

    final caja = BoxDecoration(
      color: AppColors.surface2Glass,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.glassStrokeHighlight),
    );

    return Container(
      color: AppColors.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Encabezado ---
          Padding(
            padding: EdgeInsets.fromLTRB(margen, margen - 4, margen - 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.acento,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elegir periodo',
                        style: AppTextStyles.display.copyWith(
                          fontSize: angosto ? 24 : 28,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _subtitulo,
                          key: ValueKey(_subtitulo),
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: widget.onCerrar,
                  icon: const Icon(Icons.close_rounded, size: 28),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margen, 10, margen, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pestanas,
                  if (_enRango) ...[const SizedBox(height: 16), campos],
                  const SizedBox(height: 16),
                  if (angosto) ...[
                    accesos,
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: caja,
                      child: derecha,
                    ),
                  ] else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 230,
                            padding: const EdgeInsets.all(14),
                            decoration: caja,
                            child: accesos,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: caja,
                              child: derecha,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // --- Pie: resumen y botones ---
          Padding(
            padding: EdgeInsets.fromLTRB(margen, 4, margen, margen - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(height: 1, color: AppColors.glassStrokeStandard),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 12,
                  spacing: 12,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _resumen,
                              style: AppTextStyles.bodyLg.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (_notaHoy != null)
                          Text(
                            _notaHoy!,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: widget.onCerrar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.glassStrokeHighlight,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: AppTextStyles.bodyLg,
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _enRango && _desde == null
                              ? null
                              : _aplicar,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.acento,
                            foregroundColor: AppColors.sobreAcento,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: AppTextStyles.bodyLg.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Aplicar periodo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendario() {
    final r = _pendiente.rango;
    return _Calendario(
      mes: _mes,
      hoy: _hoy,
      onMes: (m) => setState(() => _mes = m),
      onDia: _tocarDia,
      // Qué se resalta: un día, una semana o el rango.
      desde: _enRango
          ? _desde
          : (_tipo == TipoPeriodo.semana ? r.desde : _soloDia(r.desde)),
      hasta: _enRango
          ? _hasta
          : (_tipo == TipoPeriodo.semana
                ? r.hasta.subtract(const Duration(days: 1))
                : _soloDia(r.desde)),
      banda: _enRango || _tipo == TipoPeriodo.semana,
      puntasCirculo: _enRango || _tipo == TipoPeriodo.dia,
    );
  }
}

/// "Semana | Rango personalizado".
class _Pestanas extends StatelessWidget {
  const _Pestanas({
    required this.izquierda,
    required this.enRango,
    required this.onCambiar,
  });

  final String izquierda;
  final bool enRango;
  final ValueChanged<bool> onCambiar;

  @override
  Widget build(BuildContext context) {
    Widget pestana(String texto, bool activa, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activa
                ? AppColors.acento.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activa ? AppColors.acento : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Text(
            texto,
            style: AppTextStyles.bodyLg.copyWith(
              fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2Glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassStrokeHighlight),
      ),
      child: Row(
        children: [
          pestana(izquierda, !enRango, () => onCambiar(false)),
          pestana('Rango personalizado', enRango, () => onCambiar(true)),
        ],
      ),
    );
  }
}

class _AccesosRapidos extends StatelessWidget {
  const _AccesosRapidos({
    required this.activo,
    required this.compacto,
    required this.onElegir,
  });

  final String? activo;
  final bool compacto;
  final ValueChanged<String> onElegir;

  static const _opciones = [
    ('hoy', 'Hoy', Icons.today_rounded),
    ('semana', 'Esta semana', Icons.date_range_rounded),
    ('mes', 'Este mes', Icons.calendar_month_rounded),
    ('30', 'Últimos 30 días', Icons.history_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    Widget opcion((String, String, IconData) o) {
      final (clave, texto, icono) = o;
      final elegido = clave == activo;
      return Material(
        color: elegido
            ? AppColors.acento.withValues(alpha: 0.14)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: elegido
                ? AppColors.acento
                : (compacto
                      ? AppColors.glassStrokeHighlight
                      : Colors.transparent),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onElegir(clave),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(
                  icono,
                  size: 20,
                  color: elegido ? AppColors.acento : AppColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Text(texto, style: AppTextStyles.bodyLg),
              ],
            ),
          ),
        ),
      );
    }

    if (compacto) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final o in _opciones) opcion(o)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text(
            'ACCESOS RÁPIDOS',
            style: AppTextStyles.labelCode.copyWith(letterSpacing: 2.2),
          ),
        ),
        for (final o in _opciones) ...[opcion(o), const SizedBox(height: 4)],
      ],
    );
  }
}

/// "📅 9–15 nov 2026  [Semana en curso]".
class _ChipSeleccion extends StatelessWidget {
  const _ChipSeleccion({required this.texto, required this.enCurso});

  final String texto;
  final String? enCurso;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface3ActiveGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassStrokeStandard),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.acento),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineSm,
            ),
          ),
          if (enCurso != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.acento.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                enCurso!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.acento),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.fecha,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final DateTime? fecha;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final f = fecha;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(etiqueta, style: AppTextStyles.bodyLg),
        ),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2Glass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activo
                    ? AppColors.acento
                    : AppColors.glassStrokeHighlight,
                width: activo ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Text(
                  f == null
                      ? 'dd/mm/aaaa'
                      : '${dos(f.day)}/${dos(f.month)}/${f.year}',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: f == null
                        ? AppColors.textPlaceholder
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Calendario de un mes (semana de lunes a domingo). Resalta un día, una
/// semana o un rango: con [banda], los días de en medio van unidos en una
/// franja; con [puntasCirculo], el primero y el último son círculos llenos.
/// Hoy lleva un puntito. No se puede tocar el futuro.
class _Calendario extends StatelessWidget {
  const _Calendario({
    required this.mes,
    required this.hoy,
    required this.onMes,
    required this.onDia,
    required this.desde,
    required this.hasta,
    required this.banda,
    required this.puntasCirculo,
  });

  final DateTime mes;
  final DateTime hoy;
  final ValueChanged<DateTime> onMes;
  final ValueChanged<DateTime> onDia;
  final DateTime? desde;
  final DateTime? hasta;
  final bool banda;
  final bool puntasCirculo;

  @override
  Widget build(BuildContext context) {
    final primero = DateTime(mes.year, mes.month);
    final diasMes = DateTime(mes.year, mes.month + 1, 0).day;
    final vacios = primero.weekday - 1;
    final celdas = <DateTime?>[
      for (var i = 0; i < vacios; i++) null,
      for (var d = 1; d <= diasMes; d++) DateTime(mes.year, mes.month, d),
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }
    final puedeAvanzar = DateTime(
      mes.year,
      mes.month + 1,
    ).isBefore(DateTime(hoy.year, hoy.month + 1));
    final d0 = desde;
    final d1 = hasta ?? desde;
    bool dentro(DateTime f) =>
        d0 != null && d1 != null && !f.isBefore(d0) && !f.isAfter(d1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${mesCapitalizado(mes.month)} ${mes.year}',
                style: AppTextStyles.headlineSm,
              ),
            ),
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: mes.year <= _primerAnio && mes.month == 1
                  ? null
                  : () => onMes(DateTime(mes.year, mes.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: puedeAvanzar
                  ? () => onMes(DateTime(mes.year, mes.month + 1))
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in _diasCortos)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var fila = 0; fila < celdas.length ~/ 7; fila++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dia = celdas[fila * 7 + col];
                        if (dia == null) return const SizedBox(height: 40);
                        final enRango = dentro(dia);
                        final esPunta =
                            puntasCirculo &&
                            ((d0 != null && _mismoDia(dia, d0)) ||
                                (d1 != null && _mismoDia(dia, d1)));
                        final futuro = dia.isAfter(hoy);
                        // La franja se redondea donde empieza o termina en
                        // esta fila.
                        final prev = col > 0
                            ? celdas[fila * 7 + col - 1]
                            : null;
                        final sig = col < 6 ? celdas[fila * 7 + col + 1] : null;
                        final abreIzq =
                            prev == null || !dentro(prev) || col == 0;
                        final cierraDer =
                            sig == null || !dentro(sig) || col == 6;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: futuro ? null : () => onDia(dia),
                          child: Container(
                            height: 40,
                            decoration: banda && enRango
                                ? BoxDecoration(
                                    color: AppColors.acento.withValues(
                                      alpha: 0.22,
                                    ),
                                    borderRadius: BorderRadius.horizontal(
                                      left: Radius.circular(abreIzq ? 20 : 0),
                                      right: Radius.circular(
                                        cierraDer ? 20 : 0,
                                      ),
                                    ),
                                  )
                                : null,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 38,
                                height: 38,
                                decoration: esPunta || (!banda && enRango)
                                    ? BoxDecoration(
                                        color: AppColors.acento,
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      '${dia.day}',
                                      style: AppTextStyles.bodyLg.copyWith(
                                        fontWeight: enRango
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: esPunta || (!banda && enRango)
                                            ? AppColors.sobreAcento
                                            : futuro
                                            ? AppColors.textPlaceholder
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (_mismoDia(dia, hoy))
                                      Positioned(
                                        bottom: 4,
                                        child: Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: esPunta
                                                ? AppColors.sobreAcento
                                                : AppColors.acento,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Los 12 meses de un año, con flechas para cambiar de año.
class _Meses extends StatelessWidget {
  const _Meses({
    required this.anio,
    required this.hoy,
    required this.elegido,
    required this.onAnio,
    required this.onMes,
  });

  final int anio;
  final DateTime hoy;
  final DateTime? elegido;
  final ValueChanged<int> onAnio;
  final ValueChanged<int> onMes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Año anterior',
              onPressed: anio > _primerAnio ? () => onAnio(anio - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '$anio',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSm,
              ),
            ),
            IconButton(
              tooltip: 'Año siguiente',
              onPressed: anio < hoy.year ? () => onAnio(anio + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Rejilla(
          children: [
            for (var m = 1; m <= 12; m++)
              _Celda(
                texto: mesCapitalizado(m),
                elegida:
                    elegido != null &&
                    elegido!.year == anio &&
                    elegido!.month == m,
                activa: DateTime(
                  anio,
                  m,
                ).isBefore(DateTime(hoy.year, hoy.month + 1)),
                onTap: () => onMes(m),
              ),
          ],
        ),
      ],
    );
  }
}

/// Los años desde 2020 hasta el actual.
class _Anios extends StatelessWidget {
  const _Anios({
    required this.hoy,
    required this.elegido,
    required this.onAnio,
  });

  final DateTime hoy;
  final int? elegido;
  final ValueChanged<int> onAnio;

  @override
  Widget build(BuildContext context) {
    return _Rejilla(
      children: [
        for (var a = hoy.year; a >= _primerAnio; a--)
          _Celda(
            texto: '$a',
            elegida: elegido == a,
            activa: true,
            onTap: () => onAnio(a),
          ),
      ],
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({
    required this.texto,
    required this.elegida,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool elegida;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegida
          ? AppColors.acento.withValues(alpha: 0.16)
          : AppColors.surface2Glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: elegida ? AppColors.acento : AppColors.glassStrokeStandard,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: activa ? onTap : null,
        child: Center(
          child: Text(
            texto,
            style: AppTextStyles.bodyLg.copyWith(
              color: activa ? AppColors.textPrimary : AppColors.textPlaceholder,
              fontWeight: elegida ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tres por fila, de alto fijo (sin GridView: así funciona dentro de
/// IntrinsicHeight).
class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var j = i; j < i + 3; j++) ...[
                  if (j > i) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: j < children.length
                          ? children[j]
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

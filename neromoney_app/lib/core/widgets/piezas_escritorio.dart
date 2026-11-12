import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';

// Piezas comunes de las pantallas de escritorio (Movimientos, Cuentas,
// Reportes, Perfil), para que todas se vean de la misma familia.

/// Margen estándar de una sección de escritorio, con espacio abajo para el
/// botón flotante "Hablar con…".
const margenSeccionEscritorio = EdgeInsets.fromLTRB(36, 32, 36, 120);

/// Ancho máximo del contenido: en monitores muy anchos no se estira más.
const anchoMaximoSeccion = 1320.0;

/// "REPORTES / Reportes / Entiende en qué se va tu dinero." + acciones a la
/// derecha.
class EncabezadoEscritorio extends StatelessWidget {
  const EncabezadoEscritorio({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.etiqueta,
    this.acciones = const [],
  });

  final String? etiqueta;
  final String titulo;
  final String subtitulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (etiqueta != null) ...[
                Text(
                  etiqueta!.toUpperCase(),
                  style: AppTextStyles.labelCode.copyWith(
                    color: AppColors.acento,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(titulo, style: AppTextStyles.display.copyWith(fontSize: 44)),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        for (final (i, accion) in acciones.indexed) ...[
          if (i > 0) const SizedBox(width: 14),
          accion,
        ],
      ],
    );
  }
}

/// Tarjeta de vidrio de las secciones de escritorio.
class TarjetaEscritorio extends StatelessWidget {
  const TarjetaEscritorio({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(26),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: padding,
      color: color,
      child: child,
    );
  }
}

/// Botón de píldora con contorno ("+ Agregar cuenta", "Editar perfil",
/// "Siguiente"). Con [relleno] es el botón principal sólido ("Nuevo
/// movimiento").
class BotonContorno extends StatefulWidget {
  const BotonContorno({
    super.key,
    required this.texto,
    required this.onTap,
    this.icono,
    this.color,
    this.relleno = false,
    this.iconoAlFinal = false,
  });

  final String texto;
  final VoidCallback? onTap;
  final IconData? icono;
  final Color? color;
  final bool relleno;
  final bool iconoAlFinal;

  @override
  State<BotonContorno> createState() => _BotonContornoState();
}

class _BotonContornoState extends State<BotonContorno> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onTap != null;
    final color = widget.color ?? AppColors.acento;
    final colorTexto = widget.relleno
        ? AppColors.sobreAcento
        : (activo ? color : AppColors.textPlaceholder);
    final icono = widget.icono == null
        ? null
        : Icon(widget.icono, size: 20, color: colorTexto);
    return MouseRegion(
      cursor: activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: widget.relleno
                ? color
                : (_encima && activo
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activo
                  ? color.withValues(alpha: widget.relleno ? 1 : 0.8)
                  : AppColors.glassStrokeHighlight,
              width: 1.5,
            ),
            boxShadow: widget.relleno && activo
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: _encima ? 0.45 : 0.25),
                      blurRadius: _encima ? 26 : 16,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null && !widget.iconoAlFinal) ...[
                icono,
                const SizedBox(width: 10),
              ],
              Text(
                widget.texto,
                style: AppTextStyles.bodyLg.copyWith(
                  color: colorTexto,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (icono != null && widget.iconoAlFinal) ...[
                const SizedBox(width: 10),
                icono,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Control segmentado: "Todos | Ingresos | Gastos", "Semana | Mes | Año".
class ControlSegmentado<T> extends StatelessWidget {
  const ControlSegmentado({
    super.key,
    required this.opciones,
    required this.seleccionado,
    required this.onCambiar,
  });

  final Map<T, String> opciones;
  final T seleccionado;
  final ValueChanged<T> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2Glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassStrokeHighlight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final MapEntry(key: valor, value: texto) in opciones.entries)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onCambiar(valor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: valor == seleccionado
                        ? AppColors.acento.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: valor == seleccionado
                          ? AppColors.acento.withValues(alpha: 0.8)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    texto,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: valor == seleccionado
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: valor == seleccionado
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Selector desplegable con ícono ("Todas las cuentas ⌄", "Todo el
/// historial ⌄", "● Negro ⌄").
class MenuDesplegable<T> extends StatelessWidget {
  const MenuDesplegable({
    super.key,
    required this.valor,
    required this.opciones,
    required this.onCambiar,
    this.icono,
    this.adorno,
  });

  final T valor;
  final Map<T, String> opciones;
  final ValueChanged<T> onCambiar;
  final IconData? icono;

  /// Algo a la izquierda de cada opción (ej. la muestra de color del tema).
  final Widget Function(T valor)? adorno;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      onSelected: onCambiar,
      color: AppColors.surface1,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassStrokeHighlight),
      ),
      itemBuilder: (_) => [
        for (final MapEntry(key: v, value: texto) in opciones.entries)
          PopupMenuItem<T>(
            value: v,
            child: Row(
              children: [
                if (adorno != null) ...[adorno!(v), const SizedBox(width: 12)],
                Text(
                  texto,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: v == valor ? AppColors.acento : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface2Glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassStrokeHighlight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
            ],
            if (adorno != null) ...[adorno!(valor), const SizedBox(width: 12)],
            Flexible(
              child: Text(
                opciones[valor] ?? '',
                style: AppTextStyles.bodyLg,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Etiqueta con ícono" de color (la categoría en la tabla de movimientos).
class PildoraCategoria extends StatelessWidget {
  const PildoraCategoria({
    super.key,
    required this.texto,
    required this.icono,
    required this.color,
  });

  final String texto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Color estable para una categoría (texto libre, sin color propio): el
/// mismo nombre siempre da el mismo color, sin depender del orden en que
/// aparezca. Ingresos siempre en verde.
Color colorDeCategoria(String categoria, {required bool esIngreso}) {
  if (esIngreso) return AppColors.inflowEmerald;
  const colores = [
    Color(0xFFA855F7), // violeta
    Color(0xFF22D3EE), // cian
    Color(0xFFF472B6), // rosa
    Color(0xFFF59E0B), // ámbar
    Color(0xFF818CF8), // índigo
    Color(0xFF2DD4BF), // verde azulado
  ];
  final suma = categoria.codeUnits.fold<int>(0, (a, c) => a + c);
  return colores[suma % colores.length];
}

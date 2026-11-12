import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// Piezas de los formularios que se abren en un panel desde su botón (ver
// BotonConPanel): encabezado con título grande, campos en cajas redondeadas
// con la etiqueta adentro, y "×" + botón principal abajo — según la
// referencia de diseño que dio el usuario ("Crear movimiento").

/// Esqueleto del panel: encabezado, campos con scroll y botones abajo.
class FormularioPanel extends StatelessWidget {
  const FormularioPanel({
    super.key,
    required this.titulo,
    required this.campos,
    required this.textoAccion,
    required this.onAccion,
    required this.onCerrar,
    this.cargando = false,
    this.error,
    this.debajoDelTitulo,
  });

  final String titulo;
  final List<Widget> campos;
  final String textoAccion;
  final VoidCallback onAccion;
  final VoidCallback onCerrar;
  final bool cargando;

  /// Mensaje en rojo junto a los botones (ej. "Escribe un monto").
  final String? error;

  /// Algo bajo el título, dentro del encabezado (ej. Gasto / Ingreso).
  final Widget? debajoDelTitulo;

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Encabezado: "×" y el título grande ---
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassStrokeHighlight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BotonRedondo(
                  icono: Icons.close_rounded,
                  tooltip: 'Cerrar',
                  onTap: onCerrar,
                ),
                const SizedBox(height: 22),
                Text(
                  titulo,
                  style: AppTextStyles.display.copyWith(
                    fontSize: 40,
                    height: 1.05,
                  ),
                ),
                if (debajoDelTitulo != null) ...[
                  const SizedBox(height: 18),
                  debajoDelTitulo!,
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // --- Campos ---
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: teclado),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, campo) in campos.indexed) ...[
                    if (i > 0) const SizedBox(height: 12),
                    campo,
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // --- Abajo: error, "×" y el botón principal ---
          Row(
            children: [
              Expanded(
                child: error == null
                    ? const SizedBox.shrink()
                    : Text(
                        error!,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.outflowCrimson,
                        ),
                      ),
              ),
              _BotonRedondo(
                icono: Icons.close_rounded,
                tooltip: 'Cancelar',
                grande: true,
                onTap: onCerrar,
              ),
              const SizedBox(width: 12),
              _BotonPrincipal(
                texto: textoAccion,
                cargando: cargando,
                onTap: onAccion,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Caja redondeada con la etiqueta adentro, arriba del valor.
class CampoPanel extends StatelessWidget {
  const CampoPanel({
    super.key,
    required this.etiqueta,
    required this.child,
    this.alFinal,
    this.enfocado = false,
  });

  final String etiqueta;
  final Widget child;

  /// Ícono a la derecha (flecha de un selector, calendario...).
  final Widget? alFinal;

  /// Resalta la caja con el acento mientras se escribe en ella.
  final bool enfocado;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enfocado ? AppColors.acento : AppColors.glassStrokeHighlight,
          width: enfocado ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: AppTextStyles.bodySm),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
          if (alFinal != null) alFinal!,
        ],
      ),
    );
  }
}

/// Campo de texto dentro de un CampoPanel. El borde lo pone la caja (no el
/// del tema, que dibujaba otra caja dentro de la caja).
class TextoPanel extends StatefulWidget {
  const TextoPanel({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.pista,
    this.numerico = false,
    this.autofocus = false,
    this.capitalizar = TextCapitalization.sentences,
    this.onEnviar,
  });

  final String etiqueta;
  final TextEditingController controller;
  final String? pista;
  final bool numerico;
  final bool autofocus;
  final TextCapitalization capitalizar;
  final VoidCallback? onEnviar;

  @override
  State<TextoPanel> createState() => _TextoPanelState();
}

class _TextoPanelState extends State<TextoPanel> {
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tocar cualquier parte de la caja (también la etiqueta) enfoca el campo.
      onTap: _foco.requestFocus,
      child: CampoPanel(
        etiqueta: widget.etiqueta,
        enfocado: _foco.hasFocus,
        child: TextField(
          controller: widget.controller,
          focusNode: _foco,
          autofocus: widget.autofocus,
          textCapitalization: widget.capitalizar,
          keyboardType: widget.numerico
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          onSubmitted: widget.onEnviar == null
              ? null
              : (_) => widget.onEnviar!(),
          style: AppTextStyles.bodyLg,
          decoration: InputDecoration(
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: widget.pista,
            hintStyle: AppTextStyles.bodyLg.copyWith(
              color: AppColors.textPlaceholder,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector desplegable dentro de un CampoPanel ("Categoría ⌄", "Cuenta ⌄").
class SelectorPanel<T> extends StatelessWidget {
  const SelectorPanel({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onCambiar,
    this.textoVacio = 'Elegir',
    this.icono,
  });

  final String etiqueta;
  final T? valor;
  final Map<T, String> opciones;
  final ValueChanged<T> onCambiar;
  final String textoVacio;

  /// Ícono de cada opción en la lista (ej. el de la categoría).
  final IconData Function(T valor)? icono;

  @override
  Widget build(BuildContext context) {
    final texto = valor == null ? null : opciones[valor];
    return PopupMenuButton<T>(
      tooltip: '',
      onSelected: onCambiar,
      color: AppColors.surface1,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 260, maxHeight: 360),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassStrokeHighlight),
      ),
      itemBuilder: (_) => [
        for (final MapEntry(key: v, value: t) in opciones.entries)
          PopupMenuItem<T>(
            value: v,
            child: Row(
              children: [
                if (icono != null) ...[
                  Icon(icono!(v), size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    t,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: v == valor ? AppColors.acento : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: CampoPanel(
        etiqueta: etiqueta,
        alFinal: Icon(
          Icons.arrow_drop_down_rounded,
          color: AppColors.textSecondary,
        ),
        child: Text(
          texto ?? textoVacio,
          style: AppTextStyles.bodyLg.copyWith(
            color: texto == null ? AppColors.textPlaceholder : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Opciones en píldoras dentro del panel (Gasto/Ingreso, tipo de cuenta).
class PildorasPanel<T> extends StatelessWidget {
  const PildorasPanel({
    super.key,
    required this.opciones,
    required this.seleccionado,
    required this.onCambiar,
    this.colores,
  });

  final Map<T, String> opciones;
  final T seleccionado;
  final ValueChanged<T> onCambiar;

  /// Color propio por opción (rojo para Gasto, verde para Ingreso).
  final Map<T, Color>? colores;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: v, value: t) in opciones.entries)
          Builder(
            builder: (context) {
              final activo = v == seleccionado;
              final color = colores?[v] ?? AppColors.acento;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onCambiar(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: activo
                          ? color.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: activo ? color : AppColors.glassStrokeHighlight,
                      ),
                    ),
                    child: Text(
                      t,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: activo ? color : AppColors.textSecondary,
                        fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.tooltip,
    required this.onTap,
    this.grande = false,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final lado = grande ? 52.0 : 42.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface3ActiveGlass,
        shape: CircleBorder(
          side: BorderSide(color: AppColors.glassStrokeHighlight),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: lado,
            child: Icon(icono, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.texto,
    required this.cargando,
    required this.onTap,
  });

  final String texto;
  final bool cargando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Claro sobre fondo oscuro (y oscuro en el tema claro), como el "Crear"
    // blanco de la referencia.
    return Material(
      color: AppColors.textPrimary,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: cargando ? null : onTap,
        child: Container(
          height: 52,
          constraints: const BoxConstraints(minWidth: 108),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          alignment: Alignment.center,
          child: cargando
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.canvas,
                  ),
                )
              : Text(
                  texto,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.canvas,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Ventana de formulario (diseño del usuario, nov. 2026): encabezado con
/// ícono, título y subtítulo, la × para cerrar; el formulario con
/// desplazamiento; y abajo un resumen opcional, "Cancelar" y la acción
/// principal. Llena el espacio que le da BotonConPanel.
class DialogoFormulario extends StatelessWidget {
  const DialogoFormulario({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onCerrar,
    required this.child,
    required this.textoAccion,
    required this.onAccion,
    this.iconoAccion,
    this.resumen,
    this.cargando = false,
    this.error,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onCerrar;
  final Widget child;
  final String textoAccion;
  final IconData? iconoAccion;
  final VoidCallback onAccion;

  /// Línea de abajo, ej. "Gasto de $100.00 · Efectivo".
  final String? resumen;
  final bool cargando;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 600;
    final margen = angosto ? 20.0 : 30.0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface1,
            Color.alphaBlend(
              AppColors.secundario.withValues(alpha: 0.10),
              AppColors.surface1,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Encabezado ---
          Padding(
            padding: EdgeInsets.fromLTRB(margen, margen, margen - 6, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: AppColors.acento, size: angosto ? 34 : 44),
                SizedBox(width: angosto ? 12 : 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: AppTextStyles.display.copyWith(
                          fontSize: angosto ? 26 : 32,
                        ),
                      ),
                      Text(
                        subtitulo,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _BotonCerrar(onTap: onCerrar),
              ],
            ),
          ),
          // --- Formulario ---
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margen, 12, margen, 12),
              child: child,
            ),
          ),
          // --- Pie: error, resumen y botones ---
          Padding(
            padding: EdgeInsets.fromLTRB(margen, 0, margen, margen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      error!,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.outflowCrimson,
                      ),
                    ),
                  ),
                if (resumen != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      resumen!,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Divider(height: 1, color: AppColors.glassStrokeStandard),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: onCerrar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.glassStrokeHighlight),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 16,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: AppTextStyles.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: FilledButton.icon(
                        onPressed: cargando ? null : onAccion,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.acento,
                          foregroundColor: AppColors.sobreAcento,
                          disabledBackgroundColor: AppColors.acento.withValues(
                            alpha: 0.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 16,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: AppTextStyles.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: cargando
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.sobreAcento,
                                ),
                              )
                            : (iconoAccion == null ? null : Icon(iconoAccion)),
                        label: Text(
                          textoAccion,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
}

class _BotonCerrar extends StatelessWidget {
  const _BotonCerrar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: 'Cerrar', child: _circulo());
  }

  Widget _circulo() {
    return Material(
      color: AppColors.surface3ActiveGlass,
      shape: CircleBorder(
        side: BorderSide(color: AppColors.glassStrokeHighlight),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.close_rounded,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Etiqueta arriba del campo ("Monto", "Categoría").
class CampoEtiquetado extends StatelessWidget {
  const CampoEtiquetado({
    super.key,
    required this.etiqueta,
    required this.child,
    this.ayuda,
  });

  final String etiqueta;
  final Widget child;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          etiqueta,
          style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        child,
        if (ayuda != null) ...[
          const SizedBox(height: 6),
          Text(
            ayuda!,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bordes y relleno de los campos de la ventana: redondeados, con el
/// acento al enfocar.
InputDecoration decoracionCampo({
  String? pista,
  String? prefijo,
  String? sufijo,
  Widget? icono,
}) {
  OutlineInputBorder borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: ancho),
      );
  return InputDecoration(
    hintText: pista,
    // Como íconos (no prefixText/suffixText) para que se vean siempre, no
    // solo al enfocar el campo.
    prefixIcon:
        icono ??
        (prefijo == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 18, right: 4),
                child: Text(prefijo, style: AppTextStyles.bodyLg),
              )),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: sufijo == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: 18, left: 8),
            child: Text(
              sufijo,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    filled: true,
    fillColor: AppColors.surface2Glass,
    isDense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: borde(AppColors.glassStrokeHighlight),
    enabledBorder: borde(AppColors.glassStrokeHighlight),
    focusedBorder: borde(AppColors.acento, 2),
    errorBorder: borde(AppColors.outflowCrimson),
  );
}

/// Desplegable con el mismo estilo que los campos de texto.
class SelectorCampo<T> extends StatelessWidget {
  const SelectorCampo({
    super.key,
    required this.valor,
    required this.opciones,
    required this.onCambiar,
    this.icono,
    this.pista,
  });

  final T? valor;
  final Map<T, String> opciones;
  final ValueChanged<T> onCambiar;
  final IconData Function(T valor)? icono;
  final String? pista;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: valor,
      isExpanded: true,
      dropdownColor: AppColors.surface1,
      borderRadius: BorderRadius.circular(14),
      icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textPrimary),
      decoration: decoracionCampo(pista: pista),
      style: AppTextStyles.bodyLg,
      items: [
        for (final MapEntry(key: v, value: texto) in opciones.entries)
          DropdownMenuItem(
            value: v,
            child: Row(
              children: [
                if (icono != null) ...[
                  Icon(icono!(v), size: 22, color: AppColors.textPrimary),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Text(texto, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onCambiar(v);
      },
    );
  }
}

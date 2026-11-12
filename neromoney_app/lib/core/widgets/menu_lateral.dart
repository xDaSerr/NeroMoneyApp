import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Menú lateral del diseño de escritorio (ver AppShell): marca arriba, las
/// secciones principales, y Perfil + el usuario abajo. Sustituye a la
/// barra flotante del teléfono cuando la ventana es ancha.
class MenuLateral extends StatelessWidget {
  const MenuLateral({
    super.key,
    required this.indiceActual,
    required this.onSeleccionar,
    required this.onReportes,
    required this.nombreUsuario,
    required this.inicialUsuario,
  });

  static const ancho = 240.0;

  /// Índice de la pestaña activa (0 Inicio, 1 Movimientos, 3 Cuentas, 4
  /// Perfil — el 2 es el chat, al que se llega con el botón "Hablar con").
  final int indiceActual;
  final ValueChanged<int> onSeleccionar;
  final VoidCallback onReportes;
  final String nombreUsuario;
  final String inicialUsuario;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      decoration: BoxDecoration(
        color: AppColors.surface1.withValues(alpha: 0.55),
        border: Border(right: BorderSide(color: AppColors.glassStrokeStandard)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Marca "• NeroMoney" ---
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 32),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.acento,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.brilloAcento, blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'NeroMoney',
                  style: AppTextStyles.headlineSm.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
          // --- Secciones principales ---
          _ItemMenu(
            icono: Icons.home_outlined,
            iconoActivo: Icons.home_rounded,
            texto: 'Inicio',
            activo: indiceActual == 0,
            onTap: () => onSeleccionar(0),
          ),
          _ItemMenu(
            icono: Icons.swap_horiz_rounded,
            texto: 'Movimientos',
            activo: indiceActual == 1,
            onTap: () => onSeleccionar(1),
          ),
          _ItemMenu(
            icono: Icons.credit_card_outlined,
            iconoActivo: Icons.credit_card_rounded,
            texto: 'Cuentas',
            activo: indiceActual == 3,
            onTap: () => onSeleccionar(3),
          ),
          // Reportes no es una pestaña (vive fuera del shell, ver
          // app_router.dart): se abre encima, igual que desde Perfil.
          _ItemMenu(
            icono: Icons.bar_chart_rounded,
            texto: 'Reportes',
            activo: false,
            onTap: onReportes,
          ),
          const Spacer(),
          Divider(color: AppColors.glassStrokeStandard, height: 24),
          // --- Perfil y el usuario ---
          _ItemMenu(
            icono: Icons.person_outline_rounded,
            iconoActivo: Icons.person_rounded,
            texto: 'Perfil',
            activo: indiceActual == 4,
            onTap: () => onSeleccionar(4),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.secundario.withValues(alpha: 0.3),
                  child: Text(
                    inicialUsuario,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nombreUsuario,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatefulWidget {
  const _ItemMenu({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.onTap,
    this.iconoActivo,
  });

  final IconData icono;
  final IconData? iconoActivo;
  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  State<_ItemMenu> createState() => _ItemMenuState();
}

class _ItemMenuState extends State<_ItemMenu> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.activo;
    final color = activo ? AppColors.textPrimary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: activo
                  ? AppColors.acento.withValues(alpha: 0.12)
                  : (_encima
                        ? AppColors.surface3ActiveGlass
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activo
                    ? AppColors.acento.withValues(alpha: 0.6)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  activo ? (widget.iconoActivo ?? widget.icono) : widget.icono,
                  color: activo ? AppColors.acento : color,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  widget.texto,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: color,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Secciones del diseño de escritorio y la ruta a la que lleva cada una. El
/// chat ("asistente") está en el menú con el nombre del asistente y también
/// se abre con el botón "Hablar con…".
enum SeccionEscritorio {
  inicio('/home'),
  movimientos('/movements'),
  cuentas('/accounts'),
  reportes('/reports'),
  libreta('/libreta'),
  compartido('/compartido'),
  perfil('/profile'),
  asistente('/assistant');

  const SeccionEscritorio(this.ruta);
  final String ruta;

  /// La sección a la que pertenece una ruta (incluye lo que cuelga de ella,
  /// ej. /accounts/detalle → cuentas). null = pantalla de un solo paso
  /// (agregar movimiento, transferir, editar perfil...).
  static SeccionEscritorio? deRuta(String ruta) {
    // La personalización del asistente se ve como parte de su sección.
    if (ruta == '/personalizar-asistente') return asistente;
    for (final s in values) {
      if (ruta == s.ruta || ruta.startsWith('${s.ruta}/')) return s;
    }
    return null;
  }
}

/// Menú lateral del diseño de escritorio (ver MarcoEscritorio): marca arriba,
/// las secciones principales, y Perfil + el usuario abajo.
class MenuLateral extends StatelessWidget {
  const MenuLateral({
    super.key,
    required this.activa,
    required this.onIr,
    required this.llaves,
    required this.nombreUsuario,
    required this.inicialUsuario,
    this.nombreAsistente = 'Lucy',
  });

  static const ancho = 240.0;

  final SeccionEscritorio? activa;
  final ValueChanged<SeccionEscritorio> onIr;

  /// Una llave por botón: MarcoEscritorio la usa para saber dónde está cada
  /// uno y hacer que la sección "salga" de su botón.
  final Map<SeccionEscritorio, GlobalKey> llaves;
  final String nombreUsuario;
  final String inicialUsuario;

  /// Texto del botón del chat (el nombre que el usuario le puso).
  final String nombreAsistente;

  Widget _item(
    SeccionEscritorio seccion,
    String texto,
    IconData icono, [
    IconData? iconoActivo,
  ]) => _ItemMenu(
    // La llave del asistente ya la usa el botón "Hablar con…" (de ahí sale
    // la animación del chat); una GlobalKey no puede estar en dos lugares.
    key: seccion == SeccionEscritorio.asistente ? null : llaves[seccion],
    icono: icono,
    iconoActivo: iconoActivo,
    texto: texto,
    activo: activa == seccion,
    onTap: () => onIr(seccion),
  );

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
          _item(
            SeccionEscritorio.inicio,
            'Inicio',
            Icons.home_outlined,
            Icons.home_rounded,
          ),
          _item(
            SeccionEscritorio.movimientos,
            'Movimientos',
            Icons.swap_horiz_rounded,
          ),
          _item(
            SeccionEscritorio.cuentas,
            'Cuentas',
            Icons.credit_card_outlined,
            Icons.credit_card_rounded,
          ),
          _item(
            SeccionEscritorio.reportes,
            'Reportes',
            Icons.bar_chart_rounded,
          ),
          _item(
            SeccionEscritorio.libreta,
            'Libreta',
            Icons.menu_book_outlined,
            Icons.menu_book_rounded,
          ),
          _item(
            SeccionEscritorio.compartido,
            'Compartido',
            Icons.groups_outlined,
            Icons.groups_rounded,
          ),
          // --- El chat con el asistente (también se abre con "Hablar con…") ---
          _item(
            SeccionEscritorio.asistente,
            nombreAsistente,
            Icons.auto_awesome_outlined,
            Icons.auto_awesome_rounded,
          ),
          const Spacer(),
          Divider(color: AppColors.glassStrokeStandard, height: 24),
          // --- Perfil y el usuario ---
          _item(
            SeccionEscritorio.perfil,
            'Perfil',
            Icons.person_outline_rounded,
            Icons.person_rounded,
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
    super.key,
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

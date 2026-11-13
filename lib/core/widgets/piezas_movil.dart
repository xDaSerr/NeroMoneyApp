import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/onboarding/providers/perfil_providers.dart';
import '../../features/profile/data/saludo_usuario.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formato_monto.dart';
import 'glass_card.dart';

// Piezas comunes del diseño móvil (según las pantallas que diseñó el
// usuario): encabezado de marca, título de sección y tarjetas.

/// "• NeroMoney" a la izquierda y la inicial del usuario a la derecha
/// (lleva a Perfil).
class EncabezadoMovil extends ConsumerWidget {
  const EncabezadoMovil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saludo = datosDeSaludo(
      ref.watch(authStateChangesProvider).value,
      ref.watch(perfilProvider).value?.apodo,
    );
    return Row(
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
        Expanded(
          child: Text(
            'NeroMoney',
            style: AppTextStyles.headlineSm.copyWith(fontSize: 22),
          ),
        ),
        // --- Inicial del usuario → Perfil ---
        Semantics(
          button: true,
          label: 'Ir a tu perfil',
          child: GestureDetector(
            onTap: () => context.go('/profile'),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.secundario.withValues(alpha: 0.55),
              child: Text(
                saludo.inicial,
                style: AppTextStyles.headlineSm.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Título grande de la sección con subtítulo y una acción a la derecha.
class TituloMovil extends StatelessWidget {
  const TituloMovil({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.accion,
  });

  final String titulo;
  final String subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: AppTextStyles.display.copyWith(fontSize: 34),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        if (accion != null) ...[const SizedBox(width: 12), accion!],
      ],
    );
  }
}

/// Tarjeta de vidrio de las secciones móviles.
class TarjetaMovil extends StatelessWidget {
  const TarjetaMovil({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 22,
      padding: padding,
      color: color,
      child: child,
    );
  }
}

/// "PATRIMONIO TOTAL / $26,342.42 / MXN" con el ojo para ocultarlo, y
/// opcionalmente algo debajo (los accesos rápidos de Inicio, una nota).
class TarjetaPatrimonioMovil extends StatelessWidget {
  const TarjetaPatrimonioMovil({
    super.key,
    required this.total,
    required this.moneda,
    required this.ocultar,
    required this.onAlternar,
    this.nota,
    this.debajo,
  });

  final double total;
  final String moneda;
  final bool ocultar;
  final VoidCallback? onAlternar;
  final String? nota;
  final Widget? debajo;

  @override
  Widget build(BuildContext context) {
    return TarjetaMovil(
      color: AppColors.secundario.withValues(alpha: 0.14),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PATRIMONIO TOTAL',
                  style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
                ),
              ),
              // --- Ojo: oculta el patrimonio y los saldos ---
              IconButton(
                tooltip: ocultar ? 'Mostrar saldos' : 'Ocultar saldos',
                color: AppColors.acento,
                onPressed: onAlternar,
                icon: Icon(
                  ocultar
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          Text(
            ocultar ? '••••••' : formatoMonto(total),
            semanticsLabel: ocultar ? 'Patrimonio oculto' : null,
            style: AppTextStyles.numericHero.copyWith(fontSize: 38),
          ),
          Text(
            moneda,
            style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
          ),
          if (nota != null) ...[
            const SizedBox(height: 6),
            Text(
              nota!,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (debajo != null) ...[
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.only(right: 8), child: debajo),
          ],
        ],
      ),
    );
  }
}

/// "Ver todas (4) →" en el acento.
class EnlaceVerTodo extends StatelessWidget {
  const EnlaceVerTodo({super.key, required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.acento),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.acento),
        ],
      ),
    );
  }
}

/// Control segmentado a todo lo ancho ("Todos / Ingresos / Gastos",
/// "Semana / Mes / Año").
class SegmentadoMovil<T> extends StatelessWidget {
  const SegmentadoMovil({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onCambiar,
  });

  final Map<T, String> opciones;
  final T valor;
  final ValueChanged<T> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2Glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassStrokeHighlight),
      ),
      child: Row(
        children: [
          for (final MapEntry(key: v, value: texto) in opciones.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == valor,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onCambiar(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == valor
                          ? AppColors.acento.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: v == valor
                            ? AppColors.acento.withValues(alpha: 0.8)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      texto,
                      style: AppTextStyles.bodyLg.copyWith(
                        color: v == valor
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: v == valor
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
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

/// Botón relleno del acento para la acción del título ("+ Nuevo",
/// "+ Agregar").
class BotonAccionMovil extends StatelessWidget {
  const BotonAccionMovil({
    super.key,
    required this.texto,
    required this.onTap,
    this.icono = Icons.add_rounded,
  });

  final String texto;
  final VoidCallback onTap;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.acento,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: AppColors.sobreAcento),
              const SizedBox(width: 6),
              Text(
                texto,
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.sobreAcento,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

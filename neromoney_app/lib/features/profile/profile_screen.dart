import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../auth/providers/auth_providers.dart';
import '../onboarding/providers/perfil_providers.dart';

/// Perfil: correo de la sesión activa, un menú de secciones (Reportes —
/// antes era su propia pestaña, se movió aquí para dejarle el lugar a
/// "Cuentas" en la barra inferior — y Personalizar asistente) y cerrar
/// sesión. El resto (cambiar moneda) se arma en una siguiente pasada.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final nombreAsistente =
        ref.watch(perfilProvider).value?.nombreAsistente ?? 'tu asistente';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      // SafeArea + el extra abajo (espacioParaBarraFlotante) son para que
      // "Cerrar sesión" nunca quede tapado por la píldora flotante de
      // navegación (ver AppShell, extendBody:true). Con scroll (en vez de
      // un Column fijo con Spacer, como estaba antes) en lugar de
      // desbordarse si ese margen no cabe entero en pantallas más chicas
      // — mismo patrón que ya usan Inicio y Cuentas.
      body: SafeArea(
        // No recortar el viewport a la altura de la navegación: el margen
        // al final del scroll permite alcanzar el botón de cerrar sesión.
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + espacioParaBarraFlotante(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.secondaryViolet.withValues(
                  alpha: 0.3,
                ),
                child: Text(
                  (user?.email ?? '?').substring(0, 1).toUpperCase(),
                  style: AppTextStyles.headlineMd,
                ),
              ),
              const SizedBox(height: 12),
              Text(user?.email ?? 'Sin sesión', style: AppTextStyles.bodyLg),
              const SizedBox(height: 24),
              // --- Menú de secciones: "Reportes" vive aquí ahora ---
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ItemMenu(
                      icono: Icons.pie_chart_rounded,
                      titulo: 'Reportes',
                      onTap: () => context.push('/reports'),
                    ),
                    const Divider(
                      height: 1,
                      color: AppColors.glassStrokeStandard,
                    ),
                    _ItemMenu(
                      icono: Icons.face_retouching_natural_rounded,
                      titulo: 'Personalizar a $nombreAsistente',
                      onTap: () => context.push('/personalizar-asistente'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // --- Botón "Cerrar sesión" (rojo/violeta para distinguirlo de las CTA normales) ---
              GradientButton(
                label: 'Cerrar sesión',
                colors: const [AppColors.outflowCrimson, Color(0xFF7B2CBF)],
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icono, color: AppColors.primaryCyan, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(titulo, style: AppTextStyles.bodyLg)),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textPlaceholder,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../auth/providers/auth_providers.dart';
import '../onboarding/data/perfil_usuario.dart';
import '../onboarding/providers/perfil_providers.dart';
import 'data/saludo_usuario.dart';
import 'widgets/selector_moneda_dialog.dart';

/// Perfil: encabezado con apodo/nombre real, un menú de secciones (Editar
/// perfil, Moneda, Reportes — antes era su propia pestaña, se movió aquí
/// para dejarle el lugar a "Cuentas" en la barra inferior — y Personalizar
/// asistente) y cerrar sesión.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final perfil = ref.watch(perfilProvider).value;
    final nombreAsistente = perfil?.nombreAsistente ?? 'tu asistente';
    final saludo = datosDeSaludo(user, perfil?.apodo);

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
                child: Text(saludo.inicial, style: AppTextStyles.headlineMd),
              ),
              const SizedBox(height: 12),
              // --- Apodo (o el nombre derivado si nunca lo eligió) ---
              Text(saludo.nombre, style: AppTextStyles.headlineSm),
              // --- Nombre real: solo si el usuario lo puso (100% opcional) ---
              if (perfil?.nombreCompleto.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(perfil!.nombreCompleto, style: AppTextStyles.bodyMd),
              ],
              const SizedBox(height: 2),
              Text(
                user?.email ?? 'Sin sesión',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              // --- Menú de secciones ---
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // --- "Editar perfil": apodo (saludo de Inicio) + nombre real opcional ---
                    _ItemMenu(
                      icono: Icons.badge_rounded,
                      titulo: 'Editar perfil',
                      onTap: () => context.push('/editar-perfil'),
                    ),
                    const Divider(
                      height: 1,
                      color: AppColors.glassStrokeStandard,
                    ),
                    // --- "Moneda": solo relabeling, nunca convierte montos guardados ---
                    _ItemMenu(
                      icono: Icons.payments_rounded,
                      titulo: 'Moneda',
                      valor: perfil?.moneda,
                      onTap: () => mostrarSelectorMoneda(
                        context: context,
                        monedaActual: perfil?.moneda ?? 'MXN',
                        onElegir: (codigo) => ref
                            .read(perfilRepositoryProvider)
                            .guardarPerfil(
                              (perfil ?? PerfilUsuario.vacio).copyWith(
                                moneda: codigo,
                              ),
                            ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      color: AppColors.glassStrokeStandard,
                    ),
                    // --- "Recordatorios": avisos locales para no olvidar registrar gastos ---
                    _ItemMenu(
                      icono: Icons.notifications_rounded,
                      titulo: 'Recordatorios',
                      valor: perfil?.recordatoriosActivados == true
                          ? 'Activados'
                          : 'Desactivados',
                      onTap: () => context.push('/recordatorios'),
                    ),
                    const Divider(
                      height: 1,
                      color: AppColors.glassStrokeStandard,
                    ),
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
    this.valor,
  });
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;
  // Texto corto opcional antes de la flecha (ej. "MXN" en "Moneda").
  final String? valor;

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
            if (valor != null) ...[
              Text(
                valor!,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
            ],
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

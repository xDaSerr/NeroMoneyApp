import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/tema_app.dart';
import '../../../core/widgets/anillo_asistente.dart';
import '../../../core/widgets/piezas_movil.dart';
import '../../auth/providers/auth_providers.dart';
import '../../onboarding/data/perfil_usuario.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../../planes/data/membresia.dart';
import '../../planes/providers/planes_providers.dart';
import '../../reminders/data/recordatorios_service.dart';
import '../data/saludo_usuario.dart';
import 'perfil_escritorio.dart' show PerfilEscritorio;
import 'selector_moneda_dialog.dart';
import 'selector_tema_dialog.dart';

/// Perfil en teléfono (diseño móvil del usuario): tarjeta del usuario,
/// preferencias (moneda, apariencia, recordatorios, reportes), el
/// asistente y cerrar sesión.
class PerfilMovil extends ConsumerWidget {
  const PerfilMovil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authStateChangesProvider).value;
    final perfil = ref.watch(perfilProvider).value ?? PerfilUsuario.vacio;
    final saludo = datosDeSaludo(usuario, perfil.apodo);
    final plan = ref.watch(membresiaProvider).value?.plan ?? PlanNero.gratis;

    Future<void> guardar(PerfilUsuario cambiado) =>
        ref.read(perfilRepositoryProvider).guardarPerfil(cambiado);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            20 + espacioParaBarraFlotante(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EncabezadoMovil(),
              const SizedBox(height: 18),
              const TituloMovil(
                titulo: 'Mi perfil',
                subtitulo: 'Haz NeroMoney tuyo.',
              ),
              const SizedBox(height: 18),
              // --- Tarjeta del usuario ---
              TarjetaMovil(
                color: AppColors.secundario.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.secundario.withValues(
                        alpha: 0.45,
                      ),
                      child: Text(
                        saludo.inicial,
                        style: AppTextStyles.headlineLg.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            saludo.nombre,
                            style: AppTextStyles.headlineMd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (perfil.nombreCompleto.isNotEmpty)
                            Text(
                              perfil.nombreCompleto,
                              style: AppTextStyles.bodyMd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            PerfilEscritorio.correoOculto(usuario?.email),
                            style: AppTextStyles.bodyMd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // --- "Editar perfil" → apodo y nombre ---
                          OutlinedButton.icon(
                            onPressed: () => context.push('/editar-perfil'),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.acento,
                            ),
                            label: Text(
                              'Editar perfil',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.acento,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: AppColors.acento.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // --- Preferencias ---
              TarjetaMovil(
                padding: const EdgeInsets.fromLTRB(16, 16, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Text(
                        'Preferencias',
                        style: AppTextStyles.headlineSm,
                      ),
                    ),
                    // --- Membresía: Gratis / Plus / Pro ---
                    _Preferencia(
                      icono: Icons.workspace_premium_outlined,
                      titulo: 'Tu plan',
                      valor: plan.nombre,
                      onTap: () => context.push('/planes'),
                    ),
                    // --- Respaldos mensuales (Pro) ---
                    _Preferencia(
                      icono: Icons.cloud_done_outlined,
                      titulo: 'Respaldos',
                      valor: plan == PlanNero.pro ? null : 'Pro',
                      onTap: () => context.push('/respaldos'),
                    ),
                    // --- Moneda: solo cambia el símbolo, nunca convierte montos ---
                    _Preferencia(
                      icono: Icons.payments_outlined,
                      titulo: 'Moneda',
                      valor: perfil.moneda,
                      onTap: () => mostrarSelectorMoneda(
                        context: context,
                        monedaActual: perfil.moneda,
                        onElegir: (codigo) =>
                            guardar(perfil.copyWith(moneda: codigo)),
                      ),
                    ),
                    // --- Apariencia: los 8 colores de la app ---
                    _Preferencia(
                      icono: Icons.palette_outlined,
                      titulo: 'Apariencia',
                      // Con fondo (Plus) se muestra el fondo; si no, el color.
                      valor: plan != PlanNero.gratis && perfil.fondo != null
                          ? perfil.fondo!.etiqueta
                          : perfil.tema.etiqueta,
                      onTap: () => mostrarSelectorTema(
                        context: context,
                        plan: plan,
                        onElegir: (tema) => guardar(
                          (ref.read(perfilProvider).value ??
                                  PerfilUsuario.vacio)
                              .copyWith(tema: tema),
                        ),
                        onElegirFondo: (fondo) => guardar(
                          (ref.read(perfilProvider).value ??
                                  PerfilUsuario.vacio)
                              .copyWith(fondo: fondo),
                        ),
                      ),
                    ),
                    // --- Recordatorios: solo existen en la app del teléfono ---
                    _Preferencia(
                      icono: Icons.notifications_none_rounded,
                      titulo: 'Recordatorios',
                      subtitulo: RecordatoriosService.disponible
                          ? null
                          : 'Solo en la app del teléfono',
                      onTap: RecordatoriosService.disponible
                          ? () => context.push('/recordatorios')
                          : null,
                      control: Switch(
                        value: perfil.recordatoriosActivados,
                        activeThumbColor: AppColors.acento,
                        onChanged: RecordatoriosService.disponible
                            ? (activar) =>
                                  _cambiarRecordatorios(context, ref, activar)
                            : null,
                      ),
                    ),
                    _Preferencia(
                      icono: Icons.pie_chart_outline_rounded,
                      titulo: 'Reportes',
                      onTap: () => context.push('/reports'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // --- Tu asistente ---
              TarjetaMovil(
                child: Row(
                  children: [
                    AnilloAsistente(
                      avatarBase64: perfil.avatarAsistenteBase64,
                      colores: _colores(perfil),
                      size: 76,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TU ASISTENTE',
                            style: AppTextStyles.labelCode.copyWith(
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            perfil.nombreAsistente,
                            style: AppTextStyles.headlineMd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Nombre, imagen y voz.',
                            style: AppTextStyles.bodyMd,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Personalizar a ${perfil.nombreAsistente}',
                      color: AppColors.acento,
                      onPressed: () => context.push('/personalizar-asistente'),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // --- Cerrar sesión ---
              OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.outflowCrimson,
                ),
                label: Text(
                  'Cerrar sesión',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.outflowCrimson,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: AppColors.outflowCrimson.withValues(alpha: 0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 280.ms),
        ),
      ),
    );
  }

  /// Activar pide primero el permiso de notificaciones (Android 13+); solo
  /// si lo concede se guarda. recordatoriosSyncProvider programa o cancela
  /// los avisos al ver el cambio en el perfil.
  Future<void> _cambiarRecordatorios(
    BuildContext context,
    WidgetRef ref,
    bool activar,
  ) async {
    if (activar && !await RecordatoriosService.pedirPermiso()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin permiso de notificaciones no podemos recordarte. '
              'Actívalo en los ajustes del teléfono.',
            ),
          ),
        );
      }
      return;
    }
    final perfil = ref.read(perfilProvider).value ?? PerfilUsuario.vacio;
    await ref
        .read(perfilRepositoryProvider)
        .guardarPerfil(perfil.copyWith(recordatoriosActivados: activar));
  }

  List<Color>? _colores(PerfilUsuario perfil) {
    final inicio = perfil.colorAnilloInicio;
    final fin = perfil.colorAnilloFin;
    if (inicio == null || fin == null) return null;
    return [Color(inicio), Color(fin)];
  }
}

class _Preferencia extends StatelessWidget {
  const _Preferencia({
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.valor,
    this.onTap,
    this.control,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final String? valor;
  final VoidCallback? onTap;
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface3ActiveGlass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassStrokeStandard),
              ),
              child: Icon(icono, color: AppColors.acento, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppTextStyles.bodyLg),
                  if (subtitulo != null)
                    Text(subtitulo!, style: AppTextStyles.bodySm),
                ],
              ),
            ),
            if (valor != null)
              Text(
                valor!,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            control ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPlaceholder,
                ),
          ],
        ),
      ),
    );
  }
}

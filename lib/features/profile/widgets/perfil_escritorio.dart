import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/controlador_tema.dart';
import '../../../core/theme/tema_app.dart';
import '../../../core/widgets/anillo_asistente.dart';
import '../../../core/widgets/piezas_escritorio.dart';
import '../../auth/providers/auth_providers.dart';
import '../../onboarding/data/perfil_usuario.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../../onboarding/widgets/currency_picker.dart';
import '../../reminders/data/recordatorios_service.dart';
import '../data/saludo_usuario.dart';
import 'selector_moneda_dialog.dart';

/// Perfil en ventana ancha (ver referencia de diseño del usuario): la
/// tarjeta del usuario y la sesión a la izquierda; preferencias y el
/// asistente a la derecha. Mismas acciones que en teléfono.
class PerfilEscritorio extends ConsumerWidget {
  const PerfilEscritorio({super.key});

  /// "daserr1025@gmail.com" → "d••••@gmail.com": se muestra a quién
  /// pertenece la sesión sin dejar el correo completo a la vista.
  static String correoOculto(String? correo) {
    if (correo == null || !correo.contains('@')) return 'Sin correo';
    final partes = correo.split('@');
    return '${partes.first.substring(0, 1)}••••@${partes.last}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authStateChangesProvider).value;
    final perfil = ref.watch(perfilProvider).value ?? PerfilUsuario.vacio;
    final saludo = datosDeSaludo(usuario, perfil.apodo);
    final moneda = monedasDisponibles
        .where((m) => m.codigo == perfil.moneda)
        .firstOrNull;

    Future<void> guardar(PerfilUsuario cambiado) =>
        ref.read(perfilRepositoryProvider).guardarPerfil(cambiado);

    return Scaffold(
      body: SingleChildScrollView(
        padding: margenSeccionEscritorio,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoSeccion),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoEscritorio(
                  etiqueta: 'Perfil',
                  titulo: 'Mi perfil',
                  subtitulo: 'Tu cuenta y tus preferencias, en un solo lugar.',
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Columna izquierda: usuario y sesión ---
                    Expanded(
                      flex: 9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TarjetaEscritorio(
                            color: AppColors.secundario.withValues(alpha: 0.12),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 56,
                                  backgroundColor: AppColors.secundario
                                      .withValues(alpha: 0.35),
                                  child: Text(
                                    saludo.inicial,
                                    style: AppTextStyles.display,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  saludo.nombre,
                                  style: AppTextStyles.headlineLg,
                                ),
                                if (perfil.nombreCompleto.isNotEmpty)
                                  Text(
                                    perfil.nombreCompleto,
                                    style: AppTextStyles.bodyLg.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                Text(
                                  correoOculto(usuario?.email),
                                  style: AppTextStyles.bodyLg.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // --- Botón "Editar perfil" → apodo y nombre ---
                                BotonContorno(
                                  texto: 'Editar perfil',
                                  icono: Icons.edit_outlined,
                                  onTap: () => context.push('/editar-perfil'),
                                ),
                                const SizedBox(height: 22),
                                Divider(color: AppColors.glassStrokeHighlight),
                                // --- "Moneda de la cuenta" → selector (solo
                                // cambia el símbolo, nunca convierte montos) ---
                                Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    leading: Icon(
                                      Icons.payments_outlined,
                                      color: AppColors.acento,
                                      size: 30,
                                    ),
                                    title: Text(
                                      'Moneda de la cuenta',
                                      style: AppTextStyles.bodyMd,
                                    ),
                                    subtitle: Text(
                                      '${perfil.moneda}${moneda == null ? '' : ' · ${moneda.nombre}'}',
                                      style: AppTextStyles.headlineSm,
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                    onTap: () => mostrarSelectorMoneda(
                                      context: context,
                                      monedaActual: perfil.moneda,
                                      onElegir: (codigo) => guardar(
                                        perfil.copyWith(moneda: codigo),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          // --- Sesión ---
                          TarjetaEscritorio(
                            color: AppColors.outflowCrimson.withValues(
                              alpha: 0.08,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sesión', style: AppTextStyles.headlineMd),
                                const SizedBox(height: 4),
                                Text(
                                  'Administra tu acceso a NeroMoney.',
                                  style: AppTextStyles.bodyLg.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // --- Botón "Cerrar sesión" ---
                                BotonContorno(
                                  texto: 'Cerrar sesión',
                                  icono: Icons.logout_rounded,
                                  color: AppColors.outflowCrimson,
                                  onTap: () => ref
                                      .read(authRepositoryProvider)
                                      .signOut(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 26),
                    // --- Columna derecha: preferencias y asistente ---
                    Expanded(
                      flex: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TarjetaEscritorio(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Preferencias',
                                  style: AppTextStyles.headlineMd,
                                ),
                                const SizedBox(height: 14),
                                // --- Apariencia: los 8 colores de la app ---
                                _Preferencia(
                                  icono: Icons.palette_outlined,
                                  titulo: 'Apariencia',
                                  subtitulo: 'Color de la app',
                                  control: MenuDesplegable<TemaApp>(
                                    valor: perfil.tema,
                                    opciones: {
                                      for (final t in TemaApp.values)
                                        t: t.etiqueta,
                                    },
                                    adorno: (t) => _Muestra(tema: t),
                                    onCambiar: (tema) {
                                      // Se aplica al instante; el perfil lo
                                      // guarda para los demás dispositivos.
                                      ControladorTema.instancia.cambiar(tema);
                                      guardar(perfil.copyWith(tema: tema));
                                    },
                                  ),
                                ),
                                Divider(color: AppColors.glassStrokeStandard),
                                // --- Recordatorios: solo existen en el teléfono ---
                                _Preferencia(
                                  icono: Icons.notifications_none_rounded,
                                  titulo: 'Recordatorios',
                                  subtitulo: 'Avisos para tus registros',
                                  control: RecordatoriosService.disponible
                                      ? TextButton(
                                          onPressed: () =>
                                              context.push('/recordatorios'),
                                          child: Text(
                                            perfil.recordatoriosActivados
                                                ? 'Activados'
                                                : 'Desactivados',
                                          ),
                                        )
                                      : Text(
                                          'Solo en la app del teléfono',
                                          style: AppTextStyles.bodyMd,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          // --- Tu asistente ---
                          TarjetaEscritorio(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tu asistente',
                                  style: AppTextStyles.headlineMd,
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    AnilloAsistente(
                                      avatarBase64:
                                          perfil.avatarAsistenteBase64,
                                      colores: _colores(perfil),
                                      size: 150,
                                    ),
                                    const SizedBox(width: 30),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            perfil.nombreAsistente,
                                            style: AppTextStyles.display
                                                .copyWith(fontSize: 38),
                                          ),
                                          Text(
                                            'Asistente de finanzas',
                                            style: AppTextStyles.bodyLg
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Personaliza su nombre, imagen y voz.',
                                            style: AppTextStyles.bodyLg,
                                          ),
                                          const SizedBox(height: 18),
                                          // --- "Personalizar a {nombre}" ---
                                          BotonContorno(
                                            texto:
                                                'Personalizar a ${perfil.nombreAsistente}',
                                            icono: Icons.tune_rounded,
                                            onTap: () => context.push(
                                              '/personalizar-asistente',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
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
    required this.subtitulo,
    required this.control,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface3ActiveGlass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassStrokeStandard),
            ),
            child: Icon(icono, color: AppColors.textSecondary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTextStyles.headlineSm),
                Text(subtitulo, style: AppTextStyles.bodyMd),
              ],
            ),
          ),
          control,
        ],
      ),
    );
  }
}

/// Puntito con el color de un tema, para el selector de Apariencia.
class _Muestra extends StatelessWidget {
  const _Muestra({required this.tema});

  final TemaApp tema;

  @override
  Widget build(BuildContext context) {
    final paleta = PaletaTema.de(tema);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: paleta.canvas,
        border: Border.all(color: paleta.acento, width: 3),
      ),
    );
  }
}

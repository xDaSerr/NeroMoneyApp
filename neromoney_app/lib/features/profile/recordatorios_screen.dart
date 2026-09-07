import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../onboarding/data/perfil_usuario.dart';
import '../onboarding/providers/perfil_providers.dart';
import '../reminders/data/recordatorios_service.dart';
import 'data/saludo_usuario.dart';

/// Recordatorios locales para no olvidar registrar gastos — pedido
/// explícito del usuario ("Lucy: Hola, te recuerdo ingresar tus gastos...",
/// "¿Registraste tus gastos hoy?"). Dos avisos al día, apagados por
/// defecto: se llega aquí desde Perfil, nunca se activan solos.
class RecordatoriosScreen extends ConsumerStatefulWidget {
  const RecordatoriosScreen({super.key});

  @override
  ConsumerState<RecordatoriosScreen> createState() =>
      _RecordatoriosScreenState();
}

class _RecordatoriosScreenState extends ConsumerState<RecordatoriosScreen> {
  late bool _activado;
  late int _horaMediodia;
  late int _horaNoche;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final perfil = ref.read(perfilProvider).value;
    _activado = perfil?.recordatoriosActivados ?? false;
    _horaMediodia = perfil?.horaRecordatorio1 ?? 14 * 60;
    _horaNoche = perfil?.horaRecordatorio2 ?? 20 * 60;
  }

  TimeOfDay _comoHora(int minutos) =>
      TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60);

  // --- Interruptor "Activar recordatorios": pide permiso justo al
  // encenderlo, nunca antes — si Android lo niega, no se enciende ---
  Future<void> _alternar(bool valor) async {
    if (!valor) {
      setState(() => _activado = false);
      return;
    }
    final concedido = await RecordatoriosService.pedirPermiso();
    if (!mounted) return;
    if (!concedido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activa las notificaciones de NeroMoney en Ajustes del sistema '
            'para poder mandarte estos avisos.',
          ),
        ),
      );
      return;
    }
    setState(() => _activado = true);
  }

  // --- Selector de hora: aplica al recordatorio de mediodía o al de la noche ---
  Future<void> _elegirHora({required bool esMediodia}) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _comoHora(esMediodia ? _horaMediodia : _horaNoche),
    );
    if (elegida == null) return;
    setState(() {
      final minutos = elegida.hour * 60 + elegida.minute;
      if (esMediodia) {
        _horaMediodia = minutos;
      } else {
        _horaNoche = minutos;
      }
    });
  }

  // --- Botón "Guardar cambios": persiste el perfil y programa/cancela los avisos ---
  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final repo = ref.read(perfilRepositoryProvider);
      final actual = ref.read(perfilProvider).value ?? PerfilUsuario.vacio;
      final nuevo = actual.copyWith(
        recordatoriosActivados: _activado,
        horaRecordatorio1: _horaMediodia,
        horaRecordatorio2: _horaNoche,
      );
      await repo.guardarPerfil(nuevo);
      // No solo esperar a que recordatoriosSyncProvider reaccione al
      // cambio de perfil (sí lo hace, pero esto da confirmación inmediata
      // en vez de depender de un round-trip de Firestore de por medio).
      if (_activado) {
        await RecordatoriosService.programar(
          horaMediodiaMinutos: _horaMediodia,
          horaNocheMinutos: _horaNoche,
          nombreAsistente: nuevo.nombreAsistente,
          nombreSaludo: datosDeSaludo(
            FirebaseAuth.instance.currentUser,
            nuevo.apodo,
          ).nombre,
        );
      } else {
        await RecordatoriosService.cancelarTodos();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilProvider).value;
    final nombreAsistente = perfil?.nombreAsistente ?? 'Lucy';
    final apodo = datosDeSaludo(
      FirebaseAuth.instance.currentUser,
      perfil?.apodo,
    ).nombre;

    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Interruptor principal ---
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Activar recordatorios', style: AppTextStyles.bodyLg),
                          const SizedBox(height: 4),
                          Text(
                            'Dos avisos al día para no olvidar registrar tus '
                            'gastos.',
                            style: AppTextStyles.bodySm,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _activado,
                      activeThumbColor: AppColors.primaryCyan,
                      onChanged: _alternar,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // --- Horarios: solo tienen sentido si está activado ---
              Opacity(
                opacity: _activado ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !_activado,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECORDATORIO DE MEDIODÍA', style: AppTextStyles.labelCode),
                      const SizedBox(height: 8),
                      _FilaHora(
                        hora: _comoHora(_horaMediodia),
                        onTap: () => _elegirHora(esMediodia: true),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"$nombreAsistente 👋 — Te recuerdo registrar tus '
                        'gastos para llevar tus finanzas bajo control."',
                        style: AppTextStyles.bodySm,
                      ),
                      const SizedBox(height: 24),
                      Text('RECORDATORIO DE LA NOCHE', style: AppTextStyles.labelCode),
                      const SizedBox(height: 8),
                      _FilaHora(
                        hora: _comoHora(_horaNoche),
                        onTap: () => _elegirHora(esMediodia: false),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"$nombreAsistente 👋 — Hola, $apodo. ¿Registraste tus '
                        'gastos hoy? Si no, ¿quieres hacerlo? No te toma más '
                        'de 10 minutos."',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _guardando
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCyan,
                        ),
                      ),
                    )
                  : GradientButton(label: 'Guardar cambios', onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaHora extends StatelessWidget {
  const _FilaHora({required this.hora, required this.onTap});
  final TimeOfDay hora;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: GlassCard(
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: AppColors.primaryCyan, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(hora.format(context), style: AppTextStyles.headlineSm),
            ),
            const Icon(Icons.edit_rounded, color: AppColors.textPlaceholder, size: 18),
          ],
        ),
      ),
    );
  }
}

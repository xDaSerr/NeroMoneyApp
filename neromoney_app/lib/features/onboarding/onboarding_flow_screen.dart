import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import 'data/perfil_usuario.dart';
import 'providers/perfil_providers.dart';
import 'widgets/currency_picker.dart';

/// Los 2 pasos de configuración inicial: moneda → nombre del asistente.
/// Deliberadamente NO se pide crear una cuenta aquí — eso queda para
/// cuando el usuario quiera, desde la pantalla de Cuentas (o cuando la IA
/// se lo recuerde). Menos fricción para empezar a ver la app.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _pageController = PageController();
  int _paso = 0;

  String _monedaElegida = monedasDisponibles.first.codigo;
  final _nombreAsistenteCtrl = TextEditingController(text: 'Lucy');

  bool _guardando = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nombreAsistenteCtrl.dispose();
    super.dispose();
  }

  void _irAlPaso(int paso) {
    setState(() => _paso = paso);
    _pageController.animateToPage(
      paso,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finalizar() async {
    setState(() => _guardando = true);
    try {
      final nombreAsistente = _nombreAsistenteCtrl.text.trim().isEmpty
          ? 'Lucy'
          : _nombreAsistenteCtrl.text.trim();

      await ref.read(perfilRepositoryProvider).guardarPerfil(
            PerfilUsuario(
              moneda: _monedaElegida,
              nombreAsistente: nombreAsistente,
              onboardingCompletado: true,
            ),
          );

      // El router solo re-evalúa su `redirect` ante cambios de sesión o
      // navegaciones explícitas — un cambio en Firestore no lo dispara solo.
      // Por eso navegamos "a mano" aquí; el redirect se encarga de confirmar
      // que ya puedes quedarte en /home (y de cachear que el onboarding
      // quedó completo, para no volver a consultarlo).
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la configuración: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _BarraProgreso(paso: _paso),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PasoMoneda(
                    monedaElegida: _monedaElegida,
                    onCambiar: (codigo) => setState(() => _monedaElegida = codigo),
                    onContinuar: () => _irAlPaso(1),
                  ),
                  _PasoAsistente(
                    controller: _nombreAsistenteCtrl,
                    onContinuar: _finalizar,
                    onAtras: () => _irAlPaso(0),
                    guardando: _guardando,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraProgreso extends StatelessWidget {
  const _BarraProgreso({required this.paso});
  final int paso;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(2, (i) {
          final activo = i <= paso;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: activo ? AppColors.primaryCyan : AppColors.glassStrokeStandard,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PasoMoneda extends StatelessWidget {
  const _PasoMoneda({
    required this.monedaElegida,
    required this.onCambiar,
    required this.onContinuar,
  });

  final String monedaElegida;
  final ValueChanged<String> onCambiar;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('Paso 1 de 2', style: AppTextStyles.labelCode),
          const SizedBox(height: 8),
          Text('¿En qué moneda manejas tu dinero?', style: AppTextStyles.headlineLg),
          const SizedBox(height: 6),
          Text(
            'Toda la app trabajará en esta moneda. Puedes cambiarla después en Ajustes.',
            style: AppTextStyles.bodyMd,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: monedasDisponibles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final opcion = monedasDisponibles[i];
                final seleccionada = opcion.codigo == monedaElegida;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onCambiar(opcion.codigo),
                  child: GlassCard(
                    color: seleccionada
                        ? AppColors.primaryCyan.withValues(alpha: 0.12)
                        : AppColors.surface2Glass,
                    child: Row(
                      children: [
                        Text(opcion.bandera, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opcion.codigo, style: AppTextStyles.bodyLg),
                              Text(opcion.nombre, style: AppTextStyles.bodySm),
                            ],
                          ),
                        ),
                        if (seleccionada)
                          const Icon(Icons.check_circle_rounded, color: AppColors.primaryCyan),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // --- Botón "Continuar" del paso 1 → avanza al paso 2 (no guarda todavía) ---
          GradientButton(label: 'Continuar', onPressed: onContinuar),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PasoAsistente extends StatelessWidget {
  const _PasoAsistente({
    required this.controller,
    required this.onContinuar,
    required this.onAtras,
    required this.guardando,
  });

  final TextEditingController controller;
  final VoidCallback onContinuar;
  final VoidCallback onAtras;
  final bool guardando;

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView (en vez de Spacer) para que cuando el teclado
    // reduzca el espacio disponible, el contenido se desplace en lugar de
    // desbordarse ("bottom overflowed").
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('Paso 2 de 2', style: AppTextStyles.labelCode),
          const SizedBox(height: 8),
          Text('Ponle nombre a tu asistente', style: AppTextStyles.headlineLg),
          const SizedBox(height: 6),
          Text(
            'Así le hablarás para registrar tus gastos, ej. "Lucy, gasté 200 en un café".',
            style: AppTextStyles.bodyMd,
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: AppColors.userBubbleGradient),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryCyan.withValues(alpha: 0.3), blurRadius: 30),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            style: AppTextStyles.headlineMd,
            decoration: const InputDecoration(hintText: 'Lucy'),
          ),
          const SizedBox(height: 28),
          // --- Botón "Finalizar": guarda el perfil en Firestore y navega a /home ---
          // (la lógica real está en _finalizar(), arriba en el State)
          guardando
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan))
              : GradientButton(label: 'Finalizar', onPressed: onContinuar),
          const SizedBox(height: 8),
          // --- Botón "Atrás": regresa al paso 1 sin guardar nada ---
          Center(
            child: TextButton(onPressed: guardando ? null : onAtras, child: const Text('Atrás')),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

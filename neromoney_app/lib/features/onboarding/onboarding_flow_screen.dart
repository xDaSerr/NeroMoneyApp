import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/controlador_tema.dart';
import '../../core/theme/tema_app.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../auth/providers/auth_providers.dart';
import 'data/perfil_usuario.dart';
import 'providers/perfil_providers.dart';
import 'widgets/currency_picker.dart';
import 'widgets/muestra_tema.dart';

/// Los 2 pasos de configuración inicial: moneda → color de la app.
/// El nombre del asistente ya no se pide aquí (decisión del usuario): el
/// asistente lo pregunta él mismo la primera vez que se abre (ver
/// PreguntaNombreAsistente).
/// Deliberadamente NO se pide crear una cuenta aquí — eso queda para
/// cuando el usuario quiera, desde la pantalla de Cuentas (o cuando la IA
/// se lo recuerde). Menos fricción para empezar a ver la app.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _pageController = PageController();
  int _paso = 0;

  String _monedaElegida = monedasDisponibles.first.codigo;
  // Arranca en el que ya esté aplicado (normalmente Negro).
  TemaApp _temaElegido = ControladorTema.instancia.tema;

  bool _guardando = false;

  @override
  void dispose() {
    _pageController.dispose();
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
      // A esta pantalla se llega justo después de registrarte o iniciar
      // sesión — el mismo instante en el que, alguna vez, se vio un
      // parpadeo de "sin uid" mientras Firebase terminaba de asentar la
      // sesión (ver AppShell, guardia de currentUidProvider). Si
      // perfilRepositoryProvider alcanzó a construirse en ese parpadeo,
      // Riverpod lo deja atascado en ese error para siempre, aunque la
      // sesión ya esté lista — invalidarlo aquí obliga a recalcularlo con
      // el uid actual antes de usarlo, en vez de heredar un error viejo.
      ref.invalidate(currentUidProvider);
      ref.invalidate(perfilRepositoryProvider);

      if (ref.read(currentUidProvider) == null) {
        throw StateError('Tu sesión se cerró. Vuelve a iniciar sesión.');
      }

      await ref
          .read(perfilRepositoryProvider)
          .guardarPerfil(
            PerfilUsuario(
              moneda: _monedaElegida,
              nombreAsistente: 'Lucy',
              onboardingCompletado: true,
              tema: _temaElegido,
              asistenteNombrado: false,
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
        // Mensaje amigable, nunca el volcado técnico de la excepción — un
        // ProviderException incluye su stack trace completo en el texto.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'No se pudo guardar la configuración. Revisa tu '
                        'conexión e inténtalo de nuevo.',
            ),
          ),
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
                    onCambiar: (codigo) =>
                        setState(() => _monedaElegida = codigo),
                    onContinuar: () => _irAlPaso(1),
                  ),
                  _PasoColor(
                    temaElegido: _temaElegido,
                    onCambiar: (tema) {
                      setState(() => _temaElegido = tema);
                      // La app entera cambia de color al instante: la mejor
                      // vista previa es la propia pantalla.
                      ControladorTema.instancia.cambiar(tema);
                    },
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
                color: activo
                    ? AppColors.acento
                    : AppColors.glassStrokeStandard,
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
          Text(
            '¿En qué moneda manejas tu dinero?',
            style: AppTextStyles.headlineLg,
          ),
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
                        ? AppColors.acento.withValues(alpha: 0.12)
                        : AppColors.surface2Glass,
                    child: Row(
                      children: [
                        Text(
                          opcion.bandera,
                          style: const TextStyle(fontSize: 24),
                        ),
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
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.acento,
                          ),
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

class _PasoColor extends StatelessWidget {
  const _PasoColor({
    required this.temaElegido,
    required this.onCambiar,
    required this.onContinuar,
    required this.onAtras,
    required this.guardando,
  });

  final TemaApp temaElegido;
  final ValueChanged<TemaApp> onCambiar;
  final VoidCallback onContinuar;
  final VoidCallback onAtras;
  final bool guardando;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('Paso 2 de 2', style: AppTextStyles.labelCode),
          const SizedBox(height: 8),
          Text('Elige el color de tu app', style: AppTextStyles.headlineLg),
          const SizedBox(height: 6),
          Text(
            'Cambia el fondo y los acentos de toda la app. Puedes cambiarlo '
            'después en Perfil.',
            style: AppTextStyles.bodyMd,
          ),
          const SizedBox(height: 24),
          // --- Cuadrícula de 8 colores: tocar uno lo aplica al instante ---
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.78,
            children: [
              for (final tema in TemaApp.values)
                MuestraTema(
                  tema: tema,
                  seleccionado: tema == temaElegido,
                  onTap: () => onCambiar(tema),
                ),
            ],
          ),
          const SizedBox(height: 32),
          // --- Botón "Finalizar": guarda el perfil en Firestore y navega a /home ---
          // (la lógica real está en _finalizar(), arriba en el State)
          guardando
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.acento),
                )
              : GradientButton(label: 'Finalizar', onPressed: onContinuar),
          const SizedBox(height: 8),
          // --- Botón "Atrás": regresa al paso 1 sin guardar nada ---
          Center(
            child: TextButton(
              onPressed: guardando ? null : onAtras,
              child: const Text('Atrás'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

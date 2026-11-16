import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/piezas_movil.dart' show SegmentadoMovil;
import 'data/membresia.dart';
import 'providers/planes_providers.dart';

/// Lo que incluye cada plan. [listo] = false se muestra como "Pronto":
/// nunca se vende algo que todavía no existe como si ya estuviera.
const _beneficios = <PlanNero, List<(String, bool)>>{
  PlanNero.gratis: [
    ('Cuentas y movimientos ilimitados', true),
    ('Reportes del mes', true),
    ('Los 8 temas de color', true),
    ('Lucy: 15 mensajes al mes', true),
    ('1 presupuesto y 1 meta de ahorro', true),
  ],
  PlanNero.plus: [
    ('Todo lo de Gratis', true),
    ('Lucy sin límite', true),
    ('5 fondos exclusivos para la app', true),
    ('Resumen mensual inteligente', true),
    ('Detecta suscripciones y gastos hormiga', true),
    ('Presupuestos y metas ilimitados', true),
    ('Reportes avanzados', true),
    ('Exportar a Excel / CSV', true),
  ],
  PlanNero.pro: [
    ('Todo lo de Plus', true),
    ('Foto del ticket', true),
    ('Multimoneda', true),
    ('Respaldo automático cada mes', true),
    ('Resumen y proyección del año', true),
    ('Exportar a PDF', true),
  ],
};

/// Las tres membresías, con el cobro de Plus y Pro en Polar.
class PlanesScreen extends ConsumerStatefulWidget {
  const PlanesScreen({super.key, this.vieneDePago = false});

  /// Polar regresa a /planes?pago=ok al terminar de pagar.
  final bool vieneDePago;

  @override
  ConsumerState<PlanesScreen> createState() => _PlanesScreenState();
}

class _PlanesScreenState extends ConsumerState<PlanesScreen> {
  bool _anual = false;
  PlanNero? _procesando; // plan cuyo botón está esperando al servidor
  bool _abriendoPortal = false;

  @override
  void initState() {
    super.initState();
    if (widget.vieneDePago) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias! Tu plan se activa en unos segundos.'),
          ),
        );
      });
    }
  }

  Future<void> _abrir(String url) async {
    await launchUrl(
      Uri.parse(url),
      // En la web se abre en la misma pestaña: Polar regresa aquí al final.
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }

  Future<void> _elegir(PlanNero plan) async {
    setState(() => _procesando = plan);
    try {
      final url = await ref
          .read(planesRepositoryProvider)
          .crearCheckout(plan, anual: _anual);
      await _abrir(url);
    } on FirebaseFunctionsException catch (e) {
      _avisar(e.message ?? 'No se pudo abrir el pago.');
    } catch (_) {
      _avisar('No se pudo abrir el pago. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  Future<void> _portal() async {
    setState(() => _abriendoPortal = true);
    try {
      await _abrir(await ref.read(planesRepositoryProvider).abrirPortal());
    } on FirebaseFunctionsException catch (e) {
      _avisar(e.message ?? 'No se pudo abrir tu suscripción.');
    } catch (_) {
      _avisar('No se pudo abrir tu suscripción. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _abriendoPortal = false);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final membresia = ref.watch(membresiaProvider).value ?? Membresia.gratis;
    final uso = ref.watch(usoIAProvider).value ?? const UsoIA();

    List<Widget> tarjetas({required bool enFila}) => [
      for (final (i, plan) in PlanNero.values.indexed)
        _TarjetaPlan(
              enFila: enFila,
              plan: plan,
              anual: _anual,
              membresia: membresia,
              procesando: _procesando == plan,
              bloqueado: _procesando != null || _abriendoPortal,
              onElegir: () => _elegir(plan),
              onPortal: _portal,
            )
            .animate()
            .fadeIn(delay: (70 * i).ms, duration: 300.ms)
            .slideY(begin: 0.05, curve: Curves.easeOutCubic),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Atrás',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/profile'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige tu plan',
                    style: AppTextStyles.display.copyWith(fontSize: 34),
                  ),
                  Text(
                    membresia.plan == PlanNero.gratis
                        ? 'Te quedan ${uso.restantesGratis(DateTime.now())} '
                              'mensajes gratis con Lucy este mes.'
                        : 'Tienes NeroMoney ${membresia.plan.nombre}. '
                              '¡Gracias por apoyar el proyecto!',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: SegmentadoMovil<bool>(
                        opciones: const {
                          false: 'Mensual',
                          true: 'Anual · ahorra 17%',
                        },
                        valor: _anual,
                        onCambiar: (v) => setState(() => _anual = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) => c.maxWidth >= 860
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final (i, t) in tarjetas(
                                  enFila: true,
                                ).indexed) ...[
                                  if (i > 0) const SizedBox(width: 16),
                                  Expanded(child: t),
                                ],
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (i, t) in tarjetas(
                                enFila: false,
                              ).indexed) ...[
                                if (i > 0) const SizedBox(height: 14),
                                t,
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 22),
                  if (membresia.tieneCuentaDePago)
                    Center(
                      child: TextButton.icon(
                        onPressed: _abriendoPortal ? null : _portal,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Administrar suscripción'),
                      ),
                    ),
                  Text(
                    'Pagos procesados por Polar. Cancela cuando quieras desde '
                    '"Administrar suscripción"; conservas tu plan hasta el '
                    'final del periodo pagado.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textPlaceholder,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({
    required this.plan,
    required this.anual,
    required this.membresia,
    required this.procesando,
    required this.bloqueado,
    required this.onElegir,
    required this.onPortal,
    this.enFila = false,
  });

  /// En fila (pantalla ancha) las tarjetas miden lo mismo y el botón se
  /// alinea abajo; en columna cada una mide lo suyo.
  final bool enFila;
  final PlanNero plan;
  final bool anual;
  final Membresia membresia;
  final bool procesando;
  final bool bloqueado;
  final VoidCallback onElegir;
  final VoidCallback onPortal;

  @override
  Widget build(BuildContext context) {
    final esActual = membresia.plan == plan;
    final destacado = plan == PlanNero.plus;
    final precio = anual ? plan.precioAnual : plan.precioMensual;

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      color: destacado ? AppColors.acento.withValues(alpha: 0.08) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.nombre, style: AppTextStyles.headlineLg),
              const Spacer(),
              if (esActual)
                const _Etiqueta(texto: 'Tu plan')
              else if (destacado)
                const _Etiqueta(texto: 'Recomendado'),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            plan.lema,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                precio == 0 ? '\$0' : '\$${precio.toStringAsFixed(2)}',
                style: AppTextStyles.display.copyWith(fontSize: 36),
              ),
              const SizedBox(width: 6),
              Text(
                precio == 0
                    ? 'para siempre'
                    : (anual ? 'USD al año' : 'USD al mes'),
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (anual && precio > 0)
            Text(
              'Equivale a \$${(precio / 12).toStringAsFixed(2)} al mes',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.acento),
            ),
          const SizedBox(height: 18),
          for (final (texto, listo) in _beneficios[plan]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    listo ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    size: 20,
                    color: listo ? AppColors.acento : AppColors.textPlaceholder,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: listo
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (!listo) const _Etiqueta(texto: 'Pronto', tenue: true),
                ],
              ),
            ),
          if (enFila) const Spacer(),
          if (_boton() case final boton?) ...[
            const SizedBox(height: 10),
            boton,
          ],
          if (esActual &&
              membresia.cancelaAlFinal &&
              membresia.periodoFin != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Cancelado: lo conservas hasta el '
                '${membresia.periodoFin!.day} de '
                '${mesesEs[membresia.periodoFin!.month - 1]}.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// null = sin botón (Gratis cuando ya pagas: cancelar vive en
  /// "Administrar suscripción" y el aviso de fin, en la tarjeta del plan).
  Widget? _boton() {
    final pagaAlgo = membresia.plan != PlanNero.gratis;
    if (membresia.plan == plan) {
      if (pagaAlgo && membresia.cancelaAlFinal) {
        // Se arrepintió: en el portal se deshace la cancelación.
        return _BotonPlan(
          texto: 'Reactivar suscripción',
          onTap: bloqueado ? null : onPortal,
        );
      }
      return _BotonPlan(texto: 'Plan actual', onTap: null);
    }
    if (plan == PlanNero.gratis) return null;
    if (pagaAlgo) {
      // De Plus a Pro (o al revés) se cambia en el portal, sin doble cobro.
      return _BotonPlan(
        texto: 'Cambiar a ${plan.nombre}',
        onTap: bloqueado ? null : onPortal,
      );
    }
    return _BotonPlan(
      texto: 'Elegir ${plan.nombre}',
      relleno: true,
      cargando: procesando,
      onTap: bloqueado ? null : onElegir,
    );
  }
}

class _BotonPlan extends StatelessWidget {
  const _BotonPlan({
    required this.texto,
    required this.onTap,
    this.relleno = false,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? onTap;
  final bool relleno;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final hijo = cargando
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: relleno ? AppColors.sobreAcento : AppColors.acento,
            ),
          )
        : Text(
            texto,
            style: AppTextStyles.bodyLg.copyWith(
              fontWeight: FontWeight.w700,
              color: relleno
                  ? AppColors.sobreAcento
                  : (onTap == null
                        ? AppColors.textPlaceholder
                        : AppColors.acento),
            ),
          );
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const espacio = EdgeInsets.symmetric(vertical: 16);
    return SizedBox(
      width: double.infinity,
      child: relleno
          ? FilledButton(
              onPressed: cargando ? () {} : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.acento,
                foregroundColor: AppColors.sobreAcento,
                padding: espacio,
                shape: forma,
                textStyle: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: hijo,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
                padding: espacio,
                shape: forma,
                side: BorderSide(
                  color: onTap == null
                      ? AppColors.glassStrokeStandard
                      : AppColors.acento.withValues(alpha: 0.7),
                ),
              ),
              child: hijo,
            ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, this.tenue = false});

  final String texto;
  final bool tenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tenue
            ? AppColors.surface3ActiveGlass
            : AppColors.acento.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: AppTextStyles.bodySm.copyWith(
          color: tenue ? AppColors.textSecondary : AppColors.acento,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

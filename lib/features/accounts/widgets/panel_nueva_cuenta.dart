import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dialogo_formulario.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../../onboarding/widgets/currency_picker.dart';
import '../../planes/data/membresia.dart';
import '../../planes/providers/planes_providers.dart';
import '../../planes/widgets/aviso_plan.dart';
import '../data/cuenta.dart';
import '../providers/cuentas_providers.dart';
import 'cuenta_movil.dart';
import 'estilo_cuenta.dart';

/// "Nueva cuenta" en el panel que sale de un botón "+" (ver BotonConPanel).
/// Misma lógica que CuentaFormCard: el nombre se autocompleta solo en
/// Efectivo, y en crédito el límite es obligatorio (sin él no se puede
/// calcular la deuda, ver Cuenta.deudaActual).
class PanelNuevaCuenta extends ConsumerStatefulWidget {
  const PanelNuevaCuenta({super.key, required this.onCerrar});

  final VoidCallback onCerrar;

  @override
  ConsumerState<PanelNuevaCuenta> createState() => _PanelNuevaCuentaState();
}

class _PanelNuevaCuentaState extends ConsumerState<PanelNuevaCuenta> {
  final _nombre = TextEditingController(text: TipoCuenta.efectivo.etiqueta);
  final _saldo = TextEditingController();
  final _limite = TextEditingController();

  /// Últimos 4 dígitos (débito y crédito): para distinguir, por ejemplo, la
  /// tarjeta física de la digital del mismo banco. Nunca el número completo.
  final _digitos = TextEditingController();
  TipoCuenta _tipo = TipoCuenta.efectivo;
  String? _moneda; // null = la moneda principal del perfil
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_nombre, _saldo, _limite, _digitos]) {
      c.addListener(_refrescar);
    }
  }

  /// La vista previa sigue lo que se escribe, y un error ya corregido se
  /// quita en cuanto el usuario vuelve a escribir.
  void _refrescar() {
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _saldo.dispose();
    _limite.dispose();
    _digitos.dispose();
    super.dispose();
  }

  void _elegirTipo(TipoCuenta tipo) {
    final actual = _nombre.text.trim();
    final esPorDefecto =
        actual.isEmpty || actual == TipoCuenta.efectivo.etiqueta;
    setState(() {
      _tipo = tipo;
      // Si el usuario ya escribió un nombre propio, no se toca.
      if (!esPorDefecto) return;
      // Solo "Efectivo" se autocompleta; los demás llevan el nombre del
      // banco o tarjeta, que el usuario escribe.
      if (tipo == TipoCuenta.efectivo) {
        _nombre.text = tipo.etiqueta;
      } else {
        _nombre.clear();
      }
    });
  }

  double? _numero(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _crear() async {
    final nombre = _nombre.text.trim();
    final saldo = _numero(_saldo);
    final esCredito = _tipo == TipoCuenta.credito;
    final limite = _numero(_limite);
    final esTarjeta = _tipo == TipoCuenta.credito || _tipo == TipoCuenta.debito;
    final digitos = esTarjeta ? _digitos.text.trim() : '';
    final falta = nombre.isEmpty
        ? 'Escribe un nombre para la cuenta.'
        : saldo == null
        ? (esCredito
              ? 'Escribe tu disponible actual.'
              : 'Escribe el saldo actual.')
        : esCredito && limite == null
        ? 'En una tarjeta de crédito el límite es obligatorio.'
        : digitos.isNotEmpty && digitos.length != 4
        ? 'Escribe los 4 dígitos completos o deja el campo vacío.'
        : null;
    if (falta != null) {
      setState(() => _error = falta);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(cuentasRepositoryProvider)
          .crearCuenta(
            Cuenta(
              id: '', // Firestore le asigna el id real al crearla.
              nombre: nombre,
              tipo: _tipo,
              saldoActual: saldo!,
              limiteCredito: esCredito ? limite : null,
              moneda: _moneda,
              ultimos4Digitos: digitos.isEmpty ? null : digitos,
            ),
          );
      widget.onCerrar();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo crear la cuenta. Revisa tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Otra moneda distinta a la principal es de Pro.
  void _elegirMoneda(String codigo, String principal) {
    if (codigo == principal) {
      setState(() => _moneda = null);
      return;
    }
    final plan = ref.read(membresiaProvider).value?.plan ?? PlanNero.gratis;
    if (plan != PlanNero.pro) {
      mostrarAvisoPlan(
        context,
        plan: PlanNero.pro,
        titulo: 'Cuentas en otras monedas con Pro',
        mensaje:
            'Con NeroMoney Pro puedes tener cuentas en dólares, euros y '
            'más, y tu patrimonio se convierte solo a $principal.',
      );
      return;
    }
    setState(() => _moneda = codigo);
  }

  @override
  Widget build(BuildContext context) {
    final esCredito = _tipo == TipoCuenta.credito;
    final esTarjeta = esCredito || _tipo == TipoCuenta.debito;
    final principal = ref.watch(perfilProvider).value?.moneda ?? 'MXN';
    final moneda = _moneda ?? principal;
    final angosto = MediaQuery.sizeOf(context).width < 700;
    final nombre = _nombre.text.trim();
    final saldo = _numero(_saldo) ?? 0;

    // Así se verá en "Cuentas" (mismo widget que la lista).
    final vistaPrevia = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'VISTA PREVIA',
          style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: angosto ? 130 : 170,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: CuentaMovil(
              key: ValueKey(_tipo),
              ocultar: false,
              cuenta: Cuenta(
                id: '',
                nombre: nombre.isEmpty ? _tipo.etiqueta : nombre,
                tipo: _tipo,
                saldoActual: saldo,
                limiteCredito: esCredito ? (_numero(_limite) ?? 0) : null,
                ultimos4Digitos: esTarjeta && _digitos.text.trim().isNotEmpty
                    ? _digitos.text.trim()
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          moneda == principal
              ? 'Así se verá en tus cuentas.'
              : 'Así se verá en tus cuentas (en $moneda).',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );

    final campos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoEtiquetado(
          etiqueta: 'Nombre de la cuenta',
          child: TextField(
            controller: _nombre,
            autofocus: !angosto,
            textCapitalization: TextCapitalization.words,
            style: AppTextStyles.bodyLg,
            decoration: decoracionCampo(pista: 'ej. TC de Nu'),
          ),
        ),
        const SizedBox(height: 16),
        CampoEtiquetado(
          etiqueta: esCredito ? 'Disponible actual' : 'Saldo actual',
          ayuda: esCredito
              ? 'Lo que te queda disponible de tu línea de crédito.'
              : 'El dinero que tienes en esta cuenta hoy.',
          child: TextField(
            controller: _saldo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.bodyLg,
            onSubmitted: (_) => _crear(),
            decoration: decoracionCampo(
              pista: '0.00',
              prefijo: r'$',
              sufijo: moneda,
            ),
          ),
        ),
        if (esCredito) ...[
          const SizedBox(height: 16),
          CampoEtiquetado(
            etiqueta: 'Límite de crédito',
            ayuda:
                'La deuda se calcula sola (límite − disponible). Si pagas o '
                'te suben el límite, actualízalo desde Cuentas → Editar.',
            child: TextField(
              controller: _limite,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTextStyles.bodyLg,
              onSubmitted: (_) => _crear(),
              decoration: decoracionCampo(
                pista: '0.00',
                prefijo: r'$',
                sufijo: moneda,
              ),
            ),
          ),
        ],
        // --- Últimos 4 dígitos: solo tarjetas (débito y crédito) ---
        if (esTarjeta) ...[
          const SizedBox(height: 16),
          CampoEtiquetado(
            etiqueta: 'Últimos 4 dígitos (recomendado)',
            ayuda:
                'Para distinguir tarjetas del mismo banco (física y '
                'digital). Nunca pedimos el número completo.',
            child: TextField(
              controller: _digitos,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: AppTextStyles.bodyLg.copyWith(letterSpacing: 3),
              decoration: decoracionCampo(pista: 'ej. 4821', prefijo: '•••• '),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // --- Moneda: otra distinta a la principal es de Pro. No se puede
        // cambiar después (los saldos quedarían mal interpretados). ---
        CampoEtiquetado(
          etiqueta: 'Moneda',
          child: SelectorCampo<String>(
            key: ValueKey('moneda-$moneda'),
            valor: moneda,
            opciones: {
              for (final m in monedasDisponibles)
                m.codigo: '${m.bandera}  ${m.codigo} · ${m.nombre}',
            },
            onCambiar: (m) => _elegirMoneda(m, principal),
          ),
        ),
      ],
    );

    return DialogoFormulario(
      icono: Icons.add_card_rounded,
      titulo: 'Nueva cuenta',
      subtitulo: 'Organiza tu dinero en un solo lugar.',
      onCerrar: widget.onCerrar,
      textoAccion: 'Crear cuenta',
      iconoAccion: Icons.add_rounded,
      onAccion: _crear,
      cargando: _guardando,
      error: _error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tipo de cuenta',
            style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          // --- Tipo: 5 tarjetas con ícono ---
          Row(
            children: [
              for (final (i, t) in TipoCuenta.values.indexed) ...[
                if (i > 0) SizedBox(width: angosto ? 6 : 12),
                Expanded(
                  child: _TarjetaTipo(
                    tipo: t,
                    activo: t == _tipo,
                    compacta: angosto,
                    onTap: () => _elegirTipo(t),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.glassStrokeStandard),
          const SizedBox(height: 20),
          if (angosto) ...[
            campos,
            const SizedBox(height: 22),
            vistaPrevia,
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 11, child: campos),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: VerticalDivider(
                      width: 1,
                      color: AppColors.glassStrokeStandard,
                    ),
                  ),
                  Expanded(
                    flex: 9,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: vistaPrevia,
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

class _TarjetaTipo extends StatelessWidget {
  const _TarjetaTipo({
    required this.tipo,
    required this.activo,
    required this.compacta,
    required this.onTap,
  });

  final TipoCuenta tipo;
  final bool activo;
  final bool compacta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: tipo.etiqueta,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(vertical: compacta ? 12 : 18),
            decoration: BoxDecoration(
              color: activo
                  ? AppColors.acento.withValues(alpha: 0.12)
                  : AppColors.surface2Glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activo
                    ? AppColors.acento
                    : AppColors.glassStrokeHighlight,
                width: activo ? 2 : 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconoDeTipo(tipo),
                        size: compacta ? 24 : 32,
                        color: activo
                            ? AppColors.acento
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tipo.etiqueta,
                          style: AppTextStyles.bodyLg.copyWith(
                            fontSize: compacta ? 13 : 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (activo)
                  Positioned(
                    top: compacta ? -6 : -10,
                    right: compacta ? 4 : 8,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: compacta ? 16 : 22,
                      color: AppColors.acento,
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

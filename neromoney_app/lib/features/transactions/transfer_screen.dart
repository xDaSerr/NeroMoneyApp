import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import 'data/transacciones_repository.dart';
import 'providers/transacciones_providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _form = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  String? _origenId;
  String? _destinoId;
  ({
    String id,
    String origen,
    String destino,
    double monto,
    String nota,
    DateTime fecha,
  })?
  _pendiente;
  bool _guardando = false;
  bool get _bloquearEdicion => _guardando || _pendiente != null;
  String? _error;

  // La misma interpretación en la validación y en la vista previa. No se
  // admiten separadores de miles ambiguos ni fracciones de centavo.
  double? get _importe {
    final texto = _monto.text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(texto)) return null;
    final numero = double.tryParse(texto);
    return numero != null && numero > 0 ? numero : null;
  }

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_pendiente == null && !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repositorio = ref.read(transaccionesRepositoryProvider);
      // Si la confirmación se pierde, reintentar el mismo registro aun cuando
      // los streams ya muestren saldos actualizados (incluso origen en cero).
      final pendiente = _pendiente ??= (
        id: repositorio.nuevaTransferenciaId(),
        origen: _origenId!,
        destino: _destinoId!,
        monto: _importe!,
        nota: _nota.text,
        fecha: DateTime.now(),
      );
      await repositorio.registrarTransferencia(
        id: pendiente.id,
        cuentaOrigenId: pendiente.origen,
        cuentaDestinoId: pendiente.destino,
        monto: pendiente.monto,
        nota: pendiente.nota,
        fecha: pendiente.fecha,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transferencia registrada entre tus cuentas.'),
        ),
      );
      context.pop();
    } on SaldoInsuficienteException catch (e) {
      _pendiente = null;
      if (mounted) setState(() => _error = e.toString());
    } on StateError catch (e) {
      _pendiente = null;
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar la transferencia. Revisa tu conexión y vuelve a intentarlo con los mismos datos.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(cuentasProvider);
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transferir entre cuentas')),
        body: SafeArea(
          child: cuentasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(cuentasProvider),
                child: const Text(
                  'No se pudieron cargar las cuentas. Reintentar',
                ),
              ),
            ),
            data: (todas) {
              final cuentas = todas
                  .where((c) => c.permiteTransferencias)
                  .toList();
              if (cuentas.length < 2) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Necesitas dos cuentas',
                        style: AppTextStyles.headlineSm,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Agrega al menos dos cuentas de débito o efectivo para registrar una transferencia.',
                        style: AppTextStyles.bodyMd,
                      ),
                      const SizedBox(height: 24),
                      // --- Botón "Ir a Cuentas": permite agregar la cuenta que falta ---
                      GradientButton(
                        label: 'Ir a Cuentas',
                        onPressed: () => context.go('/accounts'),
                      ),
                    ],
                  ),
                );
              }
              final origen = cuentas
                  .where((c) => c.id == _origenId)
                  .firstOrNull;
              final destino = cuentas
                  .where((c) => c.id == _destinoId)
                  .firstOrNull;
              final importe = _importe;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mueve tu dinero, conserva tu patrimonio.',
                        style: AppTextStyles.headlineSm,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registra un retiro, depósito o traspaso que ya realizaste. NeroMoney solo actualiza tus registros; no envía dinero al banco.',
                        style: AppTextStyles.bodySm,
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        child: Column(
                          children: [
                            // --- Cuenta de origen: de dónde sale el dinero ---
                            _selector(
                              'Desde',
                              origen,
                              cuentas,
                              (id) => setState(() {
                                _origenId = id;
                                if (_destinoId == id) _destinoId = null;
                              }),
                            ),
                            if (origen != null)
                              _saldo('Disponible', origen.saldoActual),
                            // --- Invertir: intercambia origen y destino ---
                            IconButton(
                              tooltip: 'Invertir cuentas',
                              color: AppColors.primaryCyan,
                              onPressed: _bloquearEdicion
                                  ? null
                                  : () => setState(() {
                                      final anterior = _origenId;
                                      _origenId = _destinoId;
                                      _destinoId = anterior;
                                    }),
                              icon: const Icon(Icons.swap_vert_rounded),
                            ),
                            // --- Cuenta de destino: dónde entra el dinero ---
                            _selector(
                              'Hacia',
                              destino,
                              cuentas.where((c) => c.id != origen?.id).toList(),
                              (id) => setState(() => _destinoId = id),
                            ),
                            if (destino != null)
                              _saldo('Saldo actual', destino.saldoActual),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // --- Importe: valida centavos y saldo antes de guardar ---
                      TextFormField(
                        controller: _monto,
                        enabled: !_bloquearEdicion,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: AppTextStyles.headlineMd,
                        decoration: const InputDecoration(
                          labelText: 'Monto',
                          prefixText: '\$',
                          hintText: '0.00',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (_) {
                          if (_importe == null) {
                            return 'Escribe un monto mayor a cero, con hasta 2 decimales.';
                          }
                          if (origen != null &&
                              (_importe! * 100).round() >
                                  (origen.saldoActual * 100).round()) {
                            return 'Saldo insuficiente en la cuenta de origen.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // --- Nota opcional: ayuda a identificar el traspaso en Movimientos ---
                      TextFormField(
                        controller: _nota,
                        enabled: !_bloquearEdicion,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nota (opcional)',
                          hintText: 'Ej. Retiro en cajero',
                        ),
                      ),
                      if (origen != null &&
                          destino != null &&
                          importe != null &&
                          (importe * 100).round() <=
                              (origen.saldoActual * 100).round()) ...[
                        const SizedBox(height: 12),
                        // --- Vista previa: saldos que quedarán al registrar ---
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Así quedarán tus cuentas',
                                style: AppTextStyles.bodyLg,
                              ),
                              _saldo(
                                origen.nombre,
                                ((origen.saldoActual * 100).round() -
                                        (importe * 100).round()) /
                                    100,
                              ),
                              _saldo(
                                destino.nombre,
                                ((destino.saldoActual * 100).round() +
                                        (importe * 100).round()) /
                                    100,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tu patrimonio total no cambia. No cuenta como ingreso ni gasto.',
                                style: AppTextStyles.bodySm,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _error!,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.outflowCrimson,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // --- Registrar: confirma ambas cuentas en una sola operación ---
                      _guardando
                          ? const Center(child: CircularProgressIndicator())
                          : GradientButton(
                              label: _pendiente == null
                                  ? 'Registrar transferencia'
                                  : 'Reintentar confirmación',
                              onPressed: _guardar,
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _selector(
    String etiqueta,
    Cuenta? seleccionada,
    List<Cuenta> cuentas,
    ValueChanged<String?> cambiar,
  ) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$etiqueta-${seleccionada?.id}'),
      initialValue: seleccionada?.id,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta),
      items: cuentas
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(
                '${c.nombre} · ${c.tipo.etiqueta}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _bloquearEdicion ? null : cambiar,
      validator: (_) => seleccionada == null ? 'Elige una cuenta.' : null,
    );
  }

  Widget _saldo(String etiqueta, double saldo) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Expanded(child: Text(etiqueta, style: AppTextStyles.bodySm)),
        const SizedBox(width: 8),
        Text('\$${saldo.toStringAsFixed(2)}', style: AppTextStyles.bodyMd),
      ],
    ),
  );
}

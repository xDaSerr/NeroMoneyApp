import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../accounts/providers/cuentas_providers.dart';
import 'data/categoria.dart';
import 'data/transaccion.dart';
import 'data/transacciones_repository.dart';
import 'providers/transacciones_providers.dart';

/// Alta manual de un movimiento — la alternativa a decírselo al asistente
/// por texto/voz. Mismo resultado final: una Transaccion en Firestore y el
/// saldo de la cuenta ajustado atómicamente (ver TransaccionesRepository).
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.tipoInicial});

  /// Permite abrir la pantalla ya en "Gasto" o "Ingreso" — lo usan los
  /// accesos rápidos de Inicio (ver home_screen.dart) para ahorrar un tap.
  final TipoTransaccion? tipoInicial;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _montoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  TipoTransaccion _tipo = TipoTransaccion.gasto;
  String? _categoria;
  String? _cuentaId;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // No se puede leer `widget` en el inicializador de un campo (todavía no
    // está asociado al State en ese punto) — por eso el valor por defecto
    // vive arriba y este ajuste se hace aquí, en initState.
    final tipoInicial = widget.tipoInicial;
    if (tipoInicial != null) _tipo = tipoInicial;
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  List<Categoria> get _categoriasDisponibles =>
      _tipo == TipoTransaccion.gasto ? categoriasGasto : categoriasIngreso;

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0 || _categoria == null || _cuentaId == null) return;

    setState(() => _guardando = true);
    try {
      await ref.read(transaccionesRepositoryProvider).registrarTransaccion(
            Transaccion(
              id: '',
              monto: monto,
              tipo: _tipo,
              categoria: _categoria!,
              descripcion: _descripcionCtrl.text.trim(),
              cuentaId: _cuentaId!,
              fecha: _fecha,
            ),
          );
      if (mounted) context.pop();
    } on SaldoInsuficienteException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el movimiento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo movimiento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Toggle Gasto / Ingreso (define qué categorías se muestran abajo) ---
              Row(
                children: [
                  Expanded(
                    child: _ToggleTipoBoton(
                      label: 'Gasto',
                      color: AppColors.outflowCrimson,
                      seleccionado: _tipo == TipoTransaccion.gasto,
                      onTap: () => setState(() {
                        _tipo = TipoTransaccion.gasto;
                        _categoria = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ToggleTipoBoton(
                      label: 'Ingreso',
                      color: AppColors.inflowEmerald,
                      seleccionado: _tipo == TipoTransaccion.ingreso,
                      onTap: () => setState(() {
                        _tipo = TipoTransaccion.ingreso;
                        _categoria = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Campo de monto (estilo "numericHero", grande y en JetBrains Mono) ---
              Text('MONTO', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.numericHero,
                decoration: const InputDecoration(hintText: r'$0.00'),
              ),
              const SizedBox(height: 24),

              // --- Chips de categoría (la lista viene de data/categoria.dart) ---
              Text('CATEGORÍA', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoriasDisponibles.map((cat) {
                  final seleccionada = cat.nombre == _categoria;
                  return ChoiceChip(
                    avatar: Icon(cat.icono,
                        size: 18,
                        color: seleccionada ? AppColors.primaryCyan : AppColors.textSecondary),
                    label: Text(cat.nombre),
                    selected: seleccionada,
                    onSelected: (_) => setState(() => _categoria = cat.nombre),
                    selectedColor: AppColors.primaryCyan.withValues(alpha: 0.2),
                    backgroundColor: AppColors.surface3ActiveGlass,
                    labelStyle: AppTextStyles.bodySm.copyWith(
                      color: seleccionada ? AppColors.primaryCyan : AppColors.textSecondary,
                    ),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // --- Chips de cuenta (de qué cuenta sale/entra el dinero) ---
              Text('CUENTA', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              cuentasAsync.when(
                data: (cuentas) {
                  if (cuentas.isEmpty) {
                    return Text(
                      'Todavía no tienes cuentas. Agrega una primero desde Inicio.',
                      style: AppTextStyles.bodyMd,
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cuentas.map((cuenta) {
                      final seleccionada = cuenta.id == _cuentaId;
                      return ChoiceChip(
                        label: Text(cuenta.nombre),
                        selected: seleccionada,
                        onSelected: (_) => setState(() => _cuentaId = cuenta.id),
                        selectedColor: AppColors.primaryCyan.withValues(alpha: 0.2),
                        backgroundColor: AppColors.surface3ActiveGlass,
                        labelStyle: AppTextStyles.bodySm.copyWith(
                          color: seleccionada ? AppColors.primaryCyan : AppColors.textSecondary,
                        ),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(color: AppColors.primaryCyan),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // --- Descripción libre (opcional) ---
              Text('DESCRIPCIÓN (opcional)', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _descripcionCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyLg,
                decoration: const InputDecoration(hintText: 'ej. Café con amigos'),
              ),
              const SizedBox(height: 24),

              // --- Botón de fecha: abre el selector de fecha nativo (showDatePicker) ---
              Text('FECHA', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text('${_fecha.day}/${_fecha.month}/${_fecha.year}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                  side: const BorderSide(color: AppColors.glassStrokeStandard),
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // --- Botón principal "Guardar movimiento" (llama a _guardar) ---
              _guardando
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan))
                  : GradientButton(label: 'Guardar movimiento', onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTipoBoton extends StatelessWidget {
  const _ToggleTipoBoton({
    required this.label,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.18) : AppColors.surface3ActiveGlass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: seleccionado ? color : AppColors.glassStrokeStandard),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyLg.copyWith(
            color: seleccionado ? color : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

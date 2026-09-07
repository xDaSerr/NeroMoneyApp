import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/cuenta.dart';
import '../data/paleta_cuentas.dart';

/// Abre la hoja para editar una cuenta existente: nombre, dinero, y los
/// datos opcionales (fecha de corte, límite de pago, últimos 4 dígitos,
/// color) — todo lo que no hace falta desde el alta rápida pero sí es útil
/// tener después, ya que la cuenta existe de verdad.
///
/// Es también la forma de "resincronizar" una tarjeta de crédito cuando el
/// usuario la paga o el banco le sube el límite: NeroMoney no lo detecta
/// solo (no hace vinculación bancaria real, ver CLAUDE.md → "Filosofía
/// sobre tarjetas de crédito"), así que dejamos que el usuario lo diga a mano.
Future<void> mostrarEditorDeCuenta({
  required BuildContext context,
  required Cuenta cuenta,
  required ValueChanged<Cuenta> onGuardar,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _EditarCuentaSheet(cuenta: cuenta, onGuardar: onGuardar),
  );
}

class _EditarCuentaSheet extends StatefulWidget {
  const _EditarCuentaSheet({required this.cuenta, required this.onGuardar});

  final Cuenta cuenta;
  final ValueChanged<Cuenta> onGuardar;

  @override
  State<_EditarCuentaSheet> createState() => _EditarCuentaSheetState();
}

class _EditarCuentaSheetState extends State<_EditarCuentaSheet> {
  late final _nombreCtrl = TextEditingController(text: widget.cuenta.nombre);
  late final _saldoCtrl =
      TextEditingController(text: widget.cuenta.saldoActual.toStringAsFixed(2));
  late final _limiteCtrl =
      TextEditingController(text: widget.cuenta.limiteCredito?.toStringAsFixed(2) ?? '');
  late final _corteCtrl = TextEditingController(text: widget.cuenta.diaCorte?.toString() ?? '');
  late final _limitePagoCtrl =
      TextEditingController(text: widget.cuenta.diaLimitePago?.toString() ?? '');
  late final _digitosCtrl = TextEditingController(text: widget.cuenta.ultimos4Digitos ?? '');
  late int? _colorElegido = widget.cuenta.colorPersonalizado;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _saldoCtrl.dispose();
    _limiteCtrl.dispose();
    _corteCtrl.dispose();
    _limitePagoCtrl.dispose();
    _digitosCtrl.dispose();
    super.dispose();
  }

  // --- Botón "Guardar cambios": valida y llama a onGuardar (actualizarCuenta) ---
  void _guardar() {
    final esCredito = widget.cuenta.tipo == TipoCuenta.credito;
    final nombre = _nombreCtrl.text.trim();
    final saldo = double.tryParse(_saldoCtrl.text.replaceAll(',', '.'));
    final limite = double.tryParse(_limiteCtrl.text.replaceAll(',', '.'));
    if (nombre.isEmpty || saldo == null) return;
    if (esCredito && limite == null) return; // límite sigue siendo obligatorio en crédito

    final digitos = _digitosCtrl.text.trim();

    widget.onGuardar(widget.cuenta.copyWith(
      nombre: nombre,
      saldoActual: saldo,
      limiteCredito: esCredito ? limite : null,
      diaCorte: int.tryParse(_corteCtrl.text),
      diaLimitePago: int.tryParse(_limitePagoCtrl.text),
      ultimos4Digitos: digitos.isEmpty ? null : digitos,
      colorPersonalizado: _colorElegido,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esCredito = widget.cuenta.tipo == TipoCuenta.credito;
    // Los últimos 4 dígitos son útiles para cualquier tarjeta (crédito o
    // débito) — para diferenciar, ej., la física de la digital del mismo
    // banco. En efectivo/vale no aplica (no hay tarjeta que confundir).
    final esTarjeta = esCredito || widget.cuenta.tipo == TipoCuenta.debito;

    return Padding(
      // Empuja la hoja arriba del teclado cuando aparece.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.glassStrokeStandard),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Editar cuenta', style: AppTextStyles.headlineSm),
                const SizedBox(height: 16),
                // --- Nombre de la cuenta ---
                TextField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: AppTextStyles.bodyLg,
                  decoration: const InputDecoration(hintText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                // --- Saldo / disponible: aquí es donde el usuario resincroniza
                // el número tras pagar la tarjeta ---
                TextField(
                  controller: _saldoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTextStyles.bodyLg,
                  decoration: InputDecoration(
                    hintText: esCredito ? 'Disponible actual' : 'Saldo actual',
                  ),
                ),
                // --- Límite: solo si es tarjeta de crédito, aquí es donde se
                // resincroniza tras un aumento de línea ---
                if (esCredito) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _limiteCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTextStyles.bodyLg,
                    decoration: const InputDecoration(hintText: 'Límite de crédito'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Actualiza estos dos números cuando pagues la tarjeta o el banco '
                    'te suba el límite — NeroMoney no lo detecta solo.',
                    style: AppTextStyles.bodySm,
                  ),
                  const SizedBox(height: 16),
                  // --- Fecha de corte y límite de pago: 100% opcionales, solo de
                  // referencia — la app nunca los usa para calcular ni recordar nada ---
                  Text('DATOS DE REFERENCIA (OPCIONALES)', style: AppTextStyles.labelCode),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _corteCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: AppTextStyles.bodyLg,
                          decoration: const InputDecoration(hintText: 'Día de corte (1-31)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _limitePagoCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: AppTextStyles.bodyLg,
                          decoration: const InputDecoration(hintText: 'Día límite de pago'),
                        ),
                      ),
                    ],
                  ),
                ],
                // --- Últimos 4 dígitos: recomendado, NUNCA obligatorio — para
                // diferenciar una tarjeta física de una digital del mismo banco ---
                if (esTarjeta) ...[
                  const SizedBox(height: 16),
                  Text('ÚLTIMOS 4 DÍGITOS (RECOMENDADO)', style: AppTextStyles.labelCode),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _digitosCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: AppTextStyles.bodyLg,
                    decoration: const InputDecoration(hintText: 'ej. 4821'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Útil si el mismo banco te dio una tarjeta física y otra digital — '
                    'así las distingues a simple vista. Nunca pedimos el número completo.',
                    style: AppTextStyles.bodySm,
                  ),
                ],
                const SizedBox(height: 16),
                // --- Color de la cuenta: personalización visual, opcional ---
                Text('COLOR (OPCIONAL)', style: AppTextStyles.labelCode),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final color in paletaColoresCuentas)
                      GestureDetector(
                        onTap: () => setState(
                          () => _colorElegido = _colorElegido == color.toARGB32() ? null : color.toARGB32(),
                        ),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _colorElegido == color.toARGB32()
                                  ? AppColors.textPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: _colorElegido == color.toARGB32()
                              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                GradientButton(label: 'Guardar cambios', onPressed: _guardar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

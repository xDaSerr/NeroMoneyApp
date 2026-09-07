import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/cuenta.dart';

/// Capitaliza la primera letra de cada palabra mientras se escribe (ej.
/// "tc de nu" → "Tc De Nu"). Se aplica en tiempo real al texto, no solo como
/// sugerencia del teclado, para que quede igual sin importar cómo se
/// escriba (teclado físico, pegar texto, dictado, etc.).
class _CapitalizarPalabrasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final texto = newValue.text;
    if (texto.isEmpty) return newValue;
    final capitalizado = texto
        .split(' ')
        .map((palabra) => palabra.isEmpty
            ? palabra
            : palabra[0].toUpperCase() + palabra.substring(1))
        .join(' ');
    return newValue.copyWith(text: capitalizado);
  }
}

/// Formulario para dar de alta una cuenta/bolsillo de dinero. Se usa tanto
/// en el onboarding (opcional) como en la pantalla de Cuentas — un solo
/// lugar donde mantener esta lógica.
class CuentaFormCard extends StatefulWidget {
  const CuentaFormCard({super.key, required this.onAgregar});

  final ValueChanged<Cuenta> onAgregar;

  @override
  State<CuentaFormCard> createState() => _CuentaFormCardState();
}

class _CuentaFormCardState extends State<CuentaFormCard> {
  final _nombreCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  final _limiteCtrl = TextEditingController();
  TipoCuenta _tipo = TipoCuenta.efectivo;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _saldoCtrl.dispose();
    _limiteCtrl.dispose();
    super.dispose();
  }

  void _seleccionarTipo(TipoCuenta tipo) {
    final nombreActual = _nombreCtrl.text.trim();
    // El autocompletado del nombre solo tiene sentido para "Efectivo" — no
    // hay nada que personalizar ahí. Para los demás tipos el usuario va a
    // escribir el banco/tarjeta (ej. "TC de Nu"), así que rellenar el campo
    // con la etiqueta genérica ("Crédito", "Débito"...) solo estorba: hay
    // que borrarla para escribir el nombre real.
    final nombreEsPorDefecto = nombreActual.isEmpty || nombreActual == TipoCuenta.efectivo.etiqueta;

    setState(() {
      _tipo = tipo;
      if (!nombreEsPorDefecto) return; // el usuario ya personalizó el nombre, no lo tocamos
      if (tipo == TipoCuenta.efectivo) {
        _nombreCtrl.text = tipo.etiqueta;
      } else {
        // Limpia el "Efectivo" que pudo haber quedado autocompletado antes,
        // para que el campo quede listo para escribir el banco desde cero.
        _nombreCtrl.clear();
      }
    });
  }

  void _agregarCuenta() {
    final nombre = _nombreCtrl.text.trim();
    final saldo = double.tryParse(_saldoCtrl.text.replaceAll(',', '.'));
    final esCredito = _tipo == TipoCuenta.credito;
    final limite = double.tryParse(_limiteCtrl.text.replaceAll(',', '.'));

    if (nombre.isEmpty || saldo == null) return;
    // En crédito, límite es obligatorio: sin él "disponible" no significa
    // nada (no se puede calcular la deuda real). Ver Cuenta.deudaActual.
    if (esCredito && limite == null) return;

    widget.onAgregar(Cuenta(
      id: '', // Firestore le asigna el id real al crearla.
      nombre: nombre,
      tipo: _tipo,
      saldoActual: saldo,
      limiteCredito: esCredito ? limite : null,
    ));

    _nombreCtrl.clear();
    _saldoCtrl.clear();
    _limiteCtrl.clear();
    setState(() => _tipo = TipoCuenta.efectivo);
  }

  @override
  Widget build(BuildContext context) {
    final mostrarCamposCredito = _tipo == TipoCuenta.credito;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nueva cuenta', style: AppTextStyles.labelSm),
        const SizedBox(height: 12),
        // --- Campo de nombre de la cuenta (ej. "Efectivo", "TC de Nu") ---
        // Se autocompleta al elegir un tipo abajo (ver _seleccionarTipo), pero
        // siempre es editable a mano.
        TextField(
          controller: _nombreCtrl,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [_CapitalizarPalabrasFormatter()],
          style: AppTextStyles.bodyLg,
          decoration: const InputDecoration(hintText: 'ej. Efectivo, TC de Nu'),
        ),
        const SizedBox(height: 12),
        // --- Chips para elegir el tipo de cuenta (efectivo/débito/crédito/vale/otro) ---
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TipoCuenta.values.map((tipo) {
            final seleccionado = tipo == _tipo;
            return ChoiceChip(
              label: Text(tipo.etiqueta),
              selected: seleccionado,
              onSelected: (_) => _seleccionarTipo(tipo),
              selectedColor: AppColors.primaryCyan.withValues(alpha: 0.2),
              backgroundColor: AppColors.surface3ActiveGlass,
              labelStyle: AppTextStyles.bodySm.copyWith(
                color: seleccionado ? AppColors.primaryCyan : AppColors.textSecondary,
              ),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // --- Campo de saldo actual (el único dato de dinero siempre obligatorio) ---
        // En una tarjeta de crédito este número es lo que TE QUEDA
        // DISPONIBLE de tu línea de crédito (no lo que debes) — igual que
        // lo muestra la app de tu banco. La deuda se calcula sola con el
        // límite de abajo, ver Cuenta.deudaActual.
        TextField(
          controller: _saldoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.bodyLg,
          decoration: InputDecoration(
            hintText: mostrarCamposCredito
                ? 'Disponible actual (obligatorio)'
                : 'Saldo actual (obligatorio)',
          ),
        ),
        // --- Campo de límite: solo aparece si el tipo es "Crédito", y aquí
        // sí es obligatorio (sin límite no se puede calcular la deuda real) ---
        if (mostrarCamposCredito) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _limiteCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.bodyLg,
            decoration: const InputDecoration(hintText: 'Límite de crédito (obligatorio)'),
          ),
          const SizedBox(height: 6),
          Text(
            'La deuda se calcula sola (límite − disponible). Si pagas la tarjeta o '
            'te suben el límite, actualízalo después desde Cuentas → Editar. '
            'La fecha de corte y de pago son opcionales.',
            style: AppTextStyles.bodySm,
          ),
        ],
        const SizedBox(height: 12),
        // --- Botón "Agregar cuenta": guarda en Firestore y limpia el formulario ---
        OutlinedButton.icon(
          onPressed: _agregarCuenta,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar cuenta'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: AppColors.glassStrokeStandard),
            foregroundColor: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

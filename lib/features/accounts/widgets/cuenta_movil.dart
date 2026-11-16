import 'package:flutter/material.dart';

import '../../../core/moneda/conversor_moneda.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/cuenta.dart';

/// Tarjeta de cuenta compacta del diseño móvil (según las pantallas del
/// usuario). Dos variantes: la del carrusel de Inicio (nombre, ícono y
/// disponible en una línea) y la de la cuadrícula de Cuentas (con tipo,
/// últimos dígitos, menú "⋯" y, en crédito, el uso de la línea y la deuda).
/// El dato principal sigue siendo lo DISPONIBLE, nunca la deuda.
class CuentaMovil extends StatelessWidget {
  const CuentaMovil({
    super.key,
    required this.cuenta,
    required this.ocultar,
    this.enCuadricula = false,
    this.accion,
  });

  final Cuenta cuenta;
  final bool ocultar;
  final bool enCuadricula;

  /// El menú "⋯" (solo en la cuadrícula).
  final Widget? accion;

  Color get _color => cuenta.colorPersonalizado != null
      ? Color(cuenta.colorPersonalizado!)
      : (cuenta.tipo == TipoCuenta.credito
            ? AppColors.secundarioEnTarjeta
            : AppColors.acentoEnTarjeta);

  IconData get _icono => cuenta.tipo == TipoCuenta.efectivo
      ? Icons.account_balance_wallet_outlined
      : Icons.credit_card_rounded;

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, enCuadricula ? 8 : 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              color.withValues(alpha: 0.42),
              AppColors.fondoTarjetaFisica,
            ),
            Color.alphaBlend(
              color.withValues(alpha: 0.12),
              AppColors.fondoTarjetaFisica,
            ),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: enCuadricula ? _cuadricula(color) : _carrusel(color),
    );
  }

  Widget _insignia(Color color) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Icon(_icono, color: color, size: 24),
  );

  String get _monto =>
      ocultar ? '••••' : ConversorMoneda.formato(cuenta.saldoActual, cuenta.id);

  Widget _carrusel(Color color) {
    final digitos = cuenta.ultimos4Digitos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cuenta.nombre,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (digitos != null && digitos.isNotEmpty)
                    Text(
                      '•••• $digitos',
                      style: AppTextStyles.labelCode.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                      ),
                    ),
                ],
              ),
            ),
            _insignia(color),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'DISPONIBLE',
              style: AppTextStyles.labelCode.copyWith(
                color: color,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
            // El saldo se encoge antes que cortarse (antes salía "8,870…").
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _monto,
                  semanticsLabel: ocultar ? 'Saldo oculto' : null,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cuadricula(Color color) {
    final esCredito = cuenta.tipo == TipoCuenta.credito;
    final limite = cuenta.limiteCredito;
    final digitos = cuenta.ultimos4Digitos;
    final uso = esCredito && limite != null && limite > 0
        ? ((limite - cuenta.saldoActual) / limite).clamp(0.0, 1.0)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_insignia(color), const Spacer(), ?accion],
        ),
        const SizedBox(height: 10),
        Text(
          cuenta.nombre,
          style: AppTextStyles.headlineSm.copyWith(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          [
            cuenta.tipo.etiqueta.toUpperCase(),
            if (digitos != null && digitos.isNotEmpty) digitos,
          ].join(' • '),
          style: AppTextStyles.labelCode.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        Text(
          'DISPONIBLE',
          style: AppTextStyles.labelCode.copyWith(
            color: color,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          _monto,
          semanticsLabel: ocultar ? 'Saldo oculto' : null,
          style: AppTextStyles.headlineSm.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // --- Crédito: uso de la línea y deuda (referencia, no el dato principal) ---
        if (uso != null && !ocultar) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: uso,
                    minHeight: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '${(uso * 100).round()}%',
                  style: AppTextStyles.labelSm.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Deuda ${ConversorMoneda.formato(cuenta.deudaActual ?? 0, cuenta.id)}',
            style: AppTextStyles.bodyMd.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

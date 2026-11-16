import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/cuenta.dart';

/// Color de una cuenta: el que eligió el usuario o el de su tipo (el
/// mismo criterio que CuentaMovil).
Color colorDeCuenta(Cuenta cuenta) => cuenta.colorPersonalizado != null
    ? Color(cuenta.colorPersonalizado!)
    : colorDeTipo(cuenta.tipo);

Color colorDeTipo(TipoCuenta tipo) => tipo == TipoCuenta.credito
    ? AppColors.secundarioEnTarjeta
    : AppColors.acentoEnTarjeta;

/// Ícono de cada tipo de cuenta (selector de "Nueva cuenta", detalle,
/// listas).
IconData iconoDeTipo(TipoCuenta tipo) => switch (tipo) {
  TipoCuenta.efectivo => Icons.account_balance_wallet_outlined,
  TipoCuenta.debito => Icons.credit_card_rounded,
  TipoCuenta.credito => Icons.credit_score_rounded,
  TipoCuenta.vale => Icons.confirmation_number_outlined,
  TipoCuenta.otro => Icons.more_horiz_rounded,
};

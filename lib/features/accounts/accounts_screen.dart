import 'package:flutter/material.dart';

import '../../core/router/app_shell.dart';
import 'widgets/cuentas_escritorio.dart';
import 'widgets/cuentas_movil.dart';

/// Pestaña "Cuentas": en ventana ancha, patrimonio y tarjetas en columnas
/// (CuentasEscritorio); en teléfono, el diseño móvil del usuario
/// (CuentasMovil). Tocar una cuenta lleva al detalle (editar, ver sus
/// movimientos, borrar).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return esEscritorio(context)
        ? const CuentasEscritorio()
        : const CuentasMovil();
  }
}

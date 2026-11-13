import 'package:flutter/material.dart';

import '../../core/router/app_shell.dart';
import 'widgets/reportes_escritorio.dart';
import 'widgets/reportes_movil.dart';

/// Reportes: totales del periodo, flujo de efectivo y desglose por
/// categoría, todo calculado desde `usuarios/{uid}/transacciones` real (sin
/// presupuestos ni predicciones inventadas, ver CLAUDE.md → regla de
/// fidelidad al Stitch). En ventana ancha usa ReportesEscritorio; en
/// teléfono, el diseño móvil del usuario (ReportesMovil).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return esEscritorio(context)
        ? const ReportesEscritorio()
        : const ReportesMovil();
  }
}

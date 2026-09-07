import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../transactions/providers/transacciones_providers.dart';
import '../transactions/widgets/movimiento_tile.dart';
import 'data/cuenta.dart';
import 'providers/cuentas_providers.dart';
import 'widgets/editar_cuenta_sheet.dart';

/// Detalle de una cuenta específica — sigue el diseño de
/// `15._detalle_de_tarjeta_nu_cr_dito` del Stitch, pero solo con datos
/// reales: sin CVV dinámico, "congelar tarjeta" ni límites de seguridad
/// (no hay vinculación bancaria real, esas funciones no existen de verdad
/// — ver CLAUDE.md → regla de fidelidad al Stitch). Lo que sí es real: el
/// disponible/deuda, la fecha de corte, y los movimientos de esta cuenta
/// en particular (ver "Resolución de ambigüedad de cuenta" — aquí es al
/// revés, ya sabemos la cuenta, solo filtramos sus movimientos).
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.cuentaId});

  final String cuentaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentas = ref.watch(cuentasProvider).value ?? const [];
    Cuenta? cuenta;
    for (final c in cuentas) {
      if (c.id == cuentaId) {
        cuenta = c;
        break;
      }
    }

    // La cuenta se pudo haber borrado desde otra pantalla/dispositivo
    // mientras esta seguía abierta.
    if (cuenta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuenta')),
        body: Center(
          child: Text('Esta cuenta ya no existe.', style: AppTextStyles.bodyMd),
        ),
      );
    }

    final esCredito = cuenta.tipo == TipoCuenta.credito;
    final colorAcento =
        cuenta.colorPersonalizado != null ? Color(cuenta.colorPersonalizado!) : AppColors.secondaryViolet;

    return Scaffold(
      appBar: AppBar(
        title: Text(cuenta.nombre, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar cuenta',
            onPressed: () => mostrarEditorDeCuenta(
              context: context,
              cuenta: cuenta!,
              onGuardar: (actualizada) =>
                  ref.read(cuentasRepositoryProvider).actualizarCuenta(actualizada),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Tarjeta visual grande (estilo Stitch) ---
            _TarjetaGrande(cuenta: cuenta, colorAcento: colorAcento),
            const SizedBox(height: 20),

            if (esCredito) ...[
              _InfoCredito(cuenta: cuenta, colorAcento: colorAcento),
              const SizedBox(height: 24),
            ],

            // --- Botón "Eliminar cuenta" ---
            OutlinedButton.icon(
              onPressed: () => _confirmarEliminar(context, ref, cuenta!),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.outflowCrimson),
              label: const Text('Eliminar cuenta', style: TextStyle(color: AppColors.outflowCrimson)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.outflowCrimson),
              ),
            ),
            const SizedBox(height: 28),

            // --- Movimientos de ESTA cuenta únicamente ---
            Text('Movimientos de esta cuenta', style: AppTextStyles.headlineSm),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final transacciones = ref.watch(transaccionesPorCuentaProvider(cuentaId));
                return transacciones.when(
                  data: (lista) {
                    if (lista.isEmpty) {
                      return Text(
                        'Todavía no hay movimientos en esta cuenta.',
                        style: AppTextStyles.bodyMd,
                      );
                    }
                    return Column(
                      children: [
                        for (final t in lista)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MovimientoTile(transaccion: t, nombreCuenta: cuenta!.nombre),
                          ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)),
                  error: (e, _) => Text('No se pudieron cargar: $e',
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context, WidgetRef ref, Cuenta cuenta) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('¿Eliminar esta cuenta?'),
        content: Text(
          'Se elimina "${cuenta.nombre}". Sus movimientos ya registrados NO se borran, '
          'pero dejarán de tener una cuenta asociada.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.outflowCrimson)),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await ref.read(cuentasRepositoryProvider).eliminarCuenta(cuenta.id);
      if (context.mounted) context.pop();
    }
  }
}

/// La tarjeta visual grande de encabezado — versión honesta del "hero card"
/// del Stitch: sin chip EMV, titular ni fecha de vencimiento inventados
/// (no recolectamos esos datos), pero con los últimos 4 dígitos reales si
/// el usuario los configuró.
class _TarjetaGrande extends StatelessWidget {
  const _TarjetaGrande({required this.cuenta, required this.colorAcento});
  final Cuenta cuenta;
  final Color colorAcento;

  @override
  Widget build(BuildContext context) {
    final esCredito = cuenta.tipo == TipoCuenta.credito;
    final digitos = cuenta.ultimos4Digitos;

    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorAcento.withValues(alpha: 0.55), AppColors.canvas],
        ),
        boxShadow: [
          BoxShadow(color: colorAcento.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                esCredito ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                color: Colors.white,
                size: 28,
              ),
              if (esCredito) const Icon(Icons.contactless_rounded, color: Colors.white70, size: 22),
            ],
          ),
          const Spacer(),
          Text(
            digitos != null && digitos.isNotEmpty ? '•••• •••• •••• $digitos' : cuenta.tipo.etiqueta,
            style: AppTextStyles.bodyLg.copyWith(color: Colors.white, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(cuenta.nombre,
              style: AppTextStyles.headlineSm.copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Métricas de línea de crédito y corte — todo calculado de datos reales
/// (nunca "pago mínimo requerido" ni cosas que necesitarían el estado de
/// cuenta real del banco, que no tenemos).
class _InfoCredito extends StatelessWidget {
  const _InfoCredito({required this.cuenta, required this.colorAcento});
  final Cuenta cuenta;
  final Color colorAcento;

  @override
  Widget build(BuildContext context) {
    final limite = cuenta.limiteCredito;
    final deuda = cuenta.deudaActual;
    final progreso =
        (limite != null && limite > 0 && deuda != null) ? (deuda / limite).clamp(0.0, 1.0) : null;
    final diasCorte = cuenta.diasParaCorte;
    final diaLimitePago = cuenta.diaLimitePago;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEUDA ACTUAL', style: AppTextStyles.labelCode),
          const SizedBox(height: 4),
          Text(
            '\$${(deuda ?? 0).toStringAsFixed(2)}',
            style: AppTextStyles.numericHero.copyWith(color: AppColors.outflowCrimson),
          ),
          if (progreso != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                backgroundColor: AppColors.surface3ActiveGlass,
                valueColor: AlwaysStoppedAnimation(colorAcento),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Disponible: \$${cuenta.saldoActual.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySm),
                if (limite != null)
                  Text('Límite: \$${limite.toStringAsFixed(2)}', style: AppTextStyles.bodySm),
              ],
            ),
          ],
          if (diasCorte != null || diaLimitePago != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (diasCorte != null)
                  Expanded(
                    child: _CasillaFecha(
                      icono: Icons.event_rounded,
                      etiqueta: 'Próximo corte',
                      valor: 'En $diasCorte días',
                    ),
                  ),
                if (diasCorte != null && diaLimitePago != null) const SizedBox(width: 10),
                if (diaLimitePago != null)
                  Expanded(
                    child: _CasillaFecha(
                      icono: Icons.event_available_rounded,
                      etiqueta: 'Límite de pago',
                      valor: 'Día $diaLimitePago',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CasillaFecha extends StatelessWidget {
  const _CasillaFecha({required this.icono, required this.etiqueta, required this.valor});
  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface3ActiveGlass,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(etiqueta, style: AppTextStyles.labelCode),
            ],
          ),
          const SizedBox(height: 4),
          Text(valor, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

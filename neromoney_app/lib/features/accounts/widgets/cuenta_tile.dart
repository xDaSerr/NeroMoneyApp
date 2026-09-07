import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/cuenta.dart';
import 'chip_emv.dart';

/// Tarjeta que representa una cuenta — usada tanto en el carrusel de Inicio
/// como en la lista de la pestaña Cuentas. Con forma de tarjeta física real
/// (relación de aspecto 1.586, como una tarjeta de verdad) siguiendo la
/// referencia visual que dio el usuario a partir del Stitch — antes era
/// solo una `GlassCard` con texto, que no se sentía como una tarjeta.
///
/// El color de fondo es el que el usuario haya elegido
/// (`Cuenta.colorPersonalizado`), o violeta por defecto para crédito / cian
/// para el resto si no eligió ninguno. El dato principal sigue siendo
/// DISPONIBLE, nunca la deuda (decisión explícita del usuario, ver
/// CLAUDE.md) — la deuda solo aparece como referencia calculada, con su
/// barra de uso del límite.
class CuentaTile extends StatelessWidget {
  const CuentaTile({
    super.key,
    required this.cuenta,
    this.ocultarImportes = false,
  });

  final Cuenta cuenta;
  final bool ocultarImportes;

  @override
  Widget build(BuildContext context) {
    final esCredito = cuenta.tipo == TipoCuenta.credito;
    // Débito también es una tarjeta física de verdad (a diferencia de
    // efectivo/vale/otro) — lleva chip igual que crédito.
    final esTarjeta = esCredito || cuenta.tipo == TipoCuenta.debito;
    final acento = cuenta.colorPersonalizado != null
        ? Color(cuenta.colorPersonalizado!)
        : (esCredito ? AppColors.secondaryViolet : AppColors.primaryCyan);
    final digitos = cuenta.ultimos4Digitos;
    final limite = cuenta.limiteCredito;
    final deuda = cuenta.deudaActual;
    final progreso = (limite != null && limite > 0 && deuda != null)
        ? (deuda / limite).clamp(0.0, 1.0)
        : null;
    final diasCorte = cuenta.diasParaCorte;

    return AspectRatio(
      aspectRatio: 1.586, // proporción real de una tarjeta física
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Fondo casi negro con un tinte del color de la cuenta — así
            // cada cuenta se ve distinta sin necesitar una paleta fija por
            // banco (no conocemos el banco real de cada una).
            colors: [
              Color.alphaBlend(
                acento.withValues(alpha: 0.55),
                AppColors.canvas,
              ),
              Color.alphaBlend(
                acento.withValues(alpha: 0.22),
                AppColors.canvas,
              ),
              AppColors.canvas,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: acento.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // --- Brillo ambiental, como el reflejo de una tarjeta real ---
              Positioned(
                top: -65,
                left: -65,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // --- Encabezado: nombre + tipo/dígitos, e ícono de la cuenta ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cuenta.nombre,
                                style: AppTextStyles.bodyLg.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    cuenta.tipo.etiqueta.toUpperCase(),
                                    style: AppTextStyles.labelCode.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  if (digitos != null &&
                                      digitos.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '•••• $digitos',
                                      style: AppTextStyles.labelCode.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            // --- Chip EMV dorado: crédito y débito son
                            // tarjetas físicas de verdad, efectivo/vale/otro no ---
                            if (esTarjeta) ...[
                              const ChipEmv(),
                              const SizedBox(width: 8),
                            ],
                            // --- Insignia: contactless para tarjetas, cartera para el resto ---
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: acento.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                esCredito || cuenta.tipo == TipoCuenta.debito
                                    ? Icons.contactless_rounded
                                    : Icons.account_balance_wallet_rounded,
                                color: acento,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // --- Dato principal: SIEMPRE lo disponible, nunca la deuda ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'DISPONIBLE',
                          style: AppTextStyles.labelCode.copyWith(
                            color: acento,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ocultarImportes
                                ? '••••'
                                : '\$${cuenta.saldoActual.toStringAsFixed(2)}',
                            semanticsLabel: ocultarImportes
                                ? 'Disponible oculto'
                                : null,
                            style: AppTextStyles.headlineMd.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // --- Deuda de referencia + barra de uso del límite (solo crédito) ---
                    if (progreso != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 5,
                              child: Stack(
                                children: [
                                  Container(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                  if (!ocultarImportes)
                                    FractionallySizedBox(
                                      widthFactor: progreso,
                                      child: Container(color: acento),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ocultarImportes
                                    ? 'Debes •••• de ••••'
                                    : 'Debes \$${(deuda ?? 0).toStringAsFixed(0)} de \$${(limite ?? 0).toStringAsFixed(0)}',
                                semanticsLabel: ocultarImportes
                                    ? 'Deuda y límite ocultos'
                                    : null,
                                style: AppTextStyles.bodySm.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                              if (diasCorte != null)
                                Text(
                                  'Corte en ${diasCorte}d',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

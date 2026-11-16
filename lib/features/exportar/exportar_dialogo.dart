import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/moneda/conversor_moneda.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import '../planes/data/membresia.dart';
import '../planes/providers/planes_providers.dart';
import '../planes/widgets/aviso_plan.dart';
import '../transactions/data/periodo_movimientos.dart';
import '../transactions/providers/transacciones_providers.dart';
import 'data/exportador.dart';

enum FormatoExportacion { csv, pdf }

/// "Exportar movimientos": Excel/CSV (Plus) o PDF (Pro) de un periodo.
Future<void> mostrarDialogoExportar(BuildContext context, WidgetRef ref) async {
  final plan = ref.read(membresiaProvider).value?.plan ?? PlanNero.gratis;
  if (plan == PlanNero.gratis) {
    await mostrarAvisoPlan(
      context,
      titulo: 'Exporta tus movimientos con Plus',
      mensaje:
          'Descarga tus movimientos en Excel/CSV para tus cuentas, tu '
          'contador o tu declaración. Con Pro también en PDF.',
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _DialogoExportar(plan: plan),
  );
}

class _DialogoExportar extends ConsumerStatefulWidget {
  const _DialogoExportar({required this.plan});

  final PlanNero plan;

  @override
  ConsumerState<_DialogoExportar> createState() => _DialogoExportarState();
}

class _DialogoExportarState extends ConsumerState<_DialogoExportar> {
  PeriodoMovimientos _periodo = PeriodoMovimientos.esteMes;
  FormatoExportacion _formato = FormatoExportacion.csv;
  bool _trabajando = false;
  String? _error;

  Future<void> _elegirFormato(FormatoExportacion f) async {
    if (f == FormatoExportacion.pdf && widget.plan != PlanNero.pro) {
      await mostrarAvisoPlan(
        context,
        plan: PlanNero.pro,
        titulo: 'Reporte en PDF con Pro',
        mensaje:
            'Con NeroMoney Pro descargas un reporte en PDF con tus totales, '
            'gasto por categoría y todos tus movimientos.',
      );
      return;
    }
    setState(() => _formato = f);
  }

  Future<void> _exportar() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      final (desde, hasta) = _periodo.rango;
      final movimientos = await ref
          .read(transaccionesRepositoryProvider)
          .observarPorRango(desde, hasta)
          .first;
      if (movimientos.isEmpty) {
        setState(() => _error = 'No hay movimientos en este periodo.');
        return;
      }
      final cuentas = ref.read(cuentasProvider).value ?? const <Cuenta>[];
      final nombres = {for (final c in cuentas) c.id: c.nombre};
      final filas = [
        for (final t in movimientos..sort((a, b) => a.fecha.compareTo(b.fecha)))
          FilaExportable(
            t,
            nombres[t.cuentaId] ?? '—',
            ConversorMoneda.monedaDeCuenta(t.cuentaId),
          ),
      ];
      final nombre =
          'NeroMoney - ${_periodo.nombre} - '
          '${DateTime.now().toIso8601String().substring(0, 10)}';

      if (_formato == FormatoExportacion.csv) {
        await _guardar(nombre, generarCsv(filas), 'csv', MimeType.csv);
      } else {
        final pdf = await generarPdf(
          filas: filas,
          titulo: 'Movimientos: ${_periodo.nombre}',
          monedaPrincipal: ConversorMoneda.principal,
          // "Todo el historial" usa un rango enorme; para los totales del
          // PDF basta con el de los movimientos reales.
          desde: filas.first.transaccion.fecha,
          hasta: filas.last.transaccion.fecha.add(const Duration(days: 1)),
          fuente: pw.Font.ttf(
            await rootBundle.load('assets/fonts/Outfit-Regular.ttf'),
          ),
          fuenteNegrita: pw.Font.ttf(
            await rootBundle.load('assets/fonts/Outfit-Bold.ttf'),
          ),
        );
        await _guardar(nombre, pdf, 'pdf', MimeType.pdf);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo generar el archivo. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  /// En la web se descarga; en el teléfono se abre el diálogo del sistema
  /// para elegir dónde guardarlo.
  Future<void> _guardar(
    String nombre,
    Uint8List bytes,
    String extension,
    MimeType tipo,
  ) async {
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: nombre,
        bytes: bytes,
        fileExtension: extension,
        mimeType: tipo,
      );
    } else {
      await FileSaver.instance.saveAs(
        name: nombre,
        bytes: bytes,
        fileExtension: extension,
        mimeType: tipo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Exportar movimientos', style: AppTextStyles.headlineMd),
              const SizedBox(height: 18),
              DropdownButtonFormField<PeriodoMovimientos>(
                initialValue: _periodo,
                dropdownColor: AppColors.surface1,
                decoration: const InputDecoration(labelText: 'Periodo'),
                items: [
                  for (final p in PeriodoMovimientos.values)
                    DropdownMenuItem(value: p, child: Text(p.nombre)),
                ],
                onChanged: (p) => setState(() => _periodo = p ?? _periodo),
              ),
              const SizedBox(height: 18),
              Text('Formato', style: AppTextStyles.bodyMd),
              const SizedBox(height: 8),
              _OpcionFormato(
                icono: Icons.table_chart_outlined,
                titulo: 'Excel / CSV',
                detalle: 'Para abrir en Excel o Google Sheets.',
                seleccionado: _formato == FormatoExportacion.csv,
                onTap: () => _elegirFormato(FormatoExportacion.csv),
              ),
              const SizedBox(height: 8),
              _OpcionFormato(
                icono: Icons.picture_as_pdf_outlined,
                titulo: 'PDF',
                detalle: 'Reporte con totales y categorías.',
                etiqueta: widget.plan == PlanNero.pro ? null : 'Pro',
                seleccionado: _formato == FormatoExportacion.pdf,
                onTap: () => _elegirFormato(FormatoExportacion.pdf),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.outflowCrimson,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _trabajando ? null : _exportar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.acento,
                      foregroundColor: AppColors.sobreAcento,
                      textStyle: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    icon: _trabajando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.sobreAcento,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('Descargar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionFormato extends StatelessWidget {
  const _OpcionFormato({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.seleccionado,
    required this.onTap,
    this.etiqueta,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final bool seleccionado;
  final VoidCallback onTap;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.acento.withValues(alpha: 0.12)
              : AppColors.surface2Glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado
                ? AppColors.acento
                : AppColors.glassStrokeStandard,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, color: AppColors.acento),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppTextStyles.bodyLg),
                  Text(
                    detalle,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (etiqueta != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.acento.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  etiqueta!,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

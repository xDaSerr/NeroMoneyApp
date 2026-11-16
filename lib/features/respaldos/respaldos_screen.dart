import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/widgets/glass_card.dart';
import '../auth/providers/auth_providers.dart';
import '../planes/data/membresia.dart';
import '../planes/providers/planes_providers.dart';

/// Una copia guardada por el servidor (functions/respaldo.js).
class CopiaRespaldo {
  const CopiaRespaldo({
    required this.mes,
    required this.creado,
    required this.movimientos,
    required this.partes,
  });

  final String mes;
  final DateTime? creado;
  final int movimientos;
  final int partes;

  factory CopiaRespaldo.desdeMapa(Map<String, dynamic> d) => CopiaRespaldo(
    mes: d['mes'] as String? ?? '',
    creado: DateTime.tryParse(d['creado'] as String? ?? '')?.toLocal(),
    movimientos: (d['movimientos'] as num?)?.toInt() ?? 0,
    partes: (d['partes'] as num?)?.toInt() ?? 0,
  );
}

CollectionReference<Map<String, dynamic>> _copias(String uid) =>
    FirebaseFirestore.instance
        .collection('respaldos')
        .doc(uid)
        .collection('copias');

final copiasRespaldoProvider = StreamProvider.autoDispose<List<CopiaRespaldo>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return _copias(uid)
      .orderBy('mes', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) CopiaRespaldo.desdeMapa(d.data())]);
});

/// Respaldos automáticos (Pro): una copia de todos tus movimientos cada
/// día 1, las últimas 12, para descargar en CSV.
class RespaldosScreen extends ConsumerStatefulWidget {
  const RespaldosScreen({super.key});

  @override
  ConsumerState<RespaldosScreen> createState() => _RespaldosScreenState();
}

class _RespaldosScreenState extends ConsumerState<RespaldosScreen> {
  bool _creando = false;
  String? _descargando;

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _crearAhora() async {
    setState(() => _creando = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('respaldoAhora').call();
      _avisar('Listo: tu respaldo de hoy ya está guardado.');
    } on FirebaseFunctionsException catch (e) {
      _avisar(e.message ?? 'No se pudo crear el respaldo.');
    } catch (_) {
      _avisar('No se pudo crear el respaldo. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  /// Junta las partes de la copia y descarga el CSV.
  Future<void> _descargar(CopiaRespaldo copia) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _descargando = copia.mes);
    try {
      final partes = await _copias(uid)
          .doc(copia.mes)
          .collection('partes')
          .orderBy('i')
          .get();
      final csv = partes.docs.map((d) => d.data()['csv'] as String).join();
      final bytes = utf8.encode(csv);
      final nombre = 'NeroMoney - respaldo ${copia.mes}';
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: nombre,
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
      } else {
        await FileSaver.instance.saveAs(
          name: nombre,
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
      }
    } catch (_) {
      _avisar('No se pudo descargar el respaldo.');
    } finally {
      if (mounted) setState(() => _descargando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(membresiaProvider).value?.plan ?? PlanNero.gratis;
    final copias = ref.watch(copiasRespaldoProvider);
    final esPro = plan == PlanNero.pro;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Atrás',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/profile'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tus respaldos',
                    style: AppTextStyles.display.copyWith(fontSize: 34),
                  ),
                  Text(
                    'Cada día 1 guardamos una copia de todos tus movimientos. '
                    'Conservamos las últimas 12.',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!esPro)
                    GlassCard(
                      borderRadius: 22,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            color: AppColors.acento,
                            size: 30,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Respaldo automático con Pro',
                            style: AppTextStyles.headlineSm,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Con NeroMoney Pro tus movimientos se respaldan '
                            'solos cada mes y los descargas cuando quieras.',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
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
                            onPressed: () => context.push('/planes'),
                            child: const Text('Ver Pro'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _creando ? null : _crearAhora,
                        icon: _creando
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.acento,
                                ),
                              )
                            : Icon(
                                Icons.backup_outlined,
                                color: AppColors.acento,
                              ),
                        label: Text(
                          'Hacer un respaldo ahora',
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.acento,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          side: BorderSide(
                            color: AppColors.acento.withValues(alpha: 0.6),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    copias.when(
                      data: (lista) => lista.isEmpty
                          ? Text(
                              'Aún no hay respaldos. El primero se hace el '
                              'día 1, o ahora mismo con el botón de arriba.',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            )
                          : GlassCard(
                              borderRadius: 22,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 6,
                              ),
                              child: Column(
                                children: [
                                  for (final (i, c) in lista.indexed) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        color: AppColors.glassStrokeStandard,
                                      ),
                                    _FilaCopia(
                                      copia: c,
                                      descargando: _descargando == c.mes,
                                      onDescargar: () => _descargar(c),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: AppColors.acento,
                        ),
                      ),
                      error: (_, _) => Text(
                        'No se pudieron cargar tus respaldos.',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.outflowCrimson,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaCopia extends StatelessWidget {
  const _FilaCopia({
    required this.copia,
    required this.descargando,
    required this.onDescargar,
  });

  final CopiaRespaldo copia;
  final bool descargando;
  final VoidCallback onDescargar;

  @override
  Widget build(BuildContext context) {
    final f = copia.creado;
    final cuando = f == null
        ? copia.mes
        : '${f.day} de ${mesesEs[f.month - 1]} de ${f.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: AppColors.acento),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cuando, style: AppTextStyles.bodyLg),
                Text(
                  '${copia.movimientos} movimientos · CSV',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          descargando
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.acento,
                  ),
                )
              : IconButton(
                  tooltip: 'Descargar',
                  color: AppColors.acento,
                  onPressed: onDescargar,
                  icon: const Icon(Icons.download_rounded),
                ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogo_formulario.dart' show decoracionCampo;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../assistant/data/voz_asistente.dart';
import '../../assistant/providers/voz_asistente_provider.dart';

class ConfiguracionVozAsistente extends ConsumerStatefulWidget {
  const ConfiguracionVozAsistente({
    super.key,
    required this.nombre,
    required this.vozNombre,
    required this.vozIdioma,
    required this.tono,
    required this.revisar,
    required this.onVoz,
    required this.onTono,
    required this.onRevisar,
  });
  final String nombre, vozNombre, vozIdioma;
  final double tono;
  final bool revisar;
  final void Function(String, String) onVoz;
  final ValueChanged<double> onTono;
  final ValueChanged<bool> onRevisar;

  @override
  ConsumerState<ConfiguracionVozAsistente> createState() =>
      _ConfiguracionVozAsistenteState();
}

class _ConfiguracionVozAsistenteState
    extends ConsumerState<ConfiguracionVozAsistente>
    with WidgetsBindingObserver {
  late final VozAsistente _voz;
  late Future<List<VozDisponible>> _voces;
  bool _probando = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voz = ref.read(vozAsistenteProvider);
    _voces = _voz.voces();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _detener();
  }

  void _detener() => unawaited(_voz.detener().catchError((Object _) {}));
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detener();
    super.dispose();
  }

  Future<void> _probar() async {
    setState(() {
      _probando = true;
      _error = null;
    });
    try {
      await _voz.hablar(
        'Hola, soy ${widget.nombre.trim().isEmpty ? 'tu asistente' : widget.nombre.trim()}. Así escucharás mis respuestas.',
        nombre: widget.vozNombre,
        idioma: widget.vozIdioma,
        tono: widget.tono,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo reproducir. Prueba otra voz o revisa los idiomas de texto a voz del teléfono.',
        );
      }
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    borderRadius: 24,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.volume_up_outlined, color: AppColors.acento, size: 30),
            const SizedBox(width: 12),
            Text('Voz y dictado', style: AppTextStyles.headlineMd),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Voz del asistente',
          style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<VozDisponible>>(
          future: _voces,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snap.hasError) {
              return TextButton(
                onPressed: () => setState(() => _voces = _voz.voces()),
                child: const Text(
                  'No se pudieron cargar las voces. Reintentar',
                ),
              );
            }
            final voces = snap.data ?? [];
            final id = widget.vozNombre.isEmpty
                ? ''
                : '${widget.vozIdioma}|${widget.vozNombre}';
            final falta = id.isNotEmpty && !voces.any((v) => v.id == id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Selector de voces reales: no inferir género a partir de IDs del motor ---
                DropdownButtonFormField<String>(
                  key: ValueKey(id),
                  initialValue: id,
                  isExpanded: true,
                  dropdownColor: AppColors.surface1,
                  borderRadius: BorderRadius.circular(14),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textPrimary,
                  ),
                  style: AppTextStyles.bodyLg,
                  decoration: decoracionCampo(),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Predeterminada del dispositivo'),
                    ),
                    if (falta)
                      DropdownMenuItem(
                        value: id,
                        enabled: false,
                        child: const Text(
                          'Voz no disponible en este dispositivo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    for (var i = 0; i < voces.length; i++)
                      DropdownMenuItem(
                        value: voces[i].id,
                        child: Text(
                          'Voz ${i + 1} · ${voces[i].region}${voces[i].red ? ' · En línea' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (valor) {
                    _detener();
                    final elegida = voces
                        .where((v) => v.id == valor)
                        .firstOrNull;
                    widget.onVoz(
                      elegida?.nombre ?? '',
                      elegida?.idioma ?? 'es-MX',
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  falta || voces.isEmpty
                      ? 'Se usará la voz predeterminada. Puedes agregar voces en los ajustes de texto a voz de tu dispositivo.'
                      : 'Las voces disponibles dependen de tu dispositivo.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          'Tono de voz',
          style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
        // --- Tono: cambia la altura de la voz elegida sin fingir otra voz instalada ---
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: AppColors.acento,
            inactiveTrackColor: AppColors.surface3ActiveGlass,
            thumbColor: AppColors.acento,
            overlayColor: AppColors.acento.withValues(alpha: 0.15),
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: widget.tono.clamp(0.7, 1.3),
            min: 0.7,
            max: 1.3,
            divisions: 12,
            label: widget.tono.toStringAsFixed(2),
            onChanged: widget.onTono,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Más grave',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'Más agudo',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // --- Muestra de voz: solo reproduce una frase, no manda mensajes a la IA ---
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _probando ? null : _probar,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Escuchar muestra'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.acento),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTextStyles.bodyLg,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _probando ? _detener : null,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Detener'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.glassStrokeHighlight),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTextStyles.bodyLg,
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: AppTextStyles.bodySm),
          ),
        const SizedBox(height: 16),
        Divider(height: 1, color: AppColors.glassStrokeStandard),
        const SizedBox(height: 14),
        // --- Revisar dictado: evita enviar una transcripción equivocada automáticamente ---
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revisar antes de enviar',
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Si lo desactivas, solo pediré revisión cuando el dictado sea dudoso.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: widget.revisar,
              activeTrackColor: AppColors.acento,
              onChanged: widget.onRevisar,
            ),
          ],
        ),
      ],
    ),
  );
}

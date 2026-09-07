import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VOZ Y DICTADO', style: AppTextStyles.labelCode),
        const SizedBox(height: 12),
        Text(
          'Elige una voz y escúchala antes de guardar. Las opciones dependen de las voces disponibles en tu teléfono.',
          style: AppTextStyles.bodySm,
        ),
        const SizedBox(height: 12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Selector de voces reales: no inferir género a partir de IDs del motor ---
                DropdownButtonFormField<String>(
                  key: ValueKey(id),
                  initialValue: id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Voz del asistente',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                        child: Text('Predeterminada'),
                    ),
                    if (falta)
                      DropdownMenuItem(
                        value: id,
                        enabled: false,
                          child: const Text('Voz no disponible', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                if (falta || voces.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Se usará la voz predeterminada. Puedes agregar voces en los ajustes de texto a voz del teléfono.',
                      style: AppTextStyles.bodySm,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Tono de la voz', style: AppTextStyles.bodyMd),
        // --- Tono: cambia la altura de la voz elegida sin fingir otra voz instalada ---
        Slider(
          value: widget.tono.clamp(0.7, 1.3),
          min: 0.7,
          max: 1.3,
          divisions: 12,
          label: widget.tono.toStringAsFixed(2),
          onChanged: widget.onTono,
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Más grave'), Text('Más agudo')],
        ),
        const SizedBox(height: 8),
        // --- Muestra de voz: solo reproduce una frase, no manda mensajes a la IA ---
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _probando ? null : _probar,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Escuchar muestra'),
            ),
            TextButton(onPressed: _detener, child: const Text('Detener')),
          ],
        ),
        if (_error != null) Text(_error!, style: AppTextStyles.bodySm),
        const Divider(),
        // --- Revisar dictado: evita enviar una transcripción equivocada automáticamente ---
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Revisar antes de enviar'),
          subtitle: const Text(
            'Puedes corregir lo escuchado. Si lo desactivas, los dictados dudosos aún pedirán revisión.',
          ),
          value: widget.revisar,
          onChanged: widget.onRevisar,
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/asistente_avatar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';

// Mismas sugerencias que en Personalizar asistente.
const _sugerencias = ['Lucy', 'Nero', 'Nova', 'Atlas', 'Aria'];

/// La primera vez que el usuario abre a su asistente, este se presenta y
/// pregunta cómo quiere llamarlo (decisión del usuario: el nombre ya no se
/// pide en el onboarding). Devuelve el nombre elegido; "Lucy" si se queda
/// con el de siempre. No se puede cerrar tocando fuera: así la pregunta no
/// se pierde por un toque accidental, y "Me quedo con Lucy" es la salida.
Future<String> preguntarNombreAsistente(
  BuildContext context, {
  String? avatarBase64,
}) async {
  final nombre = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoNombre(avatarBase64: avatarBase64),
  );
  return (nombre == null || nombre.trim().isEmpty) ? 'Lucy' : nombre.trim();
}

class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre({required this.avatarBase64});

  final String? avatarBase64;

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _guardar() => Navigator.pop(context, _ctrl.text);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: GlassCard(
          color: AppColors.surface1,
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AsistenteAvatar(avatarBase64: widget.avatarBase64, size: 72)
                  .animate()
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    duration: 420.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 250.ms),
              const SizedBox(height: 18),
              // --- La presentación del asistente, como un mensaje suyo ---
              Text(
                'Hola, soy tu asistente virtual para ayudarte con tus gastos.',
                style: AppTextStyles.bodyLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '¿Cómo me quieres llamar?',
                style: AppTextStyles.headlineSm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // --- Campo para escribir el nombre ---
              TextField(
                controller: _ctrl,
                autofocus: true,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _guardar(),
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.headlineSm,
                decoration: const InputDecoration(
                  hintText: 'Escribe un nombre',
                ),
              ),
              const SizedBox(height: 12),
              // --- Sugerencias: un toque llena el campo ---
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _sugerencias)
                    ChoiceChip(
                      label: Text(s),
                      selected: _ctrl.text.trim() == s,
                      onSelected: (_) => setState(() => _ctrl.text = s),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              // --- Botón "Llámame así": guarda el nombre escrito ---
              GradientButton(
                label: _ctrl.text.trim().isEmpty
                    ? 'Llámame así'
                    : 'Llámame ${_ctrl.text.trim()}',
                onPressed: _ctrl.text.trim().isEmpty ? null : _guardar,
              ),
              const SizedBox(height: 6),
              // --- "Me quedo con Lucy": conserva el nombre de siempre ---
              TextButton(
                onPressed: () => Navigator.pop(context, 'Lucy'),
                child: const Text('Me quedo con Lucy'),
              ),
              Text(
                'Puedes cambiarlo cuando quieras en Perfil → Personalizar asistente.',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/controlador_tema.dart';
import '../../../core/theme/tema_app.dart';
import '../../onboarding/widgets/muestra_tema.dart';

/// Perfil → "Color de la app": los mismos 8 colores del onboarding. Tocar
/// uno lo aplica al instante (la app entera es la vista previa) y lo guarda
/// con [onElegir]; el diálogo se queda abierto para poder comparar.
Future<void> mostrarSelectorTema({
  required BuildContext context,
  required Future<void> Function(TemaApp tema) onElegir,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SelectorTema(onElegir: onElegir),
  );
}

class _SelectorTema extends StatefulWidget {
  const _SelectorTema({required this.onElegir});

  final Future<void> Function(TemaApp tema) onElegir;

  @override
  State<_SelectorTema> createState() => _SelectorTemaState();
}

class _SelectorTemaState extends State<_SelectorTema> {
  TemaApp _actual = ControladorTema.instancia.tema;

  Future<void> _elegir(TemaApp tema) async {
    setState(() => _actual = tema);
    ControladorTema.instancia.cambiar(tema);
    try {
      await widget.onElegir(tema);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el color. Revisa tu conexión.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      title: Text('Color de la app', style: AppTextStyles.headlineSm),
      content: SizedBox(
        width: 360,
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
          children: [
            for (final tema in TemaApp.values)
              MuestraTema(
                tema: tema,
                seleccionado: tema == _actual,
                onTap: () => _elegir(tema),
              ),
          ],
        ),
      ),
      actions: [
        // --- Botón "Listo": cierra (el color ya quedó guardado) ---
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

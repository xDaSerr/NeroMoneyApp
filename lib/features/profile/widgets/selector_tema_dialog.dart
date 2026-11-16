import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/controlador_tema.dart';
import '../../../core/theme/tema_app.dart';
import '../../onboarding/widgets/muestra_tema.dart';
import '../../planes/data/membresia.dart';
import '../../planes/widgets/aviso_plan.dart';

/// Perfil → "Apariencia": los 8 colores (para todos) y los fondos con
/// imagen (Plus y Pro). Tocar uno lo aplica al instante (la app entera es la
/// vista previa) y lo guarda; la ventana se queda abierta para comparar.
/// Elegir un color quita el fondo.
Future<void> mostrarSelectorTema({
  required BuildContext context,
  required Future<void> Function(TemaApp tema) onElegir,
  required Future<void> Function(FondoApp? fondo) onElegirFondo,
  required PlanNero plan,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SelectorTema(
      onElegir: onElegir,
      onElegirFondo: onElegirFondo,
      plan: plan,
    ),
  );
}

class _SelectorTema extends StatefulWidget {
  const _SelectorTema({
    required this.onElegir,
    required this.onElegirFondo,
    required this.plan,
  });

  final Future<void> Function(TemaApp tema) onElegir;
  final Future<void> Function(FondoApp? fondo) onElegirFondo;
  final PlanNero plan;

  @override
  State<_SelectorTema> createState() => _SelectorTemaState();
}

class _SelectorTemaState extends State<_SelectorTema> {
  TemaApp _actual = ControladorTema.instancia.tema;
  FondoApp? _fondo = ControladorTema.instancia.fondo;

  bool get _tieneFondos => widget.plan != PlanNero.gratis;

  Future<void> _guardar(Future<void> Function() accion) async {
    try {
      await accion();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar. Revisa tu conexión.'),
        ),
      );
    }
  }

  Future<void> _elegir(TemaApp tema) async {
    final quitarFondo = _fondo != null;
    setState(() {
      _actual = tema;
      _fondo = null;
    });
    ControladorTema.instancia.cambiar(tema);
    if (quitarFondo) ControladorTema.instancia.cambiarFondo(null);
    await _guardar(() async {
      await widget.onElegir(tema);
      if (quitarFondo) await widget.onElegirFondo(null);
    });
  }

  Future<void> _elegirFondo(FondoApp? fondo) async {
    if (!_tieneFondos) {
      await mostrarAvisoPlan(
        context,
        titulo: 'Fondos exclusivos con Plus',
        mensaje:
            'Con NeroMoney Plus (\$1.50 al mes) eliges uno de 5 fondos y '
            'los colores de la app se ajustan a él.',
      );
      return;
    }
    setState(() => _fondo = fondo);
    ControladorTema.instancia.cambiarFondo(fondo);
    await _guardar(() => widget.onElegirFondo(fondo));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Apariencia', style: AppTextStyles.headlineMd),
              const SizedBox(height: 18),
              // --- Colores: para todos ---
              Text(
                'Color de la app',
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: [
                  for (final tema in TemaApp.values)
                    MuestraTema(
                      tema: tema,
                      seleccionado: _fondo == null && tema == _actual,
                      onTap: () => _elegir(tema),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              // --- Fondos con imagen: Plus y Pro ---
              Row(
                children: [
                  Text(
                    'Fondos',
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.acento.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Plus',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Una imagen de fondo con los colores ajustados a ella.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 16 / 10.5,
                children: [
                  for (final fondo in FondoApp.values)
                    _MuestraFondo(
                      fondo: fondo,
                      elegido: fondo == _fondo,
                      bloqueado: !_tieneFondos,
                      onTap: () => _elegirFondo(fondo),
                    ),
                  if (_tieneFondos)
                    _SinFondo(
                      elegido: _fondo == null,
                      onTap: () => _elegirFondo(null),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Listo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuestraFondo extends StatelessWidget {
  const _MuestraFondo({
    required this.fondo,
    required this.elegido,
    required this.bloqueado,
    required this.onTap,
  });

  final FondoApp fondo;
  final bool elegido;
  final bool bloqueado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: elegido,
      label: 'Fondo ${fondo.etiqueta}',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: borde,
              border: Border.all(
                color: elegido
                    ? AppColors.acento
                    : AppColors.glassStrokeHighlight,
                width: elegido ? 2.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: borde,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    fondo.miniatura,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: AppColors.surface3ActiveGlass),
                  ),
                  // Nombre sobre una sombra para que se lea.
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Text(
                        fondo.etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (bloqueado)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  if (elegido)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.acento,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SinFondo extends StatelessWidget {
  const _SinFondo({required this.elegido, required this.onTap});

  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2Glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: elegido ? AppColors.acento : AppColors.glassStrokeHighlight,
          width: elegido ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.format_color_fill_rounded, color: AppColors.acento),
              const SizedBox(height: 6),
              Text('Sin fondo', style: AppTextStyles.bodyMd),
              Text(
                'Solo el color',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

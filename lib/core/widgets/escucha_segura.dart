import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Como ListenableBuilder, pero tolera avisos que llegan en plena
/// construcción. El router avisa de un cambio de ruta mientras procesa la
/// ruta inicial dentro de su propio build; un ListenableBuilder que lo
/// envuelve (main.dart → distribución y marco de escritorio) se marcaría
/// "sucio" siendo ancestro de lo que se está construyendo, y Flutter lo
/// prohíbe. Aquí ese aviso espera al final del cuadro.
class EscuchaSegura extends StatefulWidget {
  const EscuchaSegura({
    super.key,
    required this.escuchar,
    required this.builder,
  });

  final Listenable escuchar;
  final WidgetBuilder builder;

  @override
  State<EscuchaSegura> createState() => _EscuchaSeguraState();
}

class _EscuchaSeguraState extends State<EscuchaSegura> {
  bool _pendiente = false;

  @override
  void initState() {
    super.initState();
    widget.escuchar.addListener(_alCambiar);
  }

  @override
  void didUpdateWidget(EscuchaSegura anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.escuchar != widget.escuchar) {
      anterior.escuchar.removeListener(_alCambiar);
      widget.escuchar.addListener(_alCambiar);
    }
  }

  @override
  void dispose() {
    widget.escuchar.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_pendiente) return;
      _pendiente = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pendiente = false;
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

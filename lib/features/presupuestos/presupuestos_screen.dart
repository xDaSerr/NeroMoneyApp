import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/utils/formato_monto.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/piezas_movil.dart' show BotonAccionMovil;
import '../planes/data/membresia.dart';
import '../planes/providers/planes_providers.dart';
import '../planes/widgets/aviso_plan.dart';
import '../transactions/data/categoria.dart';
import 'data/planeacion.dart';
import 'providers/planeacion_providers.dart';

/// Colores de la barra de un presupuesto: bien / cerca del límite / pasado.
const colorAviso = Color(0xFFF59E0B);

Color colorNivel(NivelPresupuesto nivel) => switch (nivel) {
  NivelPresupuesto.bien => AppColors.acento,
  NivelPresupuesto.aviso => colorAviso,
  NivelPresupuesto.excedido => AppColors.outflowCrimson,
};

/// Presupuestos por categoría (este mes) y metas de ahorro. Gratis: uno de
/// cada uno; Plus y Pro: sin límite.
class PresupuestosScreen extends ConsumerWidget {
  const PresupuestosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(membresiaProvider).value?.plan ?? PlanNero.gratis;
    final estados = ref.watch(estadosPresupuestoProvider);
    final metas = ref.watch(metasProvider);
    final hoy = DateTime.now();

    final seccionPresupuestos = _Seccion(
      titulo: 'Presupuestos de ${mesesEs[hoy.month - 1]}',
      subtitulo: 'Un límite al mes por categoría.',
      onAgregar: () =>
          _agregarPresupuesto(context, ref, plan, estados.value ?? const []),
      contenido: estados.when(
        data: (lista) => lista.isEmpty
            ? const _Vacio(
                icono: Icons.donut_large_rounded,
                texto:
                    'Ponle un tope a una categoría (por ejemplo, '
                    'Alimentación) y te avisamos al llegar al 80%.',
              )
            : Column(
                children: [
                  for (final (i, e) in lista.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TarjetaPresupuesto(
                        estado: e,
                        onEditar: () => _editarPresupuesto(
                          context,
                          ref,
                          e.presupuesto,
                          lista,
                        ),
                        onEliminar: () => _confirmarEliminar(
                          context,
                          'el presupuesto de ${e.presupuesto.categoria}',
                          () => ref
                              .read(planeacionRepositoryProvider)
                              .eliminarPresupuesto(e.presupuesto.id),
                        ),
                      ).animate().fadeIn(delay: (50 * i).ms, duration: 250.ms),
                    ),
                ],
              ),
        loading: () => const _Cargando(),
        error: (e, _) => _Error('No se pudieron cargar tus presupuestos.'),
      ),
    );

    final seccionMetas = _Seccion(
      titulo: 'Metas de ahorro',
      subtitulo: 'Junta para lo que quieres, a tu ritmo.',
      onAgregar: () =>
          _agregarMeta(context, ref, plan, metas.value ?? const []),
      contenido: metas.when(
        data: (lista) => lista.isEmpty
            ? const _Vacio(
                icono: Icons.savings_outlined,
                texto:
                    'Crea una meta (un viaje, un fondo de emergencia) y '
                    've cuándo llegarás a este ritmo.',
              )
            : Column(
                children: [
                  for (final (i, m) in lista.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TarjetaMeta(
                        meta: m,
                        onAbonar: () => _abonar(context, ref, m),
                        onEditar: () => _editarMeta(context, ref, m),
                        onEliminar: () => _confirmarEliminar(
                          context,
                          'la meta "${m.nombre}"',
                          () => ref
                              .read(planeacionRepositoryProvider)
                              .eliminarMeta(m.id),
                        ),
                      ).animate().fadeIn(delay: (50 * i).ms, duration: 250.ms),
                    ),
                ],
              ),
        loading: () => const _Cargando(),
        error: (e, _) => _Error('No se pudieron cargar tus metas.'),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Atrás',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Presupuestos y metas',
                    style: AppTextStyles.display.copyWith(fontSize: 34),
                  ),
                  Text(
                    'Controla cuánto gastas y ahorra para lo que quieres.',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, c) => c.maxWidth >= 860
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: seccionPresupuestos),
                              const SizedBox(width: 24),
                              Expanded(child: seccionMetas),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              seccionPresupuestos,
                              const SizedBox(height: 22),
                              seccionMetas,
                            ],
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

  // --- Presupuestos ---

  Future<void> _agregarPresupuesto(
    BuildContext context,
    WidgetRef ref,
    PlanNero plan,
    List<EstadoPresupuesto> actuales,
  ) async {
    final maximo = plan.maxPresupuestos;
    if (maximo != null && actuales.length >= maximo) {
      await mostrarAvisoPlan(
        context,
        titulo: 'Presupuestos ilimitados con Plus',
        mensaje:
            'En el plan Gratis tienes $maximo presupuesto. Con Plus '
            '(\$1.50 al mes) creas todos los que quieras.',
      );
      return;
    }
    final usadas = {for (final e in actuales) e.presupuesto.categoria};
    if (usadas.length >= _categoriasPresupuesto.length) return;
    final r = await _dialogoPresupuesto(context, usadas: usadas);
    if (r == null) return;
    await ref
        .read(planeacionRepositoryProvider)
        .guardarPresupuesto(null, r.$1, r.$2);
  }

  Future<void> _editarPresupuesto(
    BuildContext context,
    WidgetRef ref,
    Presupuesto p,
    List<EstadoPresupuesto> todos,
  ) async {
    final usadas = {
      for (final e in todos)
        if (e.presupuesto.id != p.id) e.presupuesto.categoria,
    };
    final r = await _dialogoPresupuesto(context, actual: p, usadas: usadas);
    if (r == null) return;
    await ref
        .read(planeacionRepositoryProvider)
        .guardarPresupuesto(p.id, r.$1, r.$2);
  }

  // --- Metas ---

  Future<void> _agregarMeta(
    BuildContext context,
    WidgetRef ref,
    PlanNero plan,
    List<MetaAhorro> actuales,
  ) async {
    final maximo = plan.maxMetas;
    if (maximo != null && actuales.length >= maximo) {
      await mostrarAvisoPlan(
        context,
        titulo: 'Metas ilimitadas con Plus',
        mensaje:
            'En el plan Gratis tienes $maximo meta de ahorro. Con Plus '
            '(\$1.50 al mes) creas todas las que quieras.',
      );
      return;
    }
    final meta = await _dialogoMeta(context);
    if (meta == null) return;
    await ref.read(planeacionRepositoryProvider).guardarMeta(meta);
  }

  Future<void> _editarMeta(
    BuildContext context,
    WidgetRef ref,
    MetaAhorro m,
  ) async {
    final meta = await _dialogoMeta(context, actual: m);
    if (meta == null) return;
    await ref.read(planeacionRepositoryProvider).guardarMeta(meta);
  }

  Future<void> _abonar(
    BuildContext context,
    WidgetRef ref,
    MetaAhorro m,
  ) async {
    final monto = await _dialogoAbono(context, m);
    if (monto == null || monto == 0) return;
    await ref.read(planeacionRepositoryProvider).abonar(m.id, monto);
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    String que,
    Future<void> Function() eliminar,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('¿Eliminar?'),
        content: Text('Se eliminará $que. Tus movimientos no cambian.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppColors.outflowCrimson),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await eliminar();
  }
}

/// Categorías de gasto que admiten presupuesto ("Ajuste" no es gasto real).
final _categoriasPresupuesto = [
  for (final c in categoriasGasto)
    if (c.nombre != 'Ajuste') c,
];

double? _leerMonto(String texto) {
  final v = double.tryParse(texto.replaceAll(',', '').trim());
  return v == null || v.isNaN ? null : v;
}

final _soloMontos = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Devuelve (categoría, límite) o null si cancela.
Future<(String, double)?> _dialogoPresupuesto(
  BuildContext context, {
  Presupuesto? actual,
  required Set<String> usadas,
}) {
  final opciones = [
    for (final c in _categoriasPresupuesto)
      if (!usadas.contains(c.nombre)) c,
  ];
  var categoria = actual?.categoria ?? opciones.first.nombre;
  final limite = TextEditingController(
    text: actual == null ? '' : actual.limite.toStringAsFixed(0),
  );
  String? error;

  return showDialog<(String, double)>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => _DialogoFormulario(
        titulo: actual == null ? 'Nuevo presupuesto' : 'Editar presupuesto',
        onGuardar: () {
          final v = _leerMonto(limite.text);
          if (v == null || v <= 0) {
            setState(() => error = 'Escribe un monto mayor a 0.');
            return;
          }
          Navigator.pop(d, (categoria, v));
        },
        children: [
          DropdownButtonFormField<String>(
            initialValue: categoria,
            dropdownColor: AppColors.surface1,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final c in opciones)
                DropdownMenuItem(
                  value: c.nombre,
                  child: Row(
                    children: [
                      Icon(c.icono, size: 20, color: AppColors.acento),
                      const SizedBox(width: 10),
                      Text(c.nombre),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => categoria = v ?? categoria,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: limite,
            autofocus: actual == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_soloMontos],
            decoration: InputDecoration(
              labelText: 'Límite al mes',
              prefixText: '\$ ',
              errorText: error,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Los próximos 36 meses como opciones de fecha límite (fin de cada mes).
List<DateTime> _mesesFuturos() {
  final hoy = DateTime.now();
  return [
    for (var i = 1; i <= 36; i++) DateTime(hoy.year, hoy.month + i + 1, 0),
  ];
}

Future<MetaAhorro?> _dialogoMeta(BuildContext context, {MetaAhorro? actual}) {
  final nombre = TextEditingController(text: actual?.nombre ?? '');
  final objetivo = TextEditingController(
    text: actual == null ? '' : actual.objetivo.toStringAsFixed(0),
  );
  final ahorrado = TextEditingController(
    text: actual == null ? '' : actual.ahorrado.toStringAsFixed(0),
  );
  final meses = _mesesFuturos();
  // Si la fecha guardada ya no está en la lista (pasó), se ofrece igual.
  DateTime? fecha = actual?.fechaLimite;
  if (fecha != null && !meses.any((m) => _mismoMes(m, fecha!))) {
    meses.insert(0, fecha);
  }
  if (fecha != null) fecha = meses.firstWhere((m) => _mismoMes(m, fecha!));
  String? error;

  return showDialog<MetaAhorro>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => _DialogoFormulario(
        titulo: actual == null ? 'Nueva meta de ahorro' : 'Editar meta',
        onGuardar: () {
          final meta = _leerMonto(objetivo.text);
          final ya = ahorrado.text.trim().isEmpty
              ? 0.0
              : _leerMonto(ahorrado.text);
          if (nombre.text.trim().isEmpty) {
            setState(() => error = 'Ponle un nombre a tu meta.');
            return;
          }
          if (meta == null || meta <= 0 || ya == null || ya < 0) {
            setState(() => error = 'Revisa los montos.');
            return;
          }
          Navigator.pop(
            d,
            MetaAhorro(
              id: actual?.id ?? '',
              nombre: nombre.text.trim(),
              objetivo: meta,
              ahorrado: ya,
              creada: actual?.creada ?? DateTime.now(),
              fechaLimite: fecha,
            ),
          );
        },
        children: [
          TextField(
            controller: nombre,
            autofocus: actual == null,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Viaje a Oaxaca',
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: objetivo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_soloMontos],
            decoration: const InputDecoration(
              labelText: 'Cuánto quieres juntar',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ahorrado,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_soloMontos],
            decoration: const InputDecoration(
              labelText: 'Cuánto llevas (opcional)',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<DateTime?>(
            initialValue: fecha,
            dropdownColor: AppColors.surface1,
            menuMaxHeight: 320,
            decoration: const InputDecoration(labelText: 'Para cuándo'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin fecha')),
              for (final m in meses)
                DropdownMenuItem(
                  value: m,
                  child: Text(
                    '${_capitalizar(mesesEs[m.month - 1])} ${m.year}',
                  ),
                ),
            ],
            onChanged: (v) => fecha = v,
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.outflowCrimson,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Abonar (o retirar) dinero de una meta. Devuelve el cambio con signo.
Future<double?> _dialogoAbono(BuildContext context, MetaAhorro meta) {
  final monto = TextEditingController();
  var retirar = false;
  String? error;
  return showDialog<double>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => _DialogoFormulario(
        titulo: meta.nombre,
        textoGuardar: retirar ? 'Retirar' : 'Abonar',
        onGuardar: () {
          final v = _leerMonto(monto.text);
          if (v == null || v <= 0) {
            setState(() => error = 'Escribe un monto mayor a 0.');
            return;
          }
          if (retirar && v > meta.ahorrado) {
            setState(
              () => error =
                  'Solo llevas ${formatoMonto(meta.ahorrado)} en esta meta.',
            );
            return;
          }
          Navigator.pop(d, retirar ? -v : v);
        },
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Abonar')),
              ButtonSegment(value: true, label: Text('Retirar')),
            ],
            selected: {retirar},
            onSelectionChanged: (s) => setState(() => retirar = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: monto,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_soloMontos],
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: '\$ ',
              errorText: error,
              helperText:
                  'Llevas ${formatoMonto(meta.ahorrado)} de '
                  '${formatoMonto(meta.objetivo)}.',
            ),
          ),
        ],
      ),
    ),
  );
}

bool _mismoMes(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

String _capitalizar(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// "junio de 2027" (o "junio" si es este año).
String _mesYAnio(DateTime f) {
  final mes = mesesEs[f.month - 1];
  return f.year == DateTime.now().year ? mes : '$mes de ${f.year}';
}

class _DialogoFormulario extends StatelessWidget {
  const _DialogoFormulario({
    required this.titulo,
    required this.children,
    required this.onGuardar,
    this.textoGuardar = 'Guardar',
  });

  final String titulo;
  final List<Widget> children;
  final VoidCallback onGuardar;
  final String textoGuardar;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: AppTextStyles.headlineMd),
              const SizedBox(height: 18),
              ...children,
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
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
                    onPressed: onGuardar,
                    child: Text(textoGuardar),
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

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.subtitulo,
    required this.onAgregar,
    required this.contenido,
  });

  final String titulo;
  final String subtitulo;
  final VoidCallback onAgregar;
  final Widget contenido;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppTextStyles.headlineMd),
                  Text(
                    subtitulo,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            BotonAccionMovil(texto: 'Agregar', onTap: onAgregar),
          ],
        ),
        const SizedBox(height: 14),
        contenido,
      ],
    );
  }
}

/// Barra de progreso redondeada.
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({
    super.key,
    required this.valor,
    required this.color,
    this.alto = 10,
  });

  final double valor;
  final Color color;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valor.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: alto,
          color: color,
          backgroundColor: AppColors.surface3ActiveGlass,
        ),
      ),
    );
  }
}

class _TarjetaPresupuesto extends StatelessWidget {
  const _TarjetaPresupuesto({
    required this.estado,
    required this.onEditar,
    required this.onEliminar,
  });

  final EstadoPresupuesto estado;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final p = estado.presupuesto;
    final color = colorNivel(estado.nivel);
    final mensaje = switch (estado.nivel) {
      NivelPresupuesto.excedido =>
        'Te pasaste por ${formatoMonto(-estado.restante)}',
      NivelPresupuesto.aviso =>
        'Cuidado: te quedan ${formatoMonto(estado.restante)}',
      NivelPresupuesto.bien => 'Te quedan ${formatoMonto(estado.restante)}',
    };
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconoParaCategoria(p.categoria), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p.categoria, style: AppTextStyles.headlineSm),
              ),
              Text(
                '${(estado.proporcion * 100).round()}%',
                style: AppTextStyles.bodyLg.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _Menu(onEditar: onEditar, onEliminar: onEliminar),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: BarraProgreso(valor: estado.proporcion, color: color),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    mensaje,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: estado.nivel == NivelPresupuesto.bien
                          ? AppColors.textSecondary
                          : color,
                    ),
                  ),
                ),
                Text(
                  '${formatoMonto(estado.gastado)} de ${formatoMonto(p.limite)}',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMeta extends StatelessWidget {
  const _TarjetaMeta({
    required this.meta,
    required this.onAbonar,
    required this.onEditar,
    required this.onEliminar,
  });

  final MetaAhorro meta;
  final VoidCallback onAbonar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final proyeccion = meta.proyectar(DateTime.now());
    final color = meta.completada ? AppColors.inflowEmerald : AppColors.acento;
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                meta.completada
                    ? Icons.emoji_events_rounded
                    : Icons.savings_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  meta.nombre,
                  style: AppTextStyles.headlineSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Menu(onEditar: onEditar, onEliminar: onEliminar),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatoMonto(meta.ahorrado),
                      style: AppTextStyles.numericHero.copyWith(fontSize: 24),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'de ${formatoMonto(meta.objetivo)}',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${(meta.progreso * 100).round()}%',
                      style: AppTextStyles.bodyLg.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                BarraProgreso(valor: meta.progreso, color: color),
                const SizedBox(height: 10),
                Text(
                  textoProyeccion(meta, proyeccion),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: proyeccion.llegaATiempo == false
                        ? colorAviso
                        : AppColors.textSecondary,
                  ),
                ),
                if (!meta.completada) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onAbonar,
                    icon: Icon(Icons.add_rounded, color: AppColors.acento),
                    label: Text(
                      'Abonar',
                      style: AppTextStyles.bodyLg.copyWith(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.acento.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La frase de proyección de una meta (también la usa Inicio).
String textoProyeccion(MetaAhorro meta, ProyeccionMeta p) {
  if (p.completada) return '¡Meta cumplida! 🎉';
  final limite = meta.fechaLimite;
  if (p.fechaEstimada == null) {
    return limite == null
        ? 'Haz tu primer abono para calcular cuándo llegas.'
        : 'Para llegar en ${_mesYAnio(limite)}, junta '
              '${formatoMonto(p.necesarioPorMes!)} al mes.';
  }
  final llegas = 'A este ritmo llegas en ${_mesYAnio(p.fechaEstimada!)}';
  if (limite == null || p.llegaATiempo == true) return '$llegas.';
  return '$llegas. Para ${_mesYAnio(limite)} necesitas '
      '${formatoMonto(p.necesarioPorMes!)} al mes.';
}

class _Menu extends StatelessWidget {
  const _Menu({required this.onEditar, required this.onEliminar});

  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Opciones',
      color: AppColors.surface1,
      icon: Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
      itemBuilder: (_) => [
        PopupMenuItem(onTap: onEditar, child: const Text('Editar')),
        PopupMenuItem(
          onTap: onEliminar,
          child: Text(
            'Eliminar',
            style: TextStyle(color: AppColors.outflowCrimson),
          ),
        ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icono, color: AppColors.acento, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texto,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
  );
}

class _Error extends StatelessWidget {
  const _Error(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson),
  );
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../auth/providers/auth_providers.dart';
import '../onboarding/providers/perfil_providers.dart';
import '../planes/data/membresia.dart';
import '../planes/providers/planes_providers.dart';
import '../planes/widgets/aviso_plan.dart';
import '../profile/data/saludo_usuario.dart';
import '../transactions/data/categoria.dart';
import 'data/grupo.dart';
import 'providers/compartido_providers.dart';

final _soloMontos = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
double? _leerMonto(String t) => double.tryParse(t.replaceAll(',', '').trim());
String _fechaCorta(DateTime f) =>
    '${f.day} ${mesesEs[f.month - 1].substring(0, 3)}';

/// Gastos compartidos (Pro): una pareja o familia lleva sus gastos en
/// común, ve quién le debe a quién y ahorra junta para metas.
class CompartidoScreen extends ConsumerWidget {
  const CompartidoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupoId = ref.watch(grupoIdProvider);
    final grupo = ref.watch(grupoProvider);

    Widget contenido;
    if (grupoId.isLoading || (grupoId.value != null && grupo.isLoading)) {
      contenido = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (grupo.value == null) {
      contenido = const _SinGrupo();
    } else {
      contenido = _ConGrupo(grupo: grupo.value!);
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
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
                    'Compartido',
                    style: AppTextStyles.display.copyWith(fontSize: 34),
                  ),
                  Text(
                    'Gastos y metas en pareja o en familia.',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  contenido,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El nombre con el que el usuario aparece ante su grupo.
String _miNombre(WidgetRef ref) {
  final perfil = ref.read(perfilProvider).value;
  return datosDeSaludo(FirebaseAuth.instance.currentUser, perfil?.apodo).nombre;
}

void _avisar(BuildContext context, String texto) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(texto)));

String _mensajeError(Object e) => e is FirebaseFunctionsException
    ? (e.message ?? 'Algo salió mal. Intenta de nuevo.')
    : 'Algo salió mal. Revisa tu conexión.';

class _SinGrupo extends ConsumerStatefulWidget {
  const _SinGrupo();

  @override
  ConsumerState<_SinGrupo> createState() => _SinGrupoState();
}

class _SinGrupoState extends ConsumerState<_SinGrupo> {
  bool _ocupado = false;

  Future<void> _crear() async {
    final plan = ref.read(membresiaProvider).value?.plan ?? PlanNero.gratis;
    if (plan != PlanNero.pro) {
      await mostrarAvisoPlan(
        context,
        titulo: 'Gastos compartidos con Pro',
        mensaje:
            'Crea un grupo para tu pareja o tu familia con el plan Pro. Quien '
            'reciba tu código se une gratis.',
        plan: PlanNero.pro,
      );
      return;
    }
    final nombre = await _pedirTexto(
      context,
      titulo: 'Nuevo grupo',
      etiqueta: 'Nombre del grupo',
      sugerencia: 'Casa, Nosotros, Familia López…',
      textoBoton: 'Crear',
    );
    if (nombre == null || !mounted) return;
    await _correr(
      () => ref.read(compartidoRepositoryProvider).crearGrupo(
        nombre,
        _miNombre(ref),
      ),
    );
  }

  Future<void> _unirse() async {
    final codigo = await _pedirTexto(
      context,
      titulo: 'Unirme a un grupo',
      etiqueta: 'Código de 6 letras y números',
      sugerencia: 'Ej. K7MP2Q',
      textoBoton: 'Unirme',
      mayusculas: true,
    );
    if (codigo == null || !mounted) return;
    await _correr(
      () => ref.read(compartidoRepositoryProvider).unirse(
        codigo,
        _miNombre(ref),
      ),
    );
  }

  Future<void> _correr(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    try {
      await accion();
    } catch (e) {
      if (mounted) _avisar(context, _mensajeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget opcion(IconData icono, String titulo, String texto, VoidCallback f) =>
        Expanded(
          child: GestureDetector(
            onTap: _ocupado ? null : f,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icono, color: AppColors.acento, size: 34),
                    const SizedBox(height: 12),
                    Text(titulo, style: AppTextStyles.headlineSm),
                    const SizedBox(height: 4),
                    Text(
                      texto,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    final crear = opcion(
      Icons.group_add_rounded,
      'Crear un grupo',
      'Para tu pareja, tu familia o tus roomies. Te damos un código para '
          'invitarlos. (Pro)',
      _crear,
    );
    final unirse = opcion(
      Icons.vpn_key_rounded,
      'Tengo un código',
      'Únete al grupo que alguien ya creó. Es gratis.',
      _unirse,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Anoten los gastos de la casa (quién pagó y entre quiénes se '
            'divide), vean quién le debe a quién, y ahorren juntos para una '
            'meta. Sus cuentas personales siguen siendo privadas.',
            style: AppTextStyles.bodyLg,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 600
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [crear, const SizedBox(width: 14), unirse],
                )
              : Column(
                  children: [
                    Row(children: [crear]),
                    const SizedBox(height: 14),
                    Row(children: [unirse]),
                  ],
                ),
        ),
        if (_ocupado)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

enum _Vista { gastos, balance, metas }

class _ConGrupo extends ConsumerStatefulWidget {
  const _ConGrupo({required this.grupo});

  final Grupo grupo;

  @override
  ConsumerState<_ConGrupo> createState() => _ConGrupoState();
}

class _ConGrupoState extends ConsumerState<_ConGrupo> {
  var _vista = _Vista.gastos;

  Grupo get g => widget.grupo;
  String get _yo => ref.read(currentUidProvider) ?? '';

  Future<void> _salir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('¿Salir de "${g.nombre}"?'),
        content: Text(
          g.miembros.length <= 1
              ? 'Eres el único miembro: el grupo y sus gastos se borran.'
              : 'Dejarás de ver sus gastos y metas. Puedes volver con el código.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text(
              'Salir',
              style: TextStyle(color: AppColors.outflowCrimson),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(compartidoRepositoryProvider).salir();
    } catch (e) {
      if (mounted) _avisar(context, _mensajeError(e));
    }
  }

  Future<void> _nuevoGasto() async {
    final gasto = await showDialog<GastoCompartido>(
      context: context,
      builder: (_) => _DialogoGasto(grupo: g, yo: _yo),
    );
    if (gasto == null) return;
    try {
      await ref.read(compartidoRepositoryProvider).agregarGasto(g.id, gasto);
    } catch (e) {
      if (mounted) _avisar(context, _mensajeError(e));
    }
  }

  Future<void> _saldar(Deuda d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('¿Ya se pagó?'),
        content: Text(
          '${g.nombreDe(d.de)} le pagó ${formatoMonto(d.monto)} a '
          '${g.nombreDe(d.para)}. Se anota como pago y quedan a mano.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sí, anotar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(compartidoRepositoryProvider)
          .agregarGasto(
            g.id,
            GastoCompartido(
              id: '',
              monto: d.monto,
              descripcion: 'Pago a ${g.nombreDe(d.para)}',
              categoria: 'Pago',
              pagoUid: d.de,
              entre: [d.para],
              fecha: DateTime.now(),
              esPago: true,
            ),
          );
    } catch (e) {
      if (mounted) _avisar(context, _mensajeError(e));
    }
  }

  Future<void> _nuevaMeta() async {
    final nombre = await _pedirTexto(
      context,
      titulo: 'Meta en común',
      etiqueta: '¿Para qué ahorran?',
      sugerencia: 'Vacaciones, sala nueva…',
      textoBoton: 'Siguiente',
    );
    if (nombre == null || !mounted) return;
    final texto = await _pedirTexto(
      context,
      titulo: nombre,
      etiqueta: '¿Cuánto quieren juntar?',
      sugerencia: '15000',
      textoBoton: 'Crear meta',
      numerico: true,
    );
    final objetivo = texto == null ? null : _leerMonto(texto);
    if (objetivo == null || objetivo <= 0) return;
    try {
      await ref
          .read(compartidoRepositoryProvider)
          .crearMeta(g.id, nombre, objetivo, null);
    } catch (e) {
      if (mounted) _avisar(context, _mensajeError(e));
    }
  }

  Future<void> _aportar(MetaCompartida m) async {
    final texto = await _pedirTexto(
      context,
      titulo: 'Aportar a ${m.nombre}',
      etiqueta: '¿Cuánto aportas? (negativo para retirar)',
      sugerencia: '500',
      textoBoton: 'Aportar',
      numerico: true,
      permiteNegativo: true,
    );
    final monto = texto == null
        ? null
        : double.tryParse(texto.replaceAll(',', '').trim());
    if (monto == null || monto == 0) return;
    final mio = m.aportes[_yo] ?? 0;
    if (monto < 0 && -monto > mio) {
      if (mounted) {
        _avisar(context, 'Solo has aportado ${formatoMonto(mio)} a esta meta.');
      }
      return;
    }
    try {
      await ref.read(compartidoRepositoryProvider).aportar(g.id, m.id, monto);
    } catch (e) {
      if (mounted) _avisar(context, _mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastos = ref.watch(gastosGrupoProvider(g.id));
    final metas = ref.watch(metasGrupoProvider(g.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Encabezado del grupo: miembros y código para invitar ---
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_rounded, color: AppColors.acento, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(g.nombre, style: AppTextStyles.headlineMd),
                  ),
                  PopupMenuButton<String>(
                    color: AppColors.surface1,
                    onSelected: (_) => _salir(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'salir', child: Text('Salir del grupo')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in g.miembros)
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.secundario.withValues(
                          alpha: 0.5,
                        ),
                        child: Text(
                          g.nombreDe(m).substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                      label: Text(m == _yo ? '${g.nombreDe(m)} (tú)' : g.nombreDe(m)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Código para invitar: ${g.codigo}',
                      style: AppTextStyles.labelCode.copyWith(
                        color: AppColors.acento,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              'Únete a "${g.nombre}" en NeroMoney '
                              '(neromoneyapp.web.app → Compartido) con el código ${g.codigo}',
                        ),
                      );
                      if (context.mounted) {
                        _avisar(context, 'Invitación copiada. Pégala en WhatsApp.');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_Vista>(
                segments: const [
                  ButtonSegment(value: _Vista.gastos, label: Text('Gastos')),
                  ButtonSegment(value: _Vista.balance, label: Text('Cuentas claras')),
                  ButtonSegment(value: _Vista.metas, label: Text('Metas')),
                ],
                selected: {_vista},
                onSelectionChanged: (s) => setState(() => _vista = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        switch (_vista) {
          _Vista.gastos => _ListaGastos(
            grupo: g,
            gastos: gastos,
            onNuevo: _nuevoGasto,
            onEliminar: (id) => ref
                .read(compartidoRepositoryProvider)
                .eliminarGasto(g.id, id),
          ),
          _Vista.balance => _Balance(grupo: g, gastos: gastos, onSaldar: _saldar),
          _Vista.metas => _Metas(
            grupo: g,
            yo: _yo,
            metas: metas,
            onNueva: _nuevaMeta,
            onAportar: _aportar,
          ),
        },
      ],
    );
  }
}

class _ListaGastos extends StatelessWidget {
  const _ListaGastos({
    required this.grupo,
    required this.gastos,
    required this.onNuevo,
    required this.onEliminar,
  });

  final Grupo grupo;
  final AsyncValue<List<GastoCompartido>> gastos;
  final VoidCallback onNuevo;
  final void Function(String id) onEliminar;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final lista = gastos.value ?? const <GastoCompartido>[];
    final delMes = lista
        .where(
          (x) => !x.esPago && x.fecha.year == hoy.year && x.fecha.month == hoy.month,
        )
        .fold<double>(0, (s, x) => s + x.monto);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Este mes llevan ${formatoMonto(delMes)}',
                style: AppTextStyles.headlineSm,
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.acento,
                foregroundColor: AppColors.sobreAcento,
              ),
              onPressed: onNuevo,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Gasto'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (gastos.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (lista.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Anoten el primer gasto: la despensa, la renta, la luz… y quién '
              'lo pagó.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (final (i, x) in lista.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      x.esPago
                          ? Icons.handshake_rounded
                          : iconoParaCategoria(x.categoria),
                      color: x.esPago ? AppColors.inflowEmerald : AppColors.acento,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            x.descripcion.isEmpty ? x.categoria : x.descripcion,
                            style: AppTextStyles.bodyLg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            x.esPago
                                ? '${grupo.nombreDe(x.pagoUid)} · ${_fechaCorta(x.fecha)}'
                                : 'Pagó ${grupo.nombreDe(x.pagoUid)} · entre '
                                      '${x.entre.length} · ${_fechaCorta(x.fecha)}',
                            style: AppTextStyles.bodyMd,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatoMonto(x.monto),
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Borrar',
                      onPressed: () => onEliminar(x.id),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (30 * i).ms, duration: 200.ms),
            ),
      ],
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.grupo,
    required this.gastos,
    required this.onSaldar,
  });

  final Grupo grupo;
  final AsyncValue<List<GastoCompartido>> gastos;
  final void Function(Deuda) onSaldar;

  @override
  Widget build(BuildContext context) {
    final balance = BalanceGrupo.calcular(gastos.value ?? const []);
    final personas = {...grupo.miembros, ...balance.neto.keys}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cómo van', style: AppTextStyles.headlineSm),
              const SizedBox(height: 8),
              for (final p in personas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(grupo.nombreDe(p), style: AppTextStyles.bodyLg),
                      ),
                      Builder(
                        builder: (_) {
                          final v = balance.neto[p] ?? 0;
                          final (texto, color) = v > 0.009
                              ? ('le deben ${formatoMonto(v)}', AppColors.inflowEmerald)
                              : v < -0.009
                              ? ('debe ${formatoMonto(-v)}', AppColors.outflowCrimson)
                              : ('a mano', AppColors.textSecondary);
                          return Text(
                            texto,
                            style: AppTextStyles.bodyLg.copyWith(color: color),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (balance.deudas.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.task_alt_rounded, color: AppColors.inflowEmerald),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Están a mano. Nadie le debe a nadie.',
                    style: AppTextStyles.bodyLg,
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text('Para quedar a mano', style: AppTextStyles.headlineSm),
          const SizedBox(height: 8),
          for (final d in balance.deudas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${grupo.nombreDe(d.de)} le paga ${formatoMonto(d.monto)} '
                        'a ${grupo.nombreDe(d.para)}',
                        style: AppTextStyles.bodyLg,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onSaldar(d),
                      child: const Text('Ya se pagó'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Metas extends StatelessWidget {
  const _Metas({
    required this.grupo,
    required this.yo,
    required this.metas,
    required this.onNueva,
    required this.onAportar,
  });

  final Grupo grupo;
  final String yo;
  final AsyncValue<List<MetaCompartida>> metas;
  final VoidCallback onNueva;
  final void Function(MetaCompartida) onAportar;

  @override
  Widget build(BuildContext context) {
    final lista = metas.value ?? const <MetaCompartida>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Ahorrando juntos', style: AppTextStyles.headlineSm),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.acento,
                foregroundColor: AppColors.sobreAcento,
              ),
              onPressed: onNueva,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Meta'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Creen una meta en común (unas vacaciones, un mueble…) y cada '
              'quien aporta lo que pueda.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (final m in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.nombre, style: AppTextStyles.headlineSm),
                        ),
                        Text(
                          '${formatoMonto(m.juntado)} de ${formatoMonto(m.objetivo)}',
                          style: AppTextStyles.bodyLg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: m.progreso,
                        minHeight: 8,
                        backgroundColor: AppColors.glassStrokeStandard,
                        color: m.completada
                            ? AppColors.inflowEmerald
                            : AppColors.acento,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final e in m.aportes.entries)
                          if (e.value > 0)
                            Text(
                              '${e.key == yo ? 'Tú' : grupo.nombreDe(e.key)}: '
                              '${formatoMonto(e.value)}',
                              style: AppTextStyles.bodyMd,
                            ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => onAportar(m),
                        icon: const Icon(Icons.savings_rounded, size: 18),
                        label: Text(m.completada ? '¡Completada!' : 'Aportar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _DialogoGasto extends StatefulWidget {
  const _DialogoGasto({required this.grupo, required this.yo});

  final Grupo grupo;
  final String yo;

  @override
  State<_DialogoGasto> createState() => _DialogoGastoState();
}

class _DialogoGastoState extends State<_DialogoGasto> {
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();
  String _categoria = 'Alimentación';
  late String _pago = widget.yo;
  late final Set<String> _entre = {...widget.grupo.miembros};
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grupo;
    final monto = _leerMonto(_monto.text) ?? 0;
    return Dialog(
      backgroundColor: AppColors.surface1,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Gasto compartido', style: AppTextStyles.headlineMd),
              const SizedBox(height: 16),
              TextField(
                controller: _monto,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_soloMontos],
                decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Qué fue?',
                  hintText: 'Despensa, luz, renta…',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                dropdownColor: AppColors.surface1,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final c in categoriasGasto)
                    if (c.nombre != 'Ajuste')
                      DropdownMenuItem(value: c.nombre, child: Text(c.nombre)),
                ],
                onChanged: (v) => setState(() => _categoria = v ?? 'Otro'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _pago,
                dropdownColor: AppColors.surface1,
                decoration: const InputDecoration(labelText: '¿Quién pagó?'),
                items: [
                  for (final m in g.miembros)
                    DropdownMenuItem(
                      value: m,
                      child: Text(m == widget.yo ? 'Yo' : g.nombreDe(m)),
                    ),
                ],
                onChanged: (v) => setState(() => _pago = v ?? widget.yo),
              ),
              const SizedBox(height: 14),
              Text('Se divide entre', style: AppTextStyles.labelCode),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in g.miembros)
                    FilterChip(
                      label: Text(m == widget.yo ? 'Yo' : g.nombreDe(m)),
                      selected: _entre.contains(m),
                      onSelected: (s) => setState(
                        () => s ? _entre.add(m) : _entre.remove(m),
                      ),
                    ),
                ],
              ),
              if (monto > 0 && _entre.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Le toca ${formatoMonto(monto / _entre.length)} a cada quien.',
                    style: AppTextStyles.bodyMd,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.outflowCrimson,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
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
                    ),
                    onPressed: () {
                      if (monto <= 0) {
                        setState(() => _error = 'Escribe un monto mayor a 0.');
                        return;
                      }
                      if (_entre.isEmpty) {
                        setState(() => _error = 'Elige entre quiénes se divide.');
                        return;
                      }
                      Navigator.pop(
                        context,
                        GastoCompartido(
                          id: '',
                          monto: monto,
                          descripcion: _descripcion.text.trim(),
                          categoria: _categoria,
                          pagoUid: _pago,
                          entre: _entre.toList(),
                          fecha: DateTime.now(),
                        ),
                      );
                    },
                    child: const Text('Guardar'),
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

/// Ventanita con un solo campo de texto.
Future<String?> _pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  required String sugerencia,
  required String textoBoton,
  bool numerico = false,
  bool permiteNegativo = false,
  bool mayusculas = false,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: AppColors.surface1,
      title: Text(titulo),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: mayusculas
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        keyboardType: numerico
            ? TextInputType.numberWithOptions(
                decimal: true,
                signed: permiteNegativo,
              )
            : TextInputType.text,
        inputFormatters: numerico
            ? [
                FilteringTextInputFormatter.allow(
                  RegExp(permiteNegativo ? r'[0-9.,\-]' : r'[0-9.,]'),
                ),
              ]
            : null,
        decoration: InputDecoration(labelText: etiqueta, hintText: sugerencia),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(d, v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) Navigator.pop(d, ctrl.text.trim());
          },
          child: Text(textoBoton),
        ),
      ],
    ),
  );
}

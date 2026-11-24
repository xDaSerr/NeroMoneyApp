import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/utils/formato_monto.dart';
import '../../core/widgets/glass_card.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import '../transactions/data/transacciones_repository.dart';
import 'data/apunte_libreta.dart';
import 'providers/libreta_providers.dart';

final _soloMontos = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
double? _leerMonto(String texto) =>
    double.tryParse(texto.replaceAll(',', '').trim());
String _fechaCorta(DateTime f) =>
    '${f.day} ${mesesEs[f.month - 1].substring(0, 3)} ${f.year}';

/// La Libreta: lo que prestas y lo que te prestan. Cada apunte guarda a la
/// persona y su celular, cuándo prometió pagar, de qué cuenta salió el
/// dinero y los pagos que ha hecho (completos o en partes).
class LibretaScreen extends ConsumerStatefulWidget {
  const LibretaScreen({super.key});

  @override
  ConsumerState<LibretaScreen> createState() => _LibretaScreenState();
}

class _LibretaScreenState extends ConsumerState<LibretaScreen> {
  bool _verPagados = false;

  @override
  Widget build(BuildContext context) {
    final apuntes = ref.watch(apuntesLibretaProvider);
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final hoy = DateTime.now();

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Libreta',
                              style: AppTextStyles.display.copyWith(
                                fontSize: 34,
                              ),
                            ),
                            Text(
                              'Lo que prestas y lo que te prestan.',
                              style: AppTextStyles.bodyLg.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.acento,
                          foregroundColor: AppColors.sobreAcento,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () => _nuevo(context, cuentas),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Anotar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  apuntes.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Text(
                      'No se pudo cargar tu libreta. Revisa tu conexión.',
                      style: AppTextStyles.bodyLg,
                    ),
                    data: (lista) {
                      final resumen = ResumenLibreta.calcular(lista, hoy);
                      final visibles = lista
                          .where((a) => a.liquidado == _verPagados)
                          .toList();
                      if (!_verPagados) {
                        // Los que vencen primero, arriba.
                        visibles.sort((a, b) {
                          final da = a.diasParaPromesa(hoy) ?? 99999;
                          final db = b.diasParaPromesa(hoy) ?? 99999;
                          return da.compareTo(db);
                        });
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Resumen(resumen: resumen),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Pendientes'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Pagados'),
                                ),
                              ],
                              selected: {_verPagados},
                              onSelectionChanged: (s) =>
                                  setState(() => _verPagados = s.first),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (visibles.isEmpty)
                            _Vacio(pagados: _verPagados)
                          else
                            for (final (i, a) in visibles.indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child:
                                    _TarjetaApunte(
                                      apunte: a,
                                      cuentas: cuentas,
                                      onPago: () => _pago(context, a, cuentas),
                                      onEditar: () => _editar(context, a),
                                      onEliminar: () => _eliminar(context, a),
                                    ).animate().fadeIn(
                                      delay: (40 * i).ms,
                                      duration: 220.ms,
                                    ),
                              ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _nuevo(BuildContext context, List<Cuenta> cuentas) async {
    final apunte = await showDialog<ApunteLibreta>(
      context: context,
      builder: (_) => _DialogoNuevo(cuentas: cuentas),
    );
    if (apunte == null) return;
    try {
      await ref.read(libretaRepositoryProvider).crear(apunte);
      _avisar(
        apunte.meDeben
            ? 'Anotado: ${apunte.persona} te debe ${formatoMonto(apunte.monto)}.'
            : 'Anotado: le debes ${formatoMonto(apunte.monto)} a ${apunte.persona}.',
      );
    } on SaldoInsuficienteException catch (e) {
      _avisar('$e');
    } catch (_) {
      _avisar('No se pudo guardar. Revisa tu conexión.');
    }
  }

  Future<void> _pago(
    BuildContext context,
    ApunteLibreta apunte,
    List<Cuenta> cuentas,
  ) async {
    final pago = await showDialog<PagoLibreta>(
      context: context,
      builder: (_) => _DialogoPago(apunte: apunte, cuentas: cuentas),
    );
    if (pago == null) return;
    try {
      await ref
          .read(libretaRepositoryProvider)
          .registrarPago(
            apunte,
            monto: pago.monto,
            fecha: pago.fecha,
            cuentaId: pago.cuentaId,
          );
      final queda = apunte.pendiente - pago.monto;
      _avisar(
        queda <= 0.005
            ? '¡Listo! El préstamo con ${apunte.persona} quedó pagado.'
            : 'Pago anotado. Falta ${formatoMonto(queda)}.',
      );
    } on SaldoInsuficienteException catch (e) {
      _avisar('$e');
    } catch (_) {
      _avisar('No se pudo guardar el pago. Revisa tu conexión.');
    }
  }

  Future<void> _editar(BuildContext context, ApunteLibreta apunte) async {
    final datos = await showDialog<_DatosContacto>(
      context: context,
      builder: (_) => _DialogoEditar(apunte: apunte),
    );
    if (datos == null) return;
    try {
      await ref
          .read(libretaRepositoryProvider)
          .actualizarDatos(
            apunte.id,
            persona: datos.persona,
            telefono: datos.telefono,
            fechaPromesa: datos.fechaPromesa,
            nota: datos.nota,
          );
    } catch (_) {
      _avisar('No se pudo guardar. Revisa tu conexión.');
    }
  }

  Future<void> _eliminar(BuildContext context, ApunteLibreta apunte) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('¿Borrar el apunte de ${apunte.persona}?'),
        content: Text(
          apunte.cuentaId == null && apunte.pagos.every((p) => p.cuentaId == null)
              ? 'Se borra de tu libreta. No toca tus cuentas.'
              : 'Se borra de tu libreta. Los movimientos que generó siguen en '
                    'Movimientos; si quieres revertir el saldo, bórralos ahí.',
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
              'Borrar',
              style: TextStyle(color: AppColors.outflowCrimson),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(libretaRepositoryProvider).eliminar(apunte.id);
    } catch (_) {
      _avisar('No se pudo borrar. Revisa tu conexión.');
    }
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.resumen});

  final ResumenLibreta resumen;

  @override
  Widget build(BuildContext context) {
    Widget dato(String titulo, double valor, Color color, IconData icono) =>
        Expanded(
          child: GlassCard(
            child: Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: AppTextStyles.bodyMd),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatoMonto(valor),
                          style: AppTextStyles.headlineMd.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            dato(
              'Te deben',
              resumen.meDeben,
              AppColors.inflowEmerald,
              Icons.call_received_rounded,
            ),
            const SizedBox(width: 12),
            dato(
              'Debes',
              resumen.debo,
              AppColors.outflowCrimson,
              Icons.call_made_rounded,
            ),
          ],
        ),
        if (resumen.vencidos > 0) ...[
          const SizedBox(height: 10),
          Text(
            resumen.vencidos == 1
                ? '1 préstamo ya pasó su fecha de pago.'
                : '${resumen.vencidos} préstamos ya pasaron su fecha de pago.',
            style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFFF59E0B)),
          ),
        ],
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.pagados});

  final bool pagados;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            pagados ? Icons.task_alt_rounded : Icons.menu_book_rounded,
            size: 44,
            color: AppColors.acento,
          ),
          const SizedBox(height: 12),
          Text(
            pagados
                ? 'Aquí aparecerán los préstamos que ya se pagaron.'
                : 'Anota cuando prestes dinero o te presten: quién, cuánto, '
                      'su celular y cuándo quedó de pagar.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLg.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaApunte extends StatelessWidget {
  const _TarjetaApunte({
    required this.apunte,
    required this.cuentas,
    required this.onPago,
    required this.onEditar,
    required this.onEliminar,
  });

  final ApunteLibreta apunte;
  final List<Cuenta> cuentas;
  final VoidCallback onPago;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  String? get _nombreCuenta {
    for (final c in cuentas) {
      if (c.id == apunte.cuentaId) return c.nombre;
    }
    return null;
  }

  /// Solo dígitos (y el + del código de país) para tel: y WhatsApp.
  String get _telefonoLimpio =>
      apunte.telefono.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _llamar() =>
      launchUrl(Uri(scheme: 'tel', path: _telefonoLimpio));

  Future<void> _whatsapp() {
    var numero = _telefonoLimpio.replaceAll('+', '');
    // Un celular mexicano de 10 dígitos necesita el 52 para WhatsApp.
    if (numero.length == 10) numero = '52$numero';
    final texto = apunte.meDeben
        ? 'Hola, ${apunte.persona}. Te escribo por los '
              '${formatoMonto(apunte.pendiente)} que te presté.'
        : 'Hola, ${apunte.persona}. Te escribo por los '
              '${formatoMonto(apunte.pendiente)} que me prestaste.';
    return launchUrl(
      Uri.https('wa.me', '/$numero', {'text': texto}),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final color = apunte.meDeben
        ? AppColors.inflowEmerald
        : AppColors.outflowCrimson;
    final dias = apunte.diasParaPromesa(hoy);
    final (textoPromesa, colorPromesa) = switch (dias) {
      null when apunte.liquidado => ('Pagado', AppColors.inflowEmerald),
      null => ('Sin fecha de pago', AppColors.textSecondary),
      < 0 => (
        'Venció hace ${-dias} ${-dias == 1 ? 'día' : 'días'}',
        AppColors.outflowCrimson,
      ),
      0 => ('Quedó de pagar hoy', const Color(0xFFF59E0B)),
      1 => ('Paga mañana', const Color(0xFFF59E0B)),
      _ => (
        'Paga el ${_fechaCorta(apunte.fechaPromesa!)} · en $dias días',
        AppColors.textSecondary,
      ),
    };
    final cuenta = _nombreCuenta;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Text(
                  apunte.persona.isEmpty
                      ? '?'
                      : apunte.persona.substring(0, 1).toUpperCase(),
                  style: AppTextStyles.headlineSm.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apunte.persona,
                      style: AppTextStyles.headlineSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      apunte.meDeben ? 'Te debe' : 'Le debes',
                      style: AppTextStyles.bodyMd.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatoMonto(
                      apunte.liquidado ? apunte.monto : apunte.pendiente,
                    ),
                    style: AppTextStyles.headlineMd.copyWith(color: color),
                  ),
                  if (!apunte.liquidado && apunte.pagado > 0)
                    Text(
                      'de ${formatoMonto(apunte.monto)}',
                      style: AppTextStyles.bodySm,
                    ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Más',
                color: AppColors.surface1,
                onSelected: (v) => v == 'editar' ? onEditar() : onEliminar(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar datos')),
                  PopupMenuItem(value: 'borrar', child: Text('Borrar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: apunte.progreso,
              minHeight: 6,
              backgroundColor: AppColors.glassStrokeStandard,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(
                textoPromesa,
                style: AppTextStyles.bodyMd.copyWith(color: colorPromesa),
              ),
              Text(
                'Desde el ${_fechaCorta(apunte.fecha)}'
                '${cuenta == null ? '' : ' · $cuenta'}',
                style: AppTextStyles.bodyMd,
              ),
            ],
          ),
          if (apunte.nota.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              apunte.nota,
              style: AppTextStyles.bodyMd.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!apunte.liquidado)
                FilledButton.tonalIcon(
                  onPressed: onPago,
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: Text(
                    apunte.meDeben ? 'Me pagó' : 'Le pagué',
                  ),
                ),
              if (_telefonoLimpio.length >= 7) ...[
                OutlinedButton.icon(
                  onPressed: _llamar,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Llamar'),
                ),
                OutlinedButton.icon(
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// --- Formularios -----------------------------------------------------------

class _Formulario extends StatelessWidget {
  const _Formulario({
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

/// Botón que abre el calendario y muestra la fecha elegida.
class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.valor,
    required this.onCambio,
    required this.primera,
    required this.ultima,
    this.permiteQuitar = false,
  });

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime?> onCambio;
  final DateTime primera;
  final DateTime ultima;
  final bool permiteQuitar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onPressed: () async {
              final elegida = await showDatePicker(
                context: context,
                initialDate: valor ?? DateTime.now(),
                firstDate: primera,
                lastDate: ultima,
              );
              if (elegida != null) onCambio(elegida);
            },
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(
              valor == null ? etiqueta : '$etiqueta: ${_fechaCorta(valor!)}',
            ),
          ),
        ),
        if (permiteQuitar && valor != null)
          IconButton(
            tooltip: 'Quitar fecha',
            onPressed: () => onCambio(null),
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}

/// Elegir la cuenta, o "no mover mis cuentas".
class _CampoCuenta extends StatelessWidget {
  const _CampoCuenta({
    required this.etiqueta,
    required this.cuentas,
    required this.valor,
    required this.onCambio,
  });

  final String etiqueta;
  final List<Cuenta> cuentas;
  final String? valor;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: valor,
      isExpanded: true,
      dropdownColor: AppColors.surface1,
      decoration: InputDecoration(labelText: etiqueta),
      items: [
        for (final c in cuentas)
          DropdownMenuItem(
            value: c.id,
            child: Text(
              '${c.nombre} · ${c.tipo.etiqueta} · ${formatoMonto(c.saldoActual)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const DropdownMenuItem(
          value: null,
          child: Text('No mover mis cuentas (solo apuntarlo)'),
        ),
      ],
      onChanged: onCambio,
    );
  }
}

class _DialogoNuevo extends StatefulWidget {
  const _DialogoNuevo({required this.cuentas});

  final List<Cuenta> cuentas;

  @override
  State<_DialogoNuevo> createState() => _DialogoNuevoState();
}

class _DialogoNuevoState extends State<_DialogoNuevo> {
  var _direccion = DireccionPrestamo.yoPresto;
  final _persona = TextEditingController();
  final _telefono = TextEditingController();
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  late String? _cuentaId = _predeterminada();
  DateTime _fecha = DateTime.now();
  DateTime? _promesa;
  String? _error;

  String? _predeterminada() {
    if (widget.cuentas.isEmpty) return null;
    // Lo más común es prestar efectivo: se propone, pero siempre se pregunta.
    final efectivo = widget.cuentas
        .where((c) => c.tipo == TipoCuenta.efectivo)
        .firstOrNull;
    return (efectivo ??
            widget.cuentas.firstWhere(
              (c) => c.esPredeterminada,
              orElse: () => widget.cuentas.first,
            ))
        .id;
  }

  @override
  void dispose() {
    _persona.dispose();
    _telefono.dispose();
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _guardar() {
    final monto = _leerMonto(_monto.text);
    if (_persona.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre de la persona.');
      return;
    }
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Escribe un monto mayor a 0.');
      return;
    }
    final hoy = DateTime.now();
    final esHoy =
        _fecha.year == hoy.year &&
        _fecha.month == hoy.month &&
        _fecha.day == hoy.day;
    Navigator.pop(
      context,
      ApunteLibreta(
        id: '',
        direccion: _direccion,
        persona: _persona.text.trim(),
        telefono: _telefono.text.trim(),
        monto: monto,
        cuentaId: _cuentaId,
        fecha: esHoy ? hoy : DateTime(_fecha.year, _fecha.month, _fecha.day, 12),
        fechaPromesa: _promesa,
        nota: _nota.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yoPresto = _direccion == DireccionPrestamo.yoPresto;
    final hoy = DateTime.now();
    return _Formulario(
      titulo: 'Anotar en la libreta',
      textoGuardar: 'Anotar',
      onGuardar: _guardar,
      children: [
        SegmentedButton<DireccionPrestamo>(
          segments: const [
            ButtonSegment(
              value: DireccionPrestamo.yoPresto,
              icon: Icon(Icons.call_made_rounded),
              label: Text('Yo presté'),
            ),
            ButtonSegment(
              value: DireccionPrestamo.mePrestan,
              icon: Icon(Icons.call_received_rounded),
              label: Text('Me prestaron'),
            ),
          ],
          selected: {_direccion},
          onSelectionChanged: (s) => setState(() => _direccion = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _persona,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: yoPresto ? '¿A quién le prestaste?' : '¿Quién te prestó?',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telefono,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-()]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Celular (opcional)',
            hintText: '686 123 4567',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _monto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_soloMontos],
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixText: '\$ ',
          ),
        ),
        const SizedBox(height: 12),
        _CampoCuenta(
          etiqueta: yoPresto
              ? '¿De dónde salió el dinero?'
              : '¿A dónde entró el dinero?',
          cuentas: widget.cuentas,
          valor: _cuentaId,
          onCambio: (v) => setState(() => _cuentaId = v),
        ),
        const SizedBox(height: 12),
        _CampoFecha(
          etiqueta: 'Fecha del préstamo',
          valor: _fecha,
          primera: DateTime(hoy.year - 3),
          ultima: hoy,
          onCambio: (v) => setState(() => _fecha = v ?? DateTime.now()),
        ),
        const SizedBox(height: 10),
        _CampoFecha(
          etiqueta: yoPresto ? '¿Cuándo te paga?' : '¿Cuándo pagas?',
          valor: _promesa,
          primera: DateTime(hoy.year - 1),
          ultima: DateTime(hoy.year + 5),
          permiteQuitar: true,
          onCambio: (v) => setState(() => _promesa = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nota,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            hintText: 'Para la renta, quedó de pagar en dos partes…',
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.outflowCrimson,
            ),
          ),
      ],
    );
  }
}

class _DialogoPago extends StatefulWidget {
  const _DialogoPago({required this.apunte, required this.cuentas});

  final ApunteLibreta apunte;
  final List<Cuenta> cuentas;

  @override
  State<_DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<_DialogoPago> {
  late final _monto = TextEditingController(
    text: widget.apunte.pendiente.toStringAsFixed(2),
  );
  // Por defecto, la misma cuenta del préstamo (si sigue existiendo).
  late String? _cuentaId =
      widget.cuentas.any((c) => c.id == widget.apunte.cuentaId)
      ? widget.apunte.cuentaId
      : null;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apunte;
    return _Formulario(
      titulo: a.meDeben
          ? '${a.persona} te pagó'
          : 'Le pagaste a ${a.persona}',
      textoGuardar: 'Anotar pago',
      onGuardar: () {
        final v = _leerMonto(_monto.text);
        if (v == null || v <= 0) {
          setState(() => _error = 'Escribe un monto mayor a 0.');
          return;
        }
        if (v > a.pendiente + 0.005) {
          setState(
            () => _error = 'Solo falta ${formatoMonto(a.pendiente)}.',
          );
          return;
        }
        Navigator.pop(
          context,
          PagoLibreta(monto: v, fecha: DateTime.now(), cuentaId: _cuentaId),
        );
      },
      children: [
        TextField(
          controller: _monto,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_soloMontos],
          decoration: InputDecoration(
            labelText: '¿Cuánto?',
            prefixText: '\$ ',
            errorText: _error,
            helperText:
                'Falta ${formatoMonto(a.pendiente)} de ${formatoMonto(a.monto)}. '
                'Puede ser una parte.',
          ),
        ),
        const SizedBox(height: 14),
        _CampoCuenta(
          etiqueta: a.meDeben
              ? '¿A dónde entró el dinero?'
              : '¿De dónde salió el dinero?',
          cuentas: widget.cuentas,
          valor: _cuentaId,
          onCambio: (v) => setState(() => _cuentaId = v),
        ),
      ],
    );
  }
}

class _DatosContacto {
  const _DatosContacto(this.persona, this.telefono, this.fechaPromesa, this.nota);

  final String persona;
  final String telefono;
  final DateTime? fechaPromesa;
  final String nota;
}

class _DialogoEditar extends StatefulWidget {
  const _DialogoEditar({required this.apunte});

  final ApunteLibreta apunte;

  @override
  State<_DialogoEditar> createState() => _DialogoEditarState();
}

class _DialogoEditarState extends State<_DialogoEditar> {
  late final _persona = TextEditingController(text: widget.apunte.persona);
  late final _telefono = TextEditingController(text: widget.apunte.telefono);
  late final _nota = TextEditingController(text: widget.apunte.nota);
  late DateTime? _promesa = widget.apunte.fechaPromesa;
  String? _error;

  @override
  void dispose() {
    _persona.dispose();
    _telefono.dispose();
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    return _Formulario(
      titulo: 'Editar datos',
      onGuardar: () {
        if (_persona.text.trim().isEmpty) {
          setState(() => _error = 'Escribe el nombre de la persona.');
          return;
        }
        Navigator.pop(
          context,
          _DatosContacto(
            _persona.text.trim(),
            _telefono.text.trim(),
            _promesa,
            _nota.text.trim(),
          ),
        );
      },
      children: [
        TextField(
          controller: _persona,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Persona', errorText: _error),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Celular'),
        ),
        const SizedBox(height: 12),
        _CampoFecha(
          etiqueta: 'Fecha de pago',
          valor: _promesa,
          primera: DateTime(hoy.year - 1),
          ultima: DateTime(hoy.year + 5),
          permiteQuitar: true,
          onCambio: (v) => setState(() => _promesa = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nota,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Nota'),
        ),
        Text(
          'El monto y los pagos no se editan aquí, para que tus cuentas '
          'cuadren. Si te equivocaste, borra el apunte y anótalo de nuevo.',
          style: AppTextStyles.bodySm,
        ),
      ],
    );
  }
}

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/moneda/conversor_moneda.dart';
import '../../../core/widgets/dialogo_formulario.dart';
import '../../accounts/widgets/estilo_cuenta.dart';
import '../../accounts/data/cuenta.dart';
import '../../accounts/providers/cuentas_providers.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../../planes/data/membresia.dart';
import '../../planes/providers/planes_providers.dart';
import '../../planes/widgets/aviso_plan.dart';
import '../data/categoria.dart';
import '../data/transaccion.dart';
import '../data/transacciones_repository.dart';
import '../providers/transacciones_providers.dart';

/// "Crear movimiento" en el panel que sale de un botón "+" (ver
/// BotonConPanel). Misma lógica que la pantalla de alta manual
/// (AddTransactionScreen): una Transaccion y el saldo ajustado de forma
/// atómica, con la regla de saldo insuficiente del repositorio.
class PanelNuevoMovimiento extends ConsumerStatefulWidget {
  const PanelNuevoMovimiento({
    super.key,
    required this.onCerrar,
    this.tipoInicial = TipoTransaccion.gasto,
    this.cuentaInicial,
  });

  final VoidCallback onCerrar;
  final TipoTransaccion tipoInicial;

  /// Desde el detalle de una cuenta, ya viene elegida.
  final String? cuentaInicial;

  @override
  ConsumerState<PanelNuevoMovimiento> createState() =>
      _PanelNuevoMovimientoState();
}

class _PanelNuevoMovimientoState extends ConsumerState<PanelNuevoMovimiento> {
  final _descripcion = TextEditingController();
  final _monto = TextEditingController();
  late TipoTransaccion _tipo = widget.tipoInicial;
  String? _categoria;
  late String? _cuentaId = widget.cuentaInicial;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  bool _leyendoTicket = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // El resumen de abajo ("Gasto de $100.00 · Efectivo") sigue al monto.
    _monto.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _monto.dispose();
    super.dispose();
  }

  List<Categoria> get _categorias =>
      _tipo == TipoTransaccion.gasto ? categoriasGasto : categoriasIngreso;

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  /// Foto del ticket (Pro): el servidor lee monto, comercio, categoría y
  /// fecha, y aquí solo se prellenan los campos; el usuario revisa y crea.
  Future<void> _leerTicket() async {
    final plan = ref.read(membresiaProvider).value?.plan ?? PlanNero.gratis;
    if (plan != PlanNero.pro) {
      await mostrarAvisoPlan(
        context,
        plan: PlanNero.pro,
        titulo: 'Registra con la foto del ticket',
        mensaje:
            'Con NeroMoney Pro le tomas foto a tu ticket y llenamos el '
            'monto, el comercio, la categoría y la fecha por ti.',
      );
      return;
    }
    // En el teléfono se elige cámara o galería; en la web, el navegador
    // ya ofrece ambas al elegir un archivo.
    var origen = ImageSource.gallery;
    if (!kIsWeb) {
      final elegido = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface1,
        builder: (hoja) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(hoja, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(hoja, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (elegido == null) return;
      origen = elegido;
    }
    final foto = await ImagePicker().pickImage(
      source: origen,
      // Suficiente para leer un ticket y mucho más ligero de enviar.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (foto == null) return;
    setState(() {
      _leyendoTicket = true;
      _error = null;
    });
    try {
      final bytes = await foto.readAsBytes();
      final r = await FirebaseFunctions.instance
          .httpsCallable('leerTicketIA')
          .call<Map<String, dynamic>>({'imagen': base64Encode(bytes)});
      final d = r.data;
      if (d['esTicket'] != true) {
        setState(
          () => _error =
              'No encontré un ticket con total en esa foto. Prueba con más '
              'luz y que se vea completo.',
        );
        return;
      }
      setState(() {
        _tipo = TipoTransaccion.gasto;
        _monto.text = (d['monto'] as num).toStringAsFixed(2);
        final comercio = d['comercio'] as String? ?? '';
        if (comercio.isNotEmpty) _descripcion.text = comercio;
        _categoria = d['categoria'] as String?;
        final fecha = DateTime.tryParse(d['fecha'] as String? ?? '');
        if (fecha != null) _fecha = fecha;
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'No se pudo leer el ticket.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo leer el ticket. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _leyendoTicket = false);
    }
  }

  Future<void> _crear() async {
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', '.'));
    // A diferencia de la pantalla vieja (que no hacía nada), aquí se dice
    // qué falta.
    final falta = monto == null || monto <= 0
        ? 'Escribe un monto mayor a 0.'
        : _categoria == null
        ? 'Elige una categoría.'
        : _cuentaId == null
        ? 'Elige una cuenta.'
        : null;
    if (falta != null) {
      setState(() => _error = falta);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    // Hoy: la hora real de ahora. Otro día (un gasto olvidado): mediodía
    // de ese día y sin hora visible, porque el calendario no la pregunta.
    final ahora = DateTime.now();
    final esHoy =
        _fecha.year == ahora.year &&
        _fecha.month == ahora.month &&
        _fecha.day == ahora.day;
    final fecha = esHoy
        ? ahora
        : DateTime(_fecha.year, _fecha.month, _fecha.day, 12);
    try {
      await ref
          .read(transaccionesRepositoryProvider)
          .registrarTransaccion(
            Transaccion(
              id: '',
              monto: monto!,
              tipo: _tipo,
              categoria: _categoria!,
              descripcion: _descripcion.text.trim(),
              cuentaId: _cuentaId!,
              fecha: fecha,
              sinHora: !esHoy,
            ),
          );
      widget.onCerrar();
    } on SaldoInsuficienteException catch (e) {
      if (mounted) setState(() => _error = '$e');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final moneda = ref.watch(perfilProvider).value?.moneda ?? 'MXN';
    final iconos = {for (final c in _categorias) c.nombre: c.icono};
    final angosto = MediaQuery.sizeOf(context).width < 600;
    final cuenta = cuentas.where((c) => c.id == _cuentaId).firstOrNull;
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', '.'));
    final esGasto = _tipo == TipoTransaccion.gasto;

    Widget fila(List<Widget> hijos) => angosto
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, h) in hijos.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                h,
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, h) in hijos.indexed) ...[
                if (i > 0) const SizedBox(width: 24),
                Expanded(child: h),
              ],
            ],
          );

    return DialogoFormulario(
      icono: Icons.receipt_long_rounded,
      titulo: 'Nuevo movimiento',
      subtitulo: 'Registra un gasto o un ingreso.',
      onCerrar: widget.onCerrar,
      textoAccion: angosto ? 'Crear' : 'Crear movimiento',
      onAccion: _crear,
      cargando: _guardando,
      error: _error,
      resumen: monto != null && monto > 0 && cuenta != null
          ? '${esGasto ? 'Gasto' : 'Ingreso'} de '
                '${ConversorMoneda.formato(monto, cuenta.id)} · ${cuenta.nombre}'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Gasto / Ingreso (cambia las categorías disponibles) ---
          _SelectorTipo(
            tipo: _tipo,
            onCambiar: (t) => setState(() {
              _tipo = t;
              _categoria = null;
            }),
          ),
          const SizedBox(height: 14),
          // --- Foto del ticket (Pro): llena los campos de abajo ---
          OutlinedButton.icon(
            onPressed: _leyendoTicket ? null : _leerTicket,
            icon: _leyendoTicket
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.acento,
                    ),
                  )
                : Icon(
                    Icons.document_scanner_outlined,
                    color: AppColors.acento,
                  ),
            label: Text(
              _leyendoTicket
                  ? 'Leyendo tu ticket…'
                  : 'Llenar con foto del ticket',
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.acento,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.acento.withValues(alpha: 0.7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // --- Descripción (opcional) ---
          CampoEtiquetado(
            etiqueta: 'Descripción',
            child: TextField(
              controller: _descripcion,
              autofocus: !angosto,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.bodyLg,
              decoration: decoracionCampo(pista: 'ej. Café con amigos'),
            ),
          ),
          const SizedBox(height: 16),
          fila([
            // --- Monto ---
            CampoEtiquetado(
              etiqueta: 'Monto',
              child: TextField(
                controller: _monto,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTextStyles.bodyLg,
                onSubmitted: (_) => _crear(),
                decoration: decoracionCampo(pista: '0.00', prefijo: r'$ '),
              ),
            ),
            // --- Moneda: la de la cuenta (multimoneda, Pro) ---
            CampoEtiquetado(
              etiqueta: 'Moneda',
              child: InputDecorator(
                decoration: decoracionCampo(),
                child: Text(
                  _cuentaId == null
                      ? moneda
                      : ConversorMoneda.monedaDeCuenta(_cuentaId!),
                  style: AppTextStyles.bodyLg,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          fila([
            // --- Categoría ---
            CampoEtiquetado(
              etiqueta: 'Categoría',
              child: SelectorCampo<String>(
                // La llave reinicia el desplegable al cambiar Gasto/Ingreso.
                key: ValueKey('categoria-${_tipo.name}-$_categoria'),
                valor: _categoria,
                pista: 'Elige una',
                opciones: {for (final c in _categorias) c.nombre: c.nombre},
                icono: (nombre) => iconos[nombre] ?? Icons.category_outlined,
                onCambiar: (c) => setState(() {
                  _categoria = c;
                  _error = null;
                }),
              ),
            ),
            // --- Cuenta ---
            CampoEtiquetado(
              etiqueta: 'Cuenta',
              child: cuentas.isEmpty
                  ? Text(
                      'Todavía no tienes cuentas. Agrega una en Cuentas.',
                      style: AppTextStyles.bodyMd,
                    )
                  : SelectorCampo<String>(
                      valor: _cuentaId,
                      pista: 'Elige una',
                      opciones: {for (final c in cuentas) c.id: c.nombre},
                      icono: (id) => iconoDeTipo(
                        cuentas.firstWhere((c) => c.id == id).tipo,
                      ),
                      onCambiar: (id) => setState(() {
                        _cuentaId = id;
                        _error = null;
                      }),
                    ),
            ),
          ]),
          const SizedBox(height: 16),
          // --- Fecha (no se registran movimientos a futuro) ---
          CampoEtiquetado(
            etiqueta: 'Fecha',
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: decoracionCampo().copyWith(
                  suffixIcon: Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
                child: Text(
                  '${_fecha.day} ${mesesEs[_fecha.month - 1].substring(0, 3)} ${_fecha.year}',
                  style: AppTextStyles.bodyLg,
                ),
              ),
            ),
          ),
          if (cuenta != null) ...[
            const SizedBox(height: 10),
            Text(
              'Disponible en ${cuenta.nombre}: '
              '${ConversorMoneda.formato(cuenta.saldoActual, cuenta.id)}',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textPlaceholder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Gasto | Ingreso" a todo lo ancho, con su color e ícono.
class _SelectorTipo extends StatelessWidget {
  const _SelectorTipo({required this.tipo, required this.onCambiar});

  final TipoTransaccion tipo;
  final ValueChanged<TipoTransaccion> onCambiar;

  @override
  Widget build(BuildContext context) {
    Widget opcion(
      TipoTransaccion valor,
      String texto,
      IconData icono,
      Color color,
    ) {
      final activo = tipo == valor;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onCambiar(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: activo
                  ? color.withValues(alpha: 0.30)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: activo ? color : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: color, size: 24),
                const SizedBox(width: 10),
                Text(
                  texto,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontSize: 18,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2Glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassStrokeHighlight),
      ),
      child: Row(
        children: [
          opcion(
            TipoTransaccion.gasto,
            'Gasto',
            Icons.shopping_cart_outlined,
            AppColors.outflowCrimson,
          ),
          opcion(
            TipoTransaccion.ingreso,
            'Ingreso',
            Icons.trending_up_rounded,
            AppColors.inflowEmerald,
          ),
        ],
      ),
    );
  }
}

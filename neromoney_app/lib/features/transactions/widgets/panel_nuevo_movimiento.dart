import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/formulario_panel.dart';
import '../../accounts/data/cuenta.dart';
import '../../accounts/providers/cuentas_providers.dart';
import '../../onboarding/providers/perfil_providers.dart';
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
  });

  final VoidCallback onCerrar;
  final TipoTransaccion tipoInicial;

  @override
  ConsumerState<PanelNuevoMovimiento> createState() =>
      _PanelNuevoMovimientoState();
}

class _PanelNuevoMovimientoState extends ConsumerState<PanelNuevoMovimiento> {
  final _descripcion = TextEditingController();
  final _monto = TextEditingController();
  late TipoTransaccion _tipo = widget.tipoInicial;
  String? _categoria;
  String? _cuentaId;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  String? _error;

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
              fecha: _fecha,
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

    return FormularioPanel(
      titulo: 'Crear\nmovimiento',
      textoAccion: 'Crear',
      cargando: _guardando,
      error: _error,
      onAccion: _crear,
      onCerrar: widget.onCerrar,
      // --- Gasto / Ingreso (cambia las categorías disponibles) ---
      debajoDelTitulo: PildorasPanel<TipoTransaccion>(
        opciones: const {
          TipoTransaccion.gasto: 'Gasto',
          TipoTransaccion.ingreso: 'Ingreso',
        },
        colores: const {
          TipoTransaccion.gasto: AppColors.outflowCrimson,
          TipoTransaccion.ingreso: AppColors.inflowEmerald,
        },
        seleccionado: _tipo,
        onCambiar: (t) => setState(() {
          _tipo = t;
          _categoria = null;
        }),
      ),
      campos: [
        // --- Descripción (opcional) ---
        TextoPanel(
          etiqueta: 'Descripción',
          controller: _descripcion,
          pista: 'ej. Café con amigos',
          autofocus: true,
        ),
        // --- Monto + moneda de la cuenta (la app no convierte monedas) ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextoPanel(
                etiqueta: 'Monto',
                controller: _monto,
                pista: '0.00',
                numerico: true,
                onEnviar: _crear,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: CampoPanel(
                etiqueta: 'Moneda',
                child: Text(moneda, style: AppTextStyles.bodyLg),
              ),
            ),
          ],
        ),
        // --- Categoría ---
        SelectorPanel<String>(
          etiqueta: 'Categoría',
          valor: _categoria,
          textoVacio: 'Sin categoría',
          opciones: {for (final c in _categorias) c.nombre: c.nombre},
          icono: (nombre) => iconos[nombre] ?? Icons.category_outlined,
          onCambiar: (c) => setState(() {
            _categoria = c;
            _error = null;
          }),
        ),
        // --- Cuenta (con su disponible, para saber de dónde sale) ---
        if (cuentas.isEmpty)
          CampoPanel(
            etiqueta: 'Cuenta',
            child: Text(
              'Todavía no tienes cuentas. Agrega una en Cuentas.',
              style: AppTextStyles.bodyMd,
            ),
          )
        else
          SelectorPanel<String>(
            etiqueta: 'Cuenta',
            valor: _cuentaId,
            textoVacio: 'Sin cuenta',
            opciones: {
              for (final c in cuentas)
                c.id: '${c.nombre} · ${formatoMonto(c.saldoActual)}',
            },
            onCambiar: (id) => setState(() {
              _cuentaId = id;
              _error = null;
            }),
          ),
        // --- Fecha (no se registran movimientos a futuro) ---
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _elegirFecha,
          child: CampoPanel(
            etiqueta: 'Fecha',
            alFinal: Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            child: Text(
              '${_fecha.day} ${mesesEs[_fecha.month - 1].substring(0, 3)} ${_fecha.year}',
              style: AppTextStyles.bodyLg,
            ),
          ),
        ),
      ],
    );
  }
}

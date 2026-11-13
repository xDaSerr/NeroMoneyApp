import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/formulario_panel.dart';
import '../data/cuenta.dart';
import '../providers/cuentas_providers.dart';

/// "Nueva cuenta" en el panel que sale de un botón "+" (ver BotonConPanel).
/// Misma lógica que CuentaFormCard: el nombre se autocompleta solo en
/// Efectivo, y en crédito el límite es obligatorio (sin él no se puede
/// calcular la deuda, ver Cuenta.deudaActual).
class PanelNuevaCuenta extends ConsumerStatefulWidget {
  const PanelNuevaCuenta({super.key, required this.onCerrar});

  final VoidCallback onCerrar;

  @override
  ConsumerState<PanelNuevaCuenta> createState() => _PanelNuevaCuentaState();
}

class _PanelNuevaCuentaState extends ConsumerState<PanelNuevaCuenta> {
  final _nombre = TextEditingController(text: TipoCuenta.efectivo.etiqueta);
  final _saldo = TextEditingController();
  final _limite = TextEditingController();
  TipoCuenta _tipo = TipoCuenta.efectivo;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _saldo.dispose();
    _limite.dispose();
    super.dispose();
  }

  void _elegirTipo(TipoCuenta tipo) {
    final actual = _nombre.text.trim();
    final esPorDefecto =
        actual.isEmpty || actual == TipoCuenta.efectivo.etiqueta;
    setState(() {
      _tipo = tipo;
      // Si el usuario ya escribió un nombre propio, no se toca.
      if (!esPorDefecto) return;
      // Solo "Efectivo" se autocompleta; los demás llevan el nombre del
      // banco o tarjeta, que el usuario escribe.
      if (tipo == TipoCuenta.efectivo) {
        _nombre.text = tipo.etiqueta;
      } else {
        _nombre.clear();
      }
    });
  }

  double? _numero(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _crear() async {
    final nombre = _nombre.text.trim();
    final saldo = _numero(_saldo);
    final esCredito = _tipo == TipoCuenta.credito;
    final limite = _numero(_limite);
    final falta = nombre.isEmpty
        ? 'Escribe un nombre para la cuenta.'
        : saldo == null
        ? (esCredito
              ? 'Escribe tu disponible actual.'
              : 'Escribe el saldo actual.')
        : esCredito && limite == null
        ? 'En una tarjeta de crédito el límite es obligatorio.'
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
          .read(cuentasRepositoryProvider)
          .crearCuenta(
            Cuenta(
              id: '', // Firestore le asigna el id real al crearla.
              nombre: nombre,
              tipo: _tipo,
              saldoActual: saldo!,
              limiteCredito: esCredito ? limite : null,
            ),
          );
      widget.onCerrar();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo crear la cuenta. Revisa tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esCredito = _tipo == TipoCuenta.credito;
    return FormularioPanel(
      titulo: 'Nueva\ncuenta',
      textoAccion: 'Crear',
      cargando: _guardando,
      error: _error,
      onAccion: _crear,
      onCerrar: widget.onCerrar,
      // --- Tipo de cuenta ---
      debajoDelTitulo: PildorasPanel<TipoCuenta>(
        opciones: {for (final t in TipoCuenta.values) t: t.etiqueta},
        seleccionado: _tipo,
        onCambiar: _elegirTipo,
      ),
      campos: [
        // --- Nombre (ej. "Efectivo", "TC de Nu") ---
        TextoPanel(
          etiqueta: 'Nombre',
          controller: _nombre,
          pista: 'ej. TC de Nu',
          capitalizar: TextCapitalization.words,
          autofocus: true,
        ),
        // --- Saldo (en crédito: lo DISPONIBLE, no lo que se debe) ---
        TextoPanel(
          etiqueta: esCredito ? 'Disponible actual' : 'Saldo actual',
          controller: _saldo,
          pista: '0.00',
          numerico: true,
          onEnviar: _crear,
        ),
        // --- Límite: solo en crédito, y ahí es obligatorio ---
        if (esCredito) ...[
          TextoPanel(
            etiqueta: 'Límite de crédito',
            controller: _limite,
            pista: '0.00',
            numerico: true,
            onEnviar: _crear,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'La deuda se calcula sola (límite − disponible). Si pagas la '
              'tarjeta o te suben el límite, actualízalo después desde '
              'Cuentas → Editar.',
              style: AppTextStyles.bodySm,
            ),
          ),
        ],
      ],
    );
  }
}

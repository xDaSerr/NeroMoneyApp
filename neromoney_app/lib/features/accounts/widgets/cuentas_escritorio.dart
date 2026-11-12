import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/piezas_escritorio.dart';
import '../../home/providers/privacidad_inicio_provider.dart';
import '../data/cuenta.dart';
import '../providers/cuentas_providers.dart';
import 'cuenta_form_card.dart';
import 'cuenta_tile.dart';
import 'editar_cuenta_sheet.dart';

/// Cuentas en ventana ancha (ver referencia de diseño del usuario):
/// patrimonio arriba, filtros por tipo y las tarjetas en columnas, cada
/// una con su menú "⋯" (ver detalle / editar). Borrar sigue viviendo en el
/// detalle de la cuenta, con su confirmación.
class CuentasEscritorio extends ConsumerStatefulWidget {
  const CuentasEscritorio({super.key});

  @override
  ConsumerState<CuentasEscritorio> createState() => _CuentasEscritorioState();
}

class _CuentasEscritorioState extends ConsumerState<CuentasEscritorio> {
  TipoCuenta? _filtro; // null = todas

  void _agregar() => mostrarFormularioNuevaCuenta(
    context: context,
    onAgregar: (cuenta) =>
        ref.read(cuentasRepositoryProvider).crearCuenta(cuenta),
  );

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(cuentasProvider);
    final privacidad = ref.watch(privacidadInicioProvider);
    final ocultar = privacidad.value ?? true;

    return Scaffold(
      body: SingleChildScrollView(
        padding: margenSeccionEscritorio,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoSeccion),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EncabezadoEscritorio(
                  titulo: 'Cuentas y bolsillos',
                  subtitulo: 'Todo tu dinero, organizado.',
                  acciones: [
                    // --- Botón "Agregar cuenta" → formulario de alta ---
                    BotonContorno(
                      texto: 'Agregar cuenta',
                      icono: Icons.add_rounded,
                      onTap: _agregar,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                cuentasAsync.when(
                  data: (cuentas) => _contenido(cuentas, ocultar, privacidad),
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    ),
                  ),
                  error: (e, _) => Text(
                    'No se pudieron cargar tus cuentas: $e',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.outflowCrimson,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(
    List<Cuenta> cuentas,
    bool ocultar,
    AsyncValue<bool> privacidad,
  ) {
    if (cuentas.isEmpty) {
      return TarjetaEscritorio(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Todavía no tienes ninguna cuenta. Agrega la primera para '
                'empezar a registrar tus movimientos.',
                style: AppTextStyles.bodyLg,
              ),
            ),
            BotonContorno(
              texto: 'Agregar cuenta',
              icono: Icons.add_rounded,
              relleno: true,
              onTap: _agregar,
            ),
          ],
        ),
      );
    }
    if (_filtro != null && !cuentas.any((c) => c.tipo == _filtro)) {
      _filtro = null;
    }
    final visibles = _filtro == null
        ? cuentas
        : cuentas.where((c) => c.tipo == _filtro).toList();
    final total = cuentas.fold<double>(0, (a, c) => a + c.efectoEnPatrimonio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Patrimonio total (sin tarjetas de crédito, ver Cuenta.efectoEnPatrimonio) ---
        TarjetaEscritorio(
          color: AppColors.secundario.withValues(alpha: 0.12),
          padding: const EdgeInsets.fromLTRB(30, 22, 26, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PATRIMONIO TOTAL',
                      style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ocultar ? '••••••' : formatoMonto(total),
                      semanticsLabel: ocultar ? 'Patrimonio oculto' : null,
                      style: AppTextStyles.numericHero.copyWith(fontSize: 46),
                    ),
                    Text(
                      'Sin contar tarjetas de crédito',
                      style: AppTextStyles.bodyLg.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // --- Ojo: oculta patrimonio y saldos (misma preferencia que Inicio) ---
                  IconButton(
                    tooltip: ocultar ? 'Mostrar saldos' : 'Ocultar saldos',
                    iconSize: 28,
                    color: AppColors.acento,
                    icon: Icon(
                      ocultar
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: privacidad.isLoading
                        ? null
                        : () => ref
                              .read(privacidadInicioProvider.notifier)
                              .alternar()
                              .catchError((Object _) {}),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    cuentas.length == 1
                        ? '1 cuenta'
                        : '${cuentas.length} cuentas',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // --- Filtros por tipo (solo los tipos que sí tienes) ---
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Filtro(
              texto: 'Todas (${cuentas.length})',
              seleccionado: _filtro == null,
              onTap: () => setState(() => _filtro = null),
            ),
            for (final tipo in TipoCuenta.values)
              if (cuentas.any((c) => c.tipo == tipo))
                _Filtro(
                  texto:
                      '${tipo.etiqueta} (${cuentas.where((c) => c.tipo == tipo).length})',
                  seleccionado: _filtro == tipo,
                  onTap: () => setState(() => _filtro = tipo),
                ),
          ],
        ),
        const SizedBox(height: 22),
        // --- Tarjetas en columnas ---
        LayoutBuilder(
          builder: (context, restricciones) {
            // Proporción de tarjeta física (ver CuentaTile): a la mitad del
            // ancho quedaban enormes, así que van tantas columnas como
            // quepan de ~380 px (mínimo 2).
            const separacion = 24.0;
            final columnas = (restricciones.maxWidth / 380).floor().clamp(2, 4);
            final ancho =
                (restricciones.maxWidth - separacion * (columnas - 1)) /
                columnas;
            return Wrap(
              spacing: separacion,
              runSpacing: separacion,
              children: [
                for (final (i, cuenta) in visibles.indexed)
                  SizedBox(
                        width: ancho,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => context.push(
                            '/accounts/detalle',
                            extra: cuenta.id,
                          ),
                          child: CuentaTile(
                            cuenta: cuenta,
                            ocultarImportes: ocultar,
                            accion: _menu(cuenta),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                      .scale(
                        begin: const Offset(0.97, 0.97),
                        duration: 300.ms,
                        curve: Curves.easeOutCubic,
                      ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// "⋯" de cada tarjeta: ver detalle o editar.
  Widget _menu(Cuenta cuenta) {
    return PopupMenuButton<void>(
      tooltip: 'Opciones',
      color: AppColors.surface1,
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: () => context.push('/accounts/detalle', extra: cuenta.id),
          child: const Text('Ver detalle y movimientos'),
        ),
        PopupMenuItem(
          onTap: () => mostrarEditorDeCuenta(
            context: context,
            cuenta: cuenta,
            onGuardar: (actualizada) => ref
                .read(cuentasRepositoryProvider)
                .actualizarCuenta(actualizada),
          ),
          child: const Text('Editar'),
        ),
      ],
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado
                ? AppColors.acento.withValues(alpha: 0.14)
                : AppColors.surface2Glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: seleccionado
                  ? AppColors.acento.withValues(alpha: 0.6)
                  : AppColors.glassStrokeStandard,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seleccionado) ...[
                Icon(Icons.check_rounded, size: 18, color: AppColors.acento),
                const SizedBox(width: 6),
              ],
              Text(
                texto,
                style: AppTextStyles.bodyLg.copyWith(
                  color: seleccionado
                      ? AppColors.acento
                      : AppColors.textSecondary,
                  fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

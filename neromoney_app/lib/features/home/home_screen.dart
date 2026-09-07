import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import '../accounts/widgets/cuenta_tile.dart';
import '../onboarding/providers/perfil_providers.dart';
import '../transactions/data/resumen_gastos.dart';
import '../transactions/data/transaccion.dart';
import '../transactions/providers/transacciones_providers.dart';
import '../transactions/widgets/movimiento_tile.dart';

/// "Gastos de Septiembre", con mayúscula inicial — `_meses` los guarda en
/// minúsculas porque así se usan en otros textos ("en octubre..."), así
/// que la mayúscula se aplica aquí, solo para el título de la tarjeta.
String _nombreMes(int mes) {
  final nombre = _meses[mes - 1];
  return 'Gastos de ${nombre[0].toUpperCase()}${nombre.substring(1)}';
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

// Las categorías de gasto son libres (el usuario escribe lo que quiera), no
// tienen un color fijo asignado — por eso el resumen de gastos les da color
// en el orden en que aparecen, ciclando esta paleta.
const _paletaCategorias = [
  AppColors.secondaryViolet,
  AppColors.primaryCyan,
  AppColors.outflowCrimson,
  AppColors.inflowEmerald,
];

/// Dashboard principal. Sigue la estructura de la pantalla de Inicio del
/// Stitch (saludo, patrimonio, accesos rápidos, cuentas, gastos del mes,
/// últimos movimientos) pero solo con datos reales: se omiten a propósito
/// el estado de "Lucy conectada", la alerta de Lucy y el botón de voz,
/// porque el asistente de IA todavía no existe — agregarlos ahora sería
/// simular una función que no funciona. Se van sumando conforme se
/// construyan de verdad (ver CLAUDE.md → regla de fidelidad al Stitch).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentasAsync = ref.watch(cuentasProvider);
    final transaccionesAsync = ref.watch(transaccionesProvider);
    final nombreAsistente =
        ref.watch(perfilProvider).value?.nombreAsistente ?? 'tu asistente';
    final saludo = _datosDeSaludo(FirebaseAuth.instance.currentUser);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Encabezado: marca "NeroMoney" + avatar (atajo a Perfil) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NeroMoney', style: AppTextStyles.headlineSm),
                      Text(
                        'INICIO',
                        style: AppTextStyles.labelCode.copyWith(
                          color: AppColors.primaryCyan,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.secondaryViolet.withValues(
                        alpha: 0.3,
                      ),
                      child: Text(saludo.inicial, style: AppTextStyles.bodyLg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // --- Saludo con el nombre real de la sesión (Google) o el correo ---
              Text(
                'Hola, ${saludo.nombre} 👋',
                style: AppTextStyles.headlineLg,
              ),
              const SizedBox(height: 20),

              cuentasAsync.when(
                data: (cuentas) {
                  if (cuentas.isEmpty) {
                    // --- Banner que recuerda agregar una cuenta (ver _AvisoSinCuentas abajo) ---
                    return _AvisoSinCuentas(nombreAsistente: nombreAsistente);
                  }

                  // Patrimonio total = solo dinero real (efectivo/débito/vale/
                  // otro). Las tarjetas de crédito nunca entran aquí, ni
                  // sumando ni restando — ver Cuenta.efectoEnPatrimonio.
                  final total = cuentas.fold<double>(
                    0,
                    (acc, c) => acc + c.efectoEnPatrimonio,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Tarjeta de patrimonio total + accesos rápidos ---
                      // Una sola tarjeta (no dos bloques separados): así se
                      // ve igual que en el Stitch, en vez de que los botones
                      // queden pegados sueltos justo debajo del número.
                      GlassCard(
                        color: AppColors.secondaryViolet.withValues(
                          alpha: 0.10,
                        ),
                        // padding: cero a propósito. GlassCard normalmente le pone
                        // 16px de relleno a su `child` — si el reflejo fuera el
                        // `child` con ese relleno ya puesto, se quedaría metido 16px
                        // hacia adentro por cada lado (justo el "marco" sin efecto
                        // que se veía). Al poner el relleno cero aquí y meterlo a
                        // mano solo alrededor del texto (ver Padding abajo), el
                        // reflejo (Positioned.fill) sí llega hasta el borde real de
                        // la tarjeta completa.
                        padding: EdgeInsets.zero,
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PATRIMONIO TOTAL',
                                    style: AppTextStyles.labelCode,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    style: AppTextStyles.numericHero,
                                  ),
                                  const SizedBox(height: 20),
                                  // --- Accesos rápidos: Ingreso / Gasto / Transferir / Analizar ---
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _AccionRapida(
                                          icon: Icons.add_rounded,
                                          label: 'Ingreso',
                                          onTap: () => context.push(
                                            '/add-transaction',
                                            extra: TipoTransaccion.ingreso,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _AccionRapida(
                                          icon: Icons.remove_rounded,
                                          label: 'Gasto',
                                          onTap: () => context.push(
                                            '/add-transaction',
                                            extra: TipoTransaccion.gasto,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _AccionRapida(
                                          icon: Icons.swap_horiz_rounded,
                                          label: 'Transferir',
                                          // Transferencias entre cuentas todavía no existen —
                                          // decimos la verdad en vez de fingir que el botón hace algo.
                                          onTap: () =>
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Transferencias entre cuentas: próximamente.',
                                                      ),
                                                    ),
                                                  ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _AccionRapida(
                                          icon: Icons.insights_rounded,
                                          label: 'Analizar',
                                          onTap: () => context.go('/reports'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // --- Reflejo de vidrio/plástico, estático (no animado) ---
                            // Se eligió la versión estática y no el "barrido" de luz
                            // en loop que también trae el Stitch: una animación
                            // repitiéndose sola para siempre contradice la regla del
                            // proyecto de animaciones sutiles ("sin exagerar"). Es
                            // puramente decorativo — IgnorePointer para que nunca le
                            // robe el toque a los botones de abajo.
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    // La franja de brillo (la que sube y baja de
                                    // intensidad) es lo que hace que se sienta como un
                                    // reflejo de verdad y no solo un tinte parejo — se
                                    // regresa al patrón original del Stitch. Lo que de
                                    // verdad causaba que "no cubriera todo" era el
                                    // relleno de la tarjeta (ya arreglado arriba), no
                                    // este degradado — por eso ahora sí debería llegar
                                    // hasta las esquinas reales.
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      stops: const [0.0, 0.35, 0.45, 0.55, 1.0],
                                      colors: [
                                        Colors.white.withValues(alpha: 0.12),
                                        Colors.white.withValues(alpha: 0.02),
                                        Colors.white.withValues(alpha: 0.20),
                                        Colors.white.withValues(alpha: 0.04),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- Encabezado "Tus cuentas y bolsillos" + "Ver todas (N)" ---
                      // Ahora "Cuentas" es su propia pestaña (ver app_shell.dart),
                      // por eso este enlace usa .go() (cambia de pestaña) en vez
                      // de .push() (apilar una pantalla encima).
                      Row(
                        children: [
                          // Expanded + ellipsis: si el título no cabe junto al botón
                          // (nombres largos, pantallas angostas), se trunca con "…" en
                          // vez de desbordarse fuera de la pantalla.
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Tus cuentas y bolsillos',
                                    style: AppTextStyles.headlineSm,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // --- Insignia con el conteo, como en el Stitch ---
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface3ActiveGlass,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${cuentas.length}',
                                    style: AppTextStyles.labelCode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/accounts'),
                            child: Text('Ver todas (${cuentas.length})'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // --- Cuentas deslizantes: carrusel horizontal, igual que en el Stitch ---
                      _CuentasCarrusel(cuentas: cuentas),
                      const SizedBox(height: 24),

                      // --- Gastos del mes por categoría (se omite si no hay ninguno) ---
                      transaccionesAsync.maybeWhen(
                        data: (transacciones) =>
                            _GastosDelMes(transacciones: transacciones),
                        orElse: () => const SizedBox.shrink(),
                      ),

                      // --- Vista previa de los últimos movimientos ---
                      transaccionesAsync.maybeWhen(
                        data: (transacciones) => _UltimosMovimientos(
                          transacciones: transacciones,
                          cuentas: cuentas,
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryCyan,
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  'No se pudo cargar tu información: $e',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.outflowCrimson,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nombre a mostrar en el saludo + inicial para el avatar. Prioriza el
/// nombre real (lo trae Google Sign-In); si el usuario entró con
/// email/contraseña no hay nombre guardado todavía (ver roadmap → Perfil
/// completo), así que usamos lo que hay antes de la "@" del correo.
({String nombre, String inicial}) _datosDeSaludo(User? usuario) {
  final displayName = usuario?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    final primerNombre = displayName.split(' ').first;
    return (
      nombre: primerNombre,
      inicial: primerNombre.substring(0, 1).toUpperCase(),
    );
  }
  final email = usuario?.email ?? '';
  final prefijo = email.contains('@') ? email.split('@').first : email;
  if (prefijo.isEmpty) return (nombre: 'ahí', inicial: '?');
  return (nombre: prefijo, inicial: prefijo.substring(0, 1).toUpperCase());
}

class _AvisoSinCuentas extends StatelessWidget {
  const _AvisoSinCuentas({required this.nombreAsistente});
  final String nombreAsistente;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: AppColors.secondaryViolet.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.secondaryVioletTint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oye, aún no tienes cuentas — agrega una para que pueda ayudarte con tus finanzas.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                // --- Botón "Agregar cuenta" del banner → pestaña Cuentas ---
                GradientButton(
                  label: 'Agregar cuenta',
                  expand: false,
                  onPressed: () => context.go('/accounts'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un botón circular de la fila de accesos rápidos (Ingreso/Gasto/
/// Transferir/Analizar).
class _AccionRapida extends StatelessWidget {
  const _AccionRapida({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.surface3ActiveGlass,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryCyan),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.bodySm),
          ],
        ),
      ),
    );
  }
}

/// Carrusel horizontal de cuentas — deslizable con el dedo, tal como en el
/// Stitch (en vez de una cuadrícula fija que solo cabe en pantalla). Cada
/// tarjeta tiene un ancho fijo para que se vea la siguiente "asomando" al
/// borde, invitando a deslizar.
class _CuentasCarrusel extends StatelessWidget {
  const _CuentasCarrusel({required this.cuentas});
  final List<Cuenta> cuentas;

  static const _anchoTarjeta = 260.0;
  // CuentaTile ahora tiene proporción real de tarjeta (1.586) — el alto se
  // calcula a partir del ancho para que no le sobre ni le falte espacio.
  static const _altoCarrusel = _anchoTarjeta / 1.586;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _altoCarrusel,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cuentas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(
          width: _anchoTarjeta,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () =>
                context.push('/accounts/detalle', extra: cuentas[i].id),
            child: CuentaTile(cuenta: cuentas[i]),
          ),
        ),
      ),
    );
  }
}

/// Resumen de gastos del mes en curso, agrupados por categoría — construido
/// con transacciones reales (no hace falta el asistente de IA ni la
/// pantalla de Reportes para esto, los datos ya existen).
class _GastosDelMes extends StatelessWidget {
  const _GastosDelMes({required this.transacciones});
  final List<Transaccion> transacciones;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final desde = DateTime(hoy.year, hoy.month, 1);
    final hasta = DateTime(hoy.year, hoy.month + 1, 1);
    // Mismo cálculo (neteando reembolsos por categoría) que usa Lucy al
    // responder "¿cuánto llevo gastado?" — ver ResumenGastos.
    final resumen = ResumenGastos.calcular(
      transacciones,
      desde: desde,
      hasta: hasta,
    );
    if (resumen.porCategoria.isEmpty) return const SizedBox.shrink();
    final total = resumen.total;
    final entradas = resumen.porCategoria.entries.toList();

    // Top 4 categorías; el resto se agrupa en "Otros" para no saturar.
    final visibles = entradas.take(4).toList();
    final restoTotal = entradas
        .skip(4)
        .fold<double>(0, (acc, e) => acc + e.value);
    if (restoTotal > 0) visibles.add(MapEntry('Otros', restoTotal));

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      // Se me había olvidado meterlo en una tarjeta — sin esto se veía
      // "suelto" contra el fondo, a diferencia del Stitch.
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El nombre del mes va en SU PROPIO renglón, a todo lo ancho de
            // la tarjeta — antes competía por espacio con el monto en la
            // misma fila y se truncaba con "…" en meses largos (ej.
            // "septiembre"). Así siempre se ve completo, sin importar el mes.
            Text(_nombreMes(hoy.month), style: AppTextStyles.headlineSm),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total del periodo', style: AppTextStyles.bodySm),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: AppTextStyles.headlineSm,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Barra apilada: proporción de cada categoría sobre el total del mes ---
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (var i = 0; i < visibles.length; i++)
                      Expanded(
                        flex: (visibles[i].value * 1000 / total)
                            .round()
                            .clamp(1, 1000),
                        child: Container(
                          color:
                              _paletaCategorias[i % _paletaCategorias.length],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- Leyenda en cuadrícula de 2 columnas, como en el Stitch ---
            for (var i = 0; i < visibles.length; i += 2)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i + 2 < visibles.length ? 10 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _LeyendaCategoria(
                        color: _paletaCategorias[i % _paletaCategorias.length],
                        entrada: visibles[i],
                        total: total,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: i + 1 < visibles.length
                          ? _LeyendaCategoria(
                              color:
                                  _paletaCategorias[(i + 1) %
                                      _paletaCategorias.length],
                              entrada: visibles[i + 1],
                              total: total,
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un renglón de la leyenda de "Gastos del mes": punto de color + nombre de
/// categoría + porcentaje y monto.
class _LeyendaCategoria extends StatelessWidget {
  const _LeyendaCategoria({
    required this.color,
    required this.entrada,
    required this.total,
  });

  final Color color;
  final MapEntry<String, double> entrada;
  final double total;

  @override
  Widget build(BuildContext context) {
    final porcentaje = (entrada.value / total * 100).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${entrada.key} $porcentaje% (\$${entrada.value.toStringAsFixed(0)})',
            style: AppTextStyles.bodySm,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Vista previa de los últimos movimientos, con enlace al historial
/// completo (/movements). Reutiliza MovimientoTile — la misma fila que se
/// usa en la pantalla de Movimientos.
class _UltimosMovimientos extends StatelessWidget {
  const _UltimosMovimientos({
    required this.transacciones,
    required this.cuentas,
  });
  final List<Transaccion> transacciones;
  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context) {
    if (transacciones.isEmpty) return const SizedBox.shrink();
    final cuentasPorId = {for (final c in cuentas) c.id: c};
    final ultimos = transacciones.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Mismo motivo que en el encabezado de Cuentas: Expanded + ellipsis
            // evita que el título empuje al botón fuera de la pantalla.
            Expanded(
              child: Text(
                'Últimos movimientos',
                style: AppTextStyles.headlineSm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/movements'),
              child: const Text('Historial completo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final t in ultimos)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MovimientoTile(
              transaccion: t,
              nombreCuenta: cuentasPorId[t.cuentaId]?.nombre ?? '—',
            ),
          ),
      ],
    );
  }
}

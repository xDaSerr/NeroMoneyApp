/// Filtro de periodo de la pantalla de Movimientos (teléfono y escritorio).
enum PeriodoMovimientos {
  todo('Todo el historial'),
  esteMes('Este mes'),
  mesPasado('Mes pasado'),
  ultimos3Meses('Últimos 3 meses'),
  esteAnio('Este año');

  const PeriodoMovimientos(this.nombre);
  final String nombre;

  /// Rango [desde, hasta) para `transaccionesPorRangoProvider`.
  (DateTime, DateTime) get rango {
    final hoy = DateTime.now();
    return switch (this) {
      todo => (DateTime(2000), DateTime(2100)),
      esteMes => (
        DateTime(hoy.year, hoy.month),
        DateTime(hoy.year, hoy.month + 1),
      ),
      mesPasado => (
        DateTime(hoy.year, hoy.month - 1),
        DateTime(hoy.year, hoy.month),
      ),
      ultimos3Meses => (
        DateTime(hoy.year, hoy.month - 2),
        DateTime(hoy.year, hoy.month + 1),
      ),
      esteAnio => (DateTime(hoy.year), DateTime(hoy.year + 1)),
    };
  }
}

/// Todos / Ingresos / Gastos.
enum TipoFiltroMovimientos { todos, ingresos, gastos }

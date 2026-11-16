import 'package:cloud_firestore/cloud_firestore.dart';

import '../../transactions/data/resumen_gastos.dart';
import '../../transactions/data/transaccion.dart';

/// Límite mensual de gasto para una categoría. Vive en
/// `usuarios/{uid}/presupuestos/{id}`.
class Presupuesto {
  const Presupuesto({
    required this.id,
    required this.categoria,
    required this.limite,
  });

  final String id;
  final String categoria;
  final double limite;

  factory Presupuesto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Presupuesto(
      id: doc.id,
      categoria: data['categoria'] as String,
      limite: (data['limite'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'categoria': categoria,
    'limite': limite,
  };
}

enum NivelPresupuesto { bien, aviso, excedido }

/// Cuánto lleva gastado un presupuesto en el mes. Usa ResumenGastos, el
/// mismo cálculo que Inicio, Reportes y Lucy (un reembolso resta).
class EstadoPresupuesto {
  const EstadoPresupuesto(this.presupuesto, this.gastado);

  final Presupuesto presupuesto;
  final double gastado;

  /// Desde el 80% se avisa.
  static const umbralAviso = 0.8;

  double get proporcion =>
      presupuesto.limite <= 0 ? 0 : gastado / presupuesto.limite;
  double get restante => presupuesto.limite - gastado;

  NivelPresupuesto get nivel => proporcion >= 1
      ? NivelPresupuesto.excedido
      : proporcion >= umbralAviso
      ? NivelPresupuesto.aviso
      : NivelPresupuesto.bien;

  /// Estados del mes de [ahora], los más apretados primero.
  static List<EstadoPresupuesto> calcular(
    List<Presupuesto> presupuestos,
    List<Transaccion> transacciones,
    DateTime ahora,
  ) {
    final resumen = ResumenGastos.calcular(
      transacciones,
      desde: DateTime(ahora.year, ahora.month),
      hasta: DateTime(ahora.year, ahora.month + 1),
    );
    return [
      for (final p in presupuestos)
        EstadoPresupuesto(p, resumen.porCategoria[p.categoria] ?? 0),
    ]..sort((a, b) => b.proporcion.compareTo(a.proporcion));
  }
}

/// Meta de ahorro ("Viaje: $15,000 para junio"). Lo ahorrado lo abona el
/// usuario a mano. Vive en `usuarios/{uid}/metas/{id}`.
class MetaAhorro {
  const MetaAhorro({
    required this.id,
    required this.nombre,
    required this.objetivo,
    required this.ahorrado,
    required this.creada,
    this.fechaLimite,
  });

  final String id;
  final String nombre;
  final double objetivo;
  final double ahorrado;
  final DateTime creada;
  final DateTime? fechaLimite;

  double get progreso =>
      objetivo <= 0 ? 0 : (ahorrado / objetivo).clamp(0.0, 1.0);
  bool get completada => ahorrado >= objetivo;

  factory MetaAhorro.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MetaAhorro(
      id: doc.id,
      nombre: data['nombre'] as String,
      objetivo: (data['objetivo'] as num).toDouble(),
      ahorrado: (data['ahorrado'] as num?)?.toDouble() ?? 0,
      creada: (data['creada'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaLimite: (data['fechaLimite'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nombre': nombre,
    'objetivo': objetivo,
    'ahorrado': ahorrado,
    'creada': Timestamp.fromDate(creada),
    'fechaLimite': fechaLimite == null
        ? null
        : Timestamp.fromDate(fechaLimite!),
  };

  /// A este ritmo, ¿cuándo llega? Y si tiene fecha límite, ¿cuánto falta
  /// ahorrar por mes para llegar a tiempo?
  ProyeccionMeta proyectar(DateTime ahora) {
    if (completada) return const ProyeccionMeta(completada: true);
    final falta = objetivo - ahorrado;
    // Menos de un mes desde que se creó cuenta como un mes: si no, el
    // primer abono haría parecer que ahorras muchísimo al mes.
    final meses = (ahora.difference(creada).inDays / _diasPorMes).clamp(
      1.0,
      double.infinity,
    );
    final ritmo = ahorrado / meses;
    DateTime? estimada;
    if (ritmo > 0) {
      estimada = ahora.add(
        Duration(days: (falta / ritmo * _diasPorMes).ceil()),
      );
    }
    double? porMes;
    bool? aTiempo;
    if (fechaLimite != null) {
      final mesesRestantes =
          (fechaLimite!.difference(ahora).inDays / _diasPorMes).clamp(
            1.0,
            double.infinity,
          );
      porMes = falta / mesesRestantes;
      aTiempo = estimada != null && !estimada.isAfter(fechaLimite!);
    }
    return ProyeccionMeta(
      ritmoMensual: ritmo,
      fechaEstimada: estimada,
      necesarioPorMes: porMes,
      llegaATiempo: aTiempo,
    );
  }

  static const _diasPorMes = 30.44;
}

class ProyeccionMeta {
  const ProyeccionMeta({
    this.completada = false,
    this.ritmoMensual = 0,
    this.fechaEstimada,
    this.necesarioPorMes,
    this.llegaATiempo,
  });

  final bool completada;
  final double ritmoMensual;

  /// null = todavía no hay abonos para calcular un ritmo.
  final DateTime? fechaEstimada;
  final double? necesarioPorMes;
  final bool? llegaATiempo;
}

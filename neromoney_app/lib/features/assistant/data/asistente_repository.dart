import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../accounts/data/cuenta.dart';
import '../../transactions/data/resumen_gastos.dart';
import '../../transactions/data/transaccion.dart';
import '../../transactions/data/transacciones_repository.dart';
import 'borrador_pendiente.dart';
import 'mensaje_chat.dart';

/// Todo el "cerebro" de Lucy del lado de la app: manda los mensajes al
/// Cloud Function (ver `functions/index.js` → `interpretarMensajeIA`),
/// resuelve a qué cuenta real aplica cada transacción, y guarda la
/// conversación + el borrador pendiente en Firestore para que sincronicen
/// entre dispositivos.
///
/// Importante: la resolución de cuenta ocurre AQUÍ, en Dart, no en el
/// modelo de IA — DeepSeek solo entrega `cuentaMencionada` (el texto tal
/// cual lo dijo el usuario). Así el comportamiento es determinista y usa
/// las cuentas reales del usuario, que la IA ni conoce. Ver "Resolución de
/// ambigüedad de cuenta" en CLAUDE.md para los 4 niveles que se implementan
/// abajo.
class AsistenteRepository {
  AsistenteRepository(
    this._firestore,
    this._functions,
    this._uid,
    this._transaccionesRepository,
  );

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String _uid;
  final TransaccionesRepository _transaccionesRepository;

  DocumentReference<Map<String, dynamic>> get _usuarioDoc =>
      _firestore.collection('usuarios').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _mensajes =>
      _usuarioDoc.collection('mensajesAsistente');

  // Documento fijo: solo puede haber UN borrador pendiente a la vez (ver
  // BorradorPendiente).
  DocumentReference<Map<String, dynamic>> get _borradorDoc =>
      _usuarioDoc.collection('estadoAsistente').doc('borrador');

  Stream<List<MensajeChat>> observarMensajes({int limite = 200}) {
    return _mensajes
        .orderBy('fecha')
        .limitToLast(limite)
        .snapshots()
        .map((snap) => snap.docs.map(MensajeChat.fromFirestore).toList());
  }

  Stream<BorradorPendiente?> observarBorrador() {
    return _borradorDoc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final borrador = BorradorPendiente.fromFirestore(snap.data()!);
      // Una pregunta vieja sin responder no debe seguir bloqueando la UI.
      return borrador.expirado ? null : borrador;
    });
  }

  /// El texto del último mensaje que guardó Lucy — lo usa la pantalla de
  /// chat para saber qué leer en voz alta cuando el usuario le dictó por
  /// micrófono (ver "por qué" en AssistantChatScreen). No es más elegante
  /// que devolver el texto desde `enviarMensaje` directamente, pero evita
  /// tener que hacer que TODOS los métodos internos (`_resolverYRegistrar`,
  /// `_completarConCuenta`, etc.) propaguen un valor de retorno hasta
  /// arriba solo para este caso.
  String? ultimoMensajeAsistente;
  MensajeChat? ultimaRespuesta;
  OrigenTransaccion _origenActual = OrigenTransaccion.iaTexto;

  Future<void> _guardarMensaje(
    AutorMensaje autor,
    String contenido, {
    List<String> chipsCuentas = const [],
    bool registrado = false,
  }) async {
    final mensaje = MensajeChat(
      id: '',
      autor: autor,
      contenido: contenido,
      fecha: DateTime.now(),
      chipsCuentas: chipsCuentas,
      registrado: registrado,
    );
    await _mensajes.add(mensaje.toFirestore());
    // La barra rápida muestra el mismo mensaje confirmado que el chat.
    // Nunca marcar como registrado antes de que termine la escritura.
    if (autor == AutorMensaje.asistente) {
      ultimoMensajeAsistente = contenido;
      ultimaRespuesta = mensaje;
    }
  }

  // Solo para continuidad conversacional INMEDIATA (ej. si el mensaje
  // anterior fue una pregunta de Lucy y este la responde a medias). La
  // memoria de hechos financieros (montos, categorías, cuentas de gastos
  // pasados) ya NO depende de esto — viene de `_transaccionesRecientes`,
  // que son datos reales de Firestore, no texto de chat. Por eso este
  // historial puede ser corto: "Limpiar conversación" borra este texto sin
  // que Lucy pierda la capacidad de recordar transacciones reales.
  static const _limiteHistorial = 6;

  // Cuántas transacciones reales recientes se le mandan como contexto —
  // suficiente para cubrir "hoy" en un uso normal y para resolver
  // referencias a un gasto de hace un par de días (ej. un reembolso).
  static const _limiteTransaccionesContexto = 20;

  /// Los últimos mensajes YA guardados (sin incluir el que se está por
  /// mandar) — le da a DeepSeek continuidad conversacional inmediata.
  Future<List<Map<String, String>>> _historialReciente() async {
    final snap = await _mensajes
        .orderBy('fecha')
        .limitToLast(_limiteHistorial)
        .get();
    return snap.docs.map((doc) {
      final m = MensajeChat.fromFirestore(doc);
      return {
        'role': m.autor == AutorMensaje.usuario ? 'user' : 'assistant',
        'content': m.contenido,
      };
    }).toList();
  }

  /// Las transacciones reales más recientes del usuario, como contexto para
  /// la IA — esta es la memoria financiera de verdad (nunca se pierde al
  /// limpiar el chat, ver `limpiarHistorial`). Le sirve a Lucy tanto para
  /// resolver referencias a gastos pasados (reembolsos) con datos exactos,
  /// como para responder preguntas simples ("¿cuánto llevo gastado hoy?").
  Future<List<Map<String, dynamic>>> _transaccionesRecientes(
    List<Cuenta> cuentas,
  ) async {
    final cuentasPorId = {for (final c in cuentas) c.id: c.nombre};
    final snap = await _usuarioDoc
        .collection('transacciones')
        .orderBy('fecha', descending: true)
        .limit(_limiteTransaccionesContexto)
        .get();
    return snap.docs
        .map(Transaccion.fromFirestore)
        .where((t) => !t.esTransferencia)
        .map((t) {
          return {
            'tipo': t.tipo.name,
            'monto': t.monto,
            'categoria': t.categoria,
            'descripcion': t.descripcion,
            'fecha': t.fecha.toIso8601String().substring(0, 10),
            'cuenta': cuentasPorId[t.cuentaId] ?? 'desconocida',
          };
        })
        .toList();
  }

  /// Responde "¿cuánto llevo gastado hoy/ayer/hace N días/esta semana/este
  /// mes?" con el número EXACTO — se calcula aquí, sobre TODOS los
  /// movimientos del periodo (no la lista limitada de
  /// `transaccionesRecientes`) y neteando reembolsos por categoría
  /// (`ResumenGastos`, la misma lógica que "Gastos del mes" en Inicio). El
  /// modelo nunca hace esta cuenta ni calcula fechas: solo decide qué
  /// periodo preguntaron (y, para un día puntual, cuántos días atrás), para
  /// evitar que "redondee" o cuente mal un reembolso, como ya pasó cuando
  /// se le pedía sumarlo él mismo.
  Future<void> _responderConsultaGasto(
    String periodo, {
    int diasAtras = 0,
  }) async {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final DateTime desde;
    final DateTime hasta;
    final String etiqueta;
    switch (periodo) {
      case 'dia':
        // Un día puntual en el pasado (o hoy) es una ventana cerrada de un
        // solo día — a diferencia de semana/mes, NO se extiende hasta hoy.
        final diasAtrasSeguro = diasAtras.clamp(0, 3650);
        final dia = hoySinHora.subtract(Duration(days: diasAtrasSeguro));
        desde = dia;
        hasta = dia.add(const Duration(days: 1));
        etiqueta = switch (diasAtrasSeguro) {
          0 => 'hoy',
          1 => 'ayer',
          2 => 'anteayer',
          _ => 'hace $diasAtrasSeguro días',
        };
        break;
      case 'semana':
        // weekday: lunes=1 ... domingo=7 — así se calcula el lunes de esta semana.
        desde = hoySinHora.subtract(Duration(days: hoy.weekday - 1));
        hasta = hoySinHora.add(
          const Duration(days: 1),
        ); // hasta el final de hoy
        etiqueta = 'esta semana';
        break;
      case 'mes':
      default:
        desde = DateTime(hoy.year, hoy.month, 1);
        hasta = hoySinHora.add(
          const Duration(days: 1),
        ); // hasta el final de hoy
        etiqueta = 'este mes';
    }

    final snap = await _usuarioDoc
        .collection('transacciones')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThan: Timestamp.fromDate(hasta))
        .get();
    final transacciones = snap.docs.map(Transaccion.fromFirestore).toList();
    final resumen = ResumenGastos.calcular(
      transacciones,
      desde: desde,
      hasta: hasta,
    );

    final texto = resumen.total <= 0.01
        ? 'No tienes gasto neto $etiqueta (o se canceló con reembolsos).'
        : 'Llevas gastado \$${resumen.total.toStringAsFixed(2)} $etiqueta.';
    await _guardarMensaje(AutorMensaje.asistente, texto);
  }

  /// Saludo fijo (NO generado por la IA, a propósito) que se guarda la
  /// primera vez que se abre el chat — o de nuevo después de "Limpiar
  /// conversación". Al ser un texto fijo de la app, siempre es corto y
  /// consistente, sin el riesgo de que el modelo se ponga a inventar
  /// historias o "superpoderes" como pasó en una respuesta libre real (ver
  /// MENSAJE_SISTEMA en functions/index.js, donde también se acotó eso).
  Future<void> saludarSiEsNuevo(String nombreAsistente) async {
    final snap = await _mensajes.limit(1).get();
    if (snap.docs.isNotEmpty) {
      return; // ya hay conversación, no hace falta saludar
    }
    await _guardarMensaje(
      AutorMensaje.asistente,
      'Hola, soy $nombreAsistente 👋 Cuéntame qué gastaste o qué te ingresó y lo registro, '
      'o pregúntame cuánto llevas gastado hoy, esta semana o este mes.',
    );
  }

  /// Borra la conversación visible (y cualquier borrador pendiente) — nunca
  /// toca transacciones ni saldos reales. Es seguro hacerlo en cualquier
  /// momento: la memoria financiera de Lucy viene de `_transaccionesRecientes`
  /// (datos reales de Firestore), no del texto del chat, así que "olvidar"
  /// la conversación no le hace perder la capacidad de resolver referencias
  /// a gastos anteriores.
  Future<void> limpiarHistorial() async {
    final snap = await _mensajes.get();
    // Se procesa en lotes de 400 por el límite de 500 operaciones por
    // batch de Firestore — no debería hacer falta para un chat personal,
    // pero es barato cubrirlo.
    const tamanoLote = 400;
    for (var i = 0; i < snap.docs.length; i += tamanoLote) {
      final lote = snap.docs.skip(i).take(tamanoLote);
      final batch = _firestore.batch();
      for (final doc in lote) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _borradorDoc.delete();
  }

  /// Punto de entrada principal: el usuario mandó `texto`. `cuentas` son sus
  /// cuentas reales (ya cargadas por la pantalla vía `cuentasProvider`) —
  /// se usan aquí para resolver ambigüedad, nunca se le mandan a la IA.
  Future<void> enviarMensaje(
    String texto,
    List<Cuenta> cuentas, {
    OrigenTransaccion origen = OrigenTransaccion.iaTexto,
  }) async {
    ultimaRespuesta = null;
    ultimoMensajeAsistente = null;
    _origenActual = origen;
    final mensaje = texto.trim();
    if (mensaje.isEmpty) return;

    // Se lee ANTES de guardar el mensaje nuevo, para que no se incluya a sí
    // mismo — son los turnos reales que ya se hablaron.
    final historial = await _historialReciente();
    final transaccionesRecientes = await _transaccionesRecientes(cuentas);

    await _guardarMensaje(AutorMensaje.usuario, mensaje);

    // Si hay una pregunta pendiente (típicamente "¿con qué cuenta fue?"),
    // probamos primero si este mensaje ya la responde — así "con mi Nu" se
    // siente como una sola conversación en vez de un mensaje suelto.
    final borradorSnap = await _borradorDoc.get();
    if (borradorSnap.exists) {
      final borrador = BorradorPendiente.fromFirestore(borradorSnap.data()!);
      if (!borrador.expirado) {
        final cuenta = _resolverRespuestaDeCuenta(mensaje, cuentas);
        if (cuenta != null) {
          await _completarConCuenta(borrador, cuenta);
          await _borradorDoc.delete();
          return;
        }
        // No pareció responder la pregunta — se descarta (venció o el
        // usuario cambió de tema) y este mensaje se procesa como uno nuevo.
        await _borradorDoc.delete();
      }
    }

    if (cuentas.isEmpty) {
      await _guardarMensaje(
        AutorMensaje.asistente,
        'Todavía no tienes ninguna cuenta registrada — agrega una desde '
        'Inicio o Cuentas para que pueda anotar tus gastos ahí.',
      );
      return;
    }

    try {
      final resultado = await _functions
          .httpsCallable('interpretarMensajeIA')
          .call({
            'mensaje': mensaje,
            'historial': historial,
            'transaccionesRecientes': transaccionesRecientes,
            // Le sirve al modelo para corregir una transcripción de voz
            // imperfecta hacia el nombre exacto (ej. "rapicar" → "Rappi Card").
            'nombresCuentas': cuentas.map((c) => c.nombre).toList(),
          });
      final data = Map<String, dynamic>.from(resultado.data as Map);

      if (data['tipo'] == 'mensaje') {
        await _guardarMensaje(
          AutorMensaje.asistente,
          data['texto'] as String? ?? 'No entendí, ¿puedes darme más detalles?',
        );
        return;
      }

      if (data['tipo'] == 'consulta_gasto') {
        await _responderConsultaGasto(
          data['periodo'] as String? ?? 'mes',
          diasAtras: (data['diasAtras'] as num?)?.toInt() ?? 0,
        );
        return;
      }

      final datos = Map<String, dynamic>.from(data['datos'] as Map);
      await _resolverYRegistrar(
        tipo: TipoTransaccion.values.byName(datos['tipo'] as String),
        monto: (datos['monto'] as num).toDouble(),
        categoria: datos['categoria'] as String,
        descripcion: datos['descripcion'] as String? ?? '',
        cuentaMencionada: datos['cuentaMencionada'] as String? ?? '',
        cuentas: cuentas,
      );
    } on FirebaseFunctionsException catch (e) {
      await _guardarMensaje(AutorMensaje.asistente, _mensajeError(e));
    } catch (_) {
      await _guardarMensaje(
        AutorMensaje.asistente,
        'Algo salió mal de mi lado, ¿lo intentamos de nuevo?',
      );
    }
  }

  /// El usuario tocó uno de los chips de cuenta de un borrador pendiente
  /// (nivel 4 — sin ninguna pista, nunca pregunta abierta).
  Future<void> completarBorradorConChip(
    String cuentaId,
    List<Cuenta> cuentas, {
    OrigenTransaccion origen = OrigenTransaccion.iaTexto,
  }) async {
    ultimaRespuesta = null;
    ultimoMensajeAsistente = null;
    _origenActual = origen;
    final snap = await _borradorDoc.get();
    if (!snap.exists) return;
    final borrador = BorradorPendiente.fromFirestore(snap.data()!);
    Cuenta? cuenta;
    for (final c in cuentas) {
      if (c.id == cuentaId) {
        cuenta = c;
        break;
      }
    }
    if (cuenta == null) return;

    // Se guarda como si el usuario lo hubiera escrito, para que la
    // conversación se lea natural en el historial.
    await _guardarMensaje(AutorMensaje.usuario, cuenta.nombre);
    await _completarConCuenta(borrador, cuenta);
    await _borradorDoc.delete();
  }

  Future<void> _completarConCuenta(
    BorradorPendiente borrador,
    Cuenta cuenta,
  ) async {
    await _intentarRegistrarYConfirmar(
      tipo: borrador.tipo,
      monto: borrador.monto,
      categoria: borrador.categoria,
      descripcion: borrador.descripcion,
      cuentaId: cuenta.id,
      mensajeExito:
          '${_confirmacion(borrador.tipo, borrador.monto, borrador.categoria)} Lo cargué a "${cuenta.nombre}".',
    );
  }

  /// Registra la transacción y confirma — o, si la cuenta no tiene fondos
  /// suficientes (ver `SaldoInsuficienteException`), lo dice honestamente
  /// en vez de guardar un saldo imposible o fingir que sí se guardó. Los 3
  /// puntos donde Lucy registra algo pasan por aquí, para que el manejo de
  /// este caso sea siempre el mismo.
  Future<void> _intentarRegistrarYConfirmar({
    required TipoTransaccion tipo,
    required double monto,
    required String categoria,
    required String descripcion,
    required String cuentaId,
    required String mensajeExito,
  }) async {
    try {
      await _transaccionesRepository.registrarTransaccion(
        Transaccion(
          id: '',
          monto: monto,
          tipo: tipo,
          categoria: categoria,
          descripcion: descripcion,
          cuentaId: cuentaId,
          fecha: DateTime.now(),
          origen: _origenActual,
        ),
      );
      await _guardarMensaje(
        AutorMensaje.asistente,
        mensajeExito,
        registrado: true,
      );
    } on SaldoInsuficienteException catch (e) {
      await _guardarMensaje(
        AutorMensaje.asistente,
        'No pude registrarlo: $e ¿Fue con otra cuenta, o el monto es distinto?',
      );
    }
  }

  /// Los 4 niveles de resolución de ambigüedad de cuenta (ver CLAUDE.md).
  Future<void> _resolverYRegistrar({
    required TipoTransaccion tipo,
    required double monto,
    required String categoria,
    required String descripcion,
    required String cuentaMencionada,
    required List<Cuenta> cuentas,
  }) async {
    final termino = cuentaMencionada.trim().toLowerCase();

    // Nivel 1: coincidencia del nombre de la cuenta. Se usa `contains` en
    // vez de igualdad exacta a propósito — la IA ya intenta corregir el
    // nombre exacto (ver cuentasDelUsuario en functions/index.js), pero
    // esto es un respaldo por si igual llega algo como "mi Stori Card" en
    // vez de "Stori Card" tal cual, o "Rappi" a secas.
    Cuenta? cuenta;
    if (termino.isNotEmpty) {
      for (final c in cuentas) {
        final nombre = c.nombre.trim().toLowerCase();
        if (termino.contains(nombre) || nombre.contains(termino)) {
          cuenta = c;
          break;
        }
      }
    }

    // Niveles 2 y 3: término genérico ("efectivo", "mi tarjeta"...).
    if (cuenta == null && termino.isNotEmpty) {
      final tipos = _tiposCuentaDesdeTermino(termino);
      if (tipos != null) {
        final delTipo = cuentas.where((c) => tipos.contains(c.tipo)).toList();
        if (delTipo.length == 1) {
          cuenta = delTipo.first; // Nivel 2: una sola cuenta de ese tipo.
        } else if (delTipo.length > 1) {
          // Nivel 3: varias del mismo tipo — se usa la predeterminada (o la
          // primera como respaldo), se registra de una vez para no frenar
          // al usuario, y se avisa que se puede corregir hablando de nuevo.
          final elegida = delTipo.firstWhere(
            (c) => c.esPredeterminada,
            orElse: () => delTipo.first,
          );
          await _intentarRegistrarYConfirmar(
            tipo: tipo,
            monto: monto,
            categoria: categoria,
            descripcion: descripcion,
            cuentaId: elegida.id,
            mensajeExito:
                '${_confirmacion(tipo, monto, categoria)} Como tienes varias cuentas de '
                '${elegida.tipo.etiqueta.toLowerCase()}, lo puse en "${elegida.nombre}" — '
                'dime "cámbialo a [cuenta]" si no era esa.',
          );
          return;
        }
      }
    }

    if (cuenta != null) {
      await _intentarRegistrarYConfirmar(
        tipo: tipo,
        monto: monto,
        categoria: categoria,
        descripcion: descripcion,
        cuentaId: cuenta.id,
        mensajeExito:
            '${_confirmacion(tipo, monto, categoria)} Lo cargué a "${cuenta.nombre}".',
      );
      return;
    }

    // Nivel 4: ninguna pista útil — chips de selección rápida, nunca una
    // pregunta de texto libre. No bloquea el chat: el usuario puede seguir
    // hablando de otra cosa y el borrador simplemente expira en 1 hora.
    // OJO: todavía no se guarda nada en este punto — por eso el mensaje NO
    // dice "registrado" (eso solo pasa cuando el usuario elige la cuenta).
    await _borradorDoc.set(
      BorradorPendiente(
        tipo: tipo,
        monto: monto,
        categoria: categoria,
        descripcion: descripcion,
        cuentaMencionada: cuentaMencionada,
        creadoEn: DateTime.now(),
        idsCuentasSugeridas: cuentas.map((c) => c.id).toList(),
      ).toFirestore(),
    );

    await _guardarMensaje(
      AutorMensaje.asistente,
      '${_deteccion(tipo, monto, categoria)} ¿Con qué cuenta fue?',
      chipsCuentas: cuentas.map((c) => c.id).toList(),
    );
  }

  /// Intenta leer una respuesta a "¿con qué cuenta fue?" en texto libre (ej.
  /// "con mi Nu", "efectivo"). Más permisivo que la resolución principal
  /// (usa `contains` en vez de igualdad exacta) porque aquí sí sabemos que
  /// el usuario está contestando esa pregunta puntual, no describiendo un
  /// gasto nuevo desde cero.
  Cuenta? _resolverRespuestaDeCuenta(String texto, List<Cuenta> cuentas) {
    final termino = texto.trim().toLowerCase();
    if (termino.isEmpty) return null;

    for (final c in cuentas) {
      final nombre = c.nombre.trim().toLowerCase();
      if (termino.contains(nombre) || nombre.contains(termino)) return c;
    }

    final tipos = _tiposCuentaDesdeTermino(termino);
    if (tipos == null) return null;
    final delTipo = cuentas.where((c) => tipos.contains(c.tipo)).toList();
    if (delTipo.isEmpty) return null;
    return delTipo.firstWhere(
      (c) => c.esPredeterminada,
      orElse: () => delTipo.first,
    );
  }

  /// Mapea cómo la gente realmente nombra sus formas de pago a los tipos de
  /// cuenta de la app. "Tarjeta" a secas es ambiguo entre débito y crédito
  /// a propósito (ver la conversación de diseño en CLAUDE.md) — se resuelve
  /// buscando entre ambos tipos, no adivinando uno.
  List<TipoCuenta>? _tiposCuentaDesdeTermino(String termino) {
    if (termino.contains('efectivo') || termino.contains('cash')) {
      return [TipoCuenta.efectivo];
    }
    if (termino.contains('crédito') || termino.contains('credito')) {
      return [TipoCuenta.credito];
    }
    if (termino.contains('débito') || termino.contains('debito')) {
      return [TipoCuenta.debito];
    }
    if (termino.contains('vale')) return [TipoCuenta.vale];
    if (termino.contains('tarjeta')) {
      return [TipoCuenta.debito, TipoCuenta.credito];
    }
    return null;
  }

  /// Para usar DESPUÉS de una llamada real a `registrarTransaccion` — dice
  /// "registrado" porque de verdad ya se guardó.
  String _confirmacion(TipoTransaccion tipo, double monto, String categoria) {
    final verbo = tipo == TipoTransaccion.gasto ? 'Gasto' : 'Ingreso';
    return '$verbo de \$${monto.toStringAsFixed(2)} en $categoria registrado.';
  }

  /// Para usar ANTES de tener la cuenta (nivel 4) — todavía no se guardó
  /// nada, así que no debe sonar como si ya estuviera hecho.
  String _deteccion(TipoTransaccion tipo, double monto, String categoria) {
    final sustantivo = tipo == TipoTransaccion.gasto
        ? 'un gasto'
        : 'un ingreso';
    return 'Detecté $sustantivo de \$${monto.toStringAsFixed(2)} en $categoria.';
  }

  String _mensajeError(FirebaseFunctionsException e) {
    if (e.code == 'unauthenticated') {
      return 'Parece que tu sesión expiró — vuelve a iniciar sesión e intenta de nuevo.';
    }
    return 'No pude conectarme con mi cerebro (DeepSeek) en este momento. Intenta de nuevo en un momento.';
  }
}

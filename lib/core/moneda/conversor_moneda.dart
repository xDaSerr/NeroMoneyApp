import '../utils/formato_monto.dart';

/// Multimoneda (Pro): una cuenta puede llevar otra moneda (ej. una cuenta
/// en dólares) y los totales (patrimonio, gastos, reportes, presupuestos)
/// se convierten a la moneda principal del perfil.
///
/// Es estático, igual que AppColors: lo configura `conversorMonedaProvider`
/// (ver monedas_providers.dart) cada vez que cambian las cuentas, el perfil
/// o los tipos de cambio, y así cualquier cálculo puede usarlo sin pasar
/// parámetros por toda la app. Sin configurar, no convierte nada.
class ConversorMoneda {
  ConversorMoneda._();

  static String _principal = 'MXN';
  static Map<String, String> _monedaPorCuenta = const {};

  /// Unidades de cada moneda por 1 USD (ej. {'MXN': 17.2, 'EUR': 0.92}).
  static Map<String, double> _tasas = const {};

  static String get principal => _principal;
  static bool get tieneTasas => _tasas.isNotEmpty;

  static void configurar({
    required String principal,
    required Map<String, String> monedaPorCuenta,
    required Map<String, double> tasas,
  }) {
    _principal = principal;
    _monedaPorCuenta = monedaPorCuenta;
    _tasas = tasas;
  }

  /// Vuelve al estado inicial (pruebas y cierre de sesión).
  static void reiniciar() =>
      configurar(principal: 'MXN', monedaPorCuenta: const {}, tasas: const {});

  static String monedaDeCuenta(String cuentaId) =>
      _monedaPorCuenta[cuentaId] ?? _principal;

  static bool esExtranjera(String cuentaId) =>
      monedaDeCuenta(cuentaId) != _principal;

  /// [monto] en [moneda] llevado a la moneda principal. Sin tipo de
  /// cambio conocido se deja igual (mejor un número sin convertir que
  /// ninguno).
  static double aPrincipal(double monto, String moneda) {
    if (moneda == _principal) return monto;
    final de = _tasas[moneda];
    final a = _tasas[_principal];
    if (de == null || a == null || de == 0) return monto;
    return monto / de * a;
  }

  static double deCuenta(double monto, String cuentaId) =>
      aPrincipal(monto, monedaDeCuenta(cuentaId));

  /// "$1,250.00" en la moneda principal, o "$75.00 USD" si la cuenta usa
  /// otra.
  static String formato(double monto, String cuentaId) {
    final moneda = monedaDeCuenta(cuentaId);
    return moneda == _principal
        ? formatoMonto(monto)
        : '${formatoMonto(monto)} $moneda';
  }
}

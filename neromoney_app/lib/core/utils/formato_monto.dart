import 'package:intl/intl.dart';

final _formato = NumberFormat('#,##0.00', 'en_US');

/// "$26,342.42": con separador de miles, para cifras grandes como el
/// patrimonio. La app no convierte monedas, así que el símbolo es siempre
/// "$" y el código de la moneda se muestra aparte cuando hace falta.
String formatoMonto(double monto) => '\$${_formato.format(monto)}';

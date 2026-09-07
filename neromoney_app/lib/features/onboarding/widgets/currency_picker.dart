/// Lista corta de monedas comunes para el selector del onboarding. No hace
/// falta una lista exhaustiva de las ~180 del mundo — con estas se cubre la
/// gran mayoría de usuarios reales de la app.
class OpcionMoneda {
  const OpcionMoneda(this.codigo, this.nombre, this.bandera);
  final String codigo;
  final String nombre;
  final String bandera;
}

const monedasDisponibles = [
  OpcionMoneda('MXN', 'Peso mexicano', '🇲🇽'),
  OpcionMoneda('USD', 'Dólar estadounidense', '🇺🇸'),
  OpcionMoneda('EUR', 'Euro', '🇪🇺'),
  OpcionMoneda('COP', 'Peso colombiano', '🇨🇴'),
  OpcionMoneda('ARS', 'Peso argentino', '🇦🇷'),
  OpcionMoneda('CLP', 'Peso chileno', '🇨🇱'),
  OpcionMoneda('PEN', 'Sol peruano', '🇵🇪'),
  OpcionMoneda('GTQ', 'Quetzal guatemalteco', '🇬🇹'),
  OpcionMoneda('BRL', 'Real brasileño', '🇧🇷'),
];

/// Cómo se dice en voz cada moneda. La app siempre MUESTRA los montos con
/// el símbolo "$" (es lo que la gente espera ver en pantalla), pero un
/// lector de texto a voz interpreta "$" como dólares sin importar cuál sea
/// la moneda real configurada — por eso, antes de leer un monto en voz alta
/// (ver AssistantChatScreen), hay que cambiar el símbolo por esta palabra.
String monedaHablada(String codigoMoneda) => switch (codigoMoneda) {
      'USD' => 'dólares',
      'EUR' => 'euros',
      'PEN' => 'soles',
      'GTQ' => 'quetzales',
      'BRL' => 'reales',
      _ => 'pesos', // MXN, COP, ARS, CLP
    };

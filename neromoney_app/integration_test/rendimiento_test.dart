import 'package:integration_test/integration_test.dart';

import '../test/support/escenario_rendimiento.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registrarPruebaRendimiento(
    onReporte: (reporte) => binding.reportData = reporte,
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

/// Contenedor de las 5 pestañas principales. `navigationShell` viene de
/// go_router (StatefulShellRoute) y mantiene el estado/historial de
/// navegación de cada pestaña por separado — si entras a "Movimientos",
/// navegas a un detalle, y cambias a "Perfil" y regresas, "Movimientos"
/// sigue donde lo dejaste en vez de reiniciarse.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // "Cuentas" tomó el lugar de "Reportes" (que se movió al menú de Perfil,
  // ver ProfileScreen) — decisión explícita del usuario.
  static const _destinations = [
    (icon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.receipt_long_rounded, label: 'Movs'),
    (icon: Icons.auto_awesome_rounded, label: 'Lucy IA'),
    (icon: Icons.account_balance_rounded, label: 'Cuentas'),
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Si ya estás en esa pestaña, regresa a su raíz en vez de apilar.
          initialLocation: index == navigationShell.currentIndex,
        ),
        backgroundColor: AppColors.surface1,
        indicatorColor: AppColors.primaryCyan.withValues(alpha: 0.15),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}

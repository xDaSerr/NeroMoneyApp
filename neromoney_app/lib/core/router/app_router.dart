import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../widgets/placeholder_screen.dart';
import '../../features/accounts/account_detail_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/assistant/assistant_chat_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/data/perfil_repository.dart';
import '../../features/onboarding/onboarding_flow_screen.dart';
import '../../features/profile/personalizar_asistente_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/transactions/add_transaction_screen.dart';
import '../../features/transactions/data/transaccion.dart';
import '../../features/transactions/movements_screen.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';

const _authRoutes = {'/login', '/register', '/forgot-password'};
const _onboardingRoute = '/onboarding';

// Una vez que confirmamos que un usuario ya completó el onboarding, no tiene
// sentido volver a preguntarle a Firestore en cada cambio de pestaña — esa
// bandera no vuelve a false. Evita un round-trip de red por cada navegación.
bool _onboardingConfirmado = false;

/// Todas las rutas de la app en un solo lugar. Las 5 pestañas viven dentro
/// de un StatefulShellRoute (ver app_shell.dart) para que cada una recuerde
/// su propia navegación al cambiar de pestaña.
final appRouter = GoRouter(
  initialLocation: '/login',
  // Reacciona a login/logout: cada vez que cambia la sesión, go_router
  // vuelve a evaluar `redirect` de inmediato, sin que ninguna pantalla
  // tenga que navegar manualmente.
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.matchedLocation;
    final onAuthRoute = _authRoutes.contains(loc);
    final onOnboardingRoute = loc == _onboardingRoute;

    if (user == null) {
      _onboardingConfirmado = false;
      return onAuthRoute ? null : '/login';
    }

    if (!_onboardingConfirmado) {
      final perfil = await PerfilRepository(FirebaseFirestore.instance, user.uid).obtenerPerfil();
      _onboardingConfirmado = perfil.onboardingCompletado;
    }

    if (!_onboardingConfirmado) {
      return onOnboardingRoute ? null : _onboardingRoute;
    }

    if (onAuthRoute || onOnboardingRoute) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(path: _onboardingRoute, builder: (context, state) => const OnboardingFlowScreen()),
    GoRoute(
      path: '/add-transaction',
      // `extra` opcional: los accesos rápidos de Inicio mandan un
      // TipoTransaccion para abrir la pantalla ya en "Gasto" o "Ingreso".
      builder: (context, state) =>
          AddTransactionScreen(tipoInicial: state.extra as TipoTransaccion?),
    ),
    // Reportes ya no es una pestaña — se llega desde el menú de Perfil (ver
    // ProfileScreen), por eso vive fuera del StatefulShellRoute.
    GoRoute(
      path: '/reports',
      builder: (context, state) => const PlaceholderScreen(title: 'Reportes'),
    ),
    // Igual que Reportes: se llega desde el menú de Perfil, no desde una
    // pestaña — el usuario pidió explícitamente que esto NO sea parte del
    // onboarding, sino algo que se cambia cuando uno quiera.
    GoRoute(
      path: '/personalizar-asistente',
      builder: (context, state) => const PersonalizarAsistenteScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/movements', builder: (context, state) => const MovementsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/assistant', builder: (context, state) => const AssistantChatScreen()),
        ]),
        // "Cuentas" tomó el lugar que tenía "Reportes" en la barra inferior
        // (decisión del usuario). El detalle de una cuenta vive anidado
        // aquí (no como ruta aparte) para que "atrás" te regrese a la
        // lista de cuentas sin salirse de esta pestaña.
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
            routes: [
              GoRoute(
                path: 'detalle',
                builder: (context, state) => AccountDetailScreen(cuentaId: state.extra as String),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ]),
      ],
    ),
  ],
);

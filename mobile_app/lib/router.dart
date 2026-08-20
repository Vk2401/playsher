import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/register_screen.dart';
import 'screens/location_screen.dart';
import 'screens/main_shell.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/ground_detail_screen.dart';
import 'screens/booking_flow_screen.dart';
import 'screens/booking_confirm_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/booking_detail_screen.dart';
import 'screens/games_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/game_detail_screen.dart';
import 'screens/host_game_screen.dart';
import 'screens/coaching_screen.dart';
import 'screens/coach_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/saved_turfs_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/venue_filter_screen.dart';

// ── Bridge: notifies GoRouter when auth state changes ─────────────────────────
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

/// The router's root navigator.
///
/// Public because `AppUpdateGate` lives in `MaterialApp.router`'s `builder`,
/// whose context sits *above* this navigator — `showDialog` with that context
/// throws "does not include a Navigator". The gate hosts its dialog here.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (ctx, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      final isAuthRoute = loc == '/splash' ||
          loc == '/onboarding' ||
          loc.startsWith('/login') ||
          loc.startsWith('/otp') ||
          loc.startsWith('/register') ||
          loc == '/location';

      if (!auth.isAuthenticated && !isAuthRoute) return '/login';
      if (auth.isAuthenticated &&
          (loc.startsWith('/login') ||
              loc.startsWith('/otp') ||
              loc.startsWith('/register'))) {
        return '/home';
      }
      return null;
    },
    routes: [
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      // ── Onboarding ─────────────────────────────────────────────────────────
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // ── Auth ───────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(mobile: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/register',
        builder: (_, state) =>
            RegisterScreen(mobile: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/location',
        builder: (_, state) {
          final fromRegister = state.extra as bool? ?? false;
          return LocationScreen(fromRegister: fromRegister);
        },
      ),

      // ── Main shell (bottom nav) ────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/venues',
                builder: (_, state) => ExploreScreen(
                    initialSearch: state.uri.queryParameters['q']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/games', builder: (_, __) => const GamesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/coaching',
                  builder: (_, __) => const CoachingScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/profile', builder: (_, __) => const ProfileScreen()),
            ],
          ),
        ],
      ),

      // ── Ground detail ──────────────────────────────────────────────────────
      GoRoute(
        path: '/grounds/:id',
        builder: (_, state) =>
            GroundDetailScreen(groundId: state.pathParameters['id']!),
      ),

      // ── Booking ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/book/:groundId',
        builder: (_, state) => BookingFlowScreen(
          groundId: int.parse(state.pathParameters['groundId']!),
          extra: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/booking-confirm',
        builder: (_, state) => BookingConfirmScreen(
            bookingData: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: '/my-bookings',
        builder: (_, __) => const BookingsScreen(),
      ),
      GoRoute(
        path: '/bookings/:id',
        builder: (_, state) =>
            BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),

      // ── Games ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/games/:id',
        builder: (_, state) =>
            GameDetailScreen(gameId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/host-game',
        builder: (_, __) => const HostGameScreen(),
      ),

      // ── Coaching ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/coaching/:id',
        builder: (_, state) =>
            CoachDetailScreen(coachId: state.pathParameters['id']!),
      ),

      // ── Profile sub-routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/saved-turfs',
        builder: (_, __) => const SavedTurfsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),

      // ── Venue filter ───────────────────────────────────────────────────────
      GoRoute(
        path: '/venue-filter',
        builder: (_, __) => const VenueFilterScreen(),
      ),
    ],
  );
});

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/invite_code_page.dart';
import '../features/auth/landing_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/tier_selection_page.dart';
import '../features/admin/invites_page.dart';
import '../features/admin/trade_entry_page.dart';
import '../features/community/community_page.dart';
import '../features/auth/welcome_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/placeholder_page.dart';
import '../features/trades/trade_detail_page.dart';
import '../features/trades/trades_list_page.dart';
import 'providers/auth_provider.dart';
import 'supabase_client.dart';

/// Notifies go_router whenever auth state changes so redirects re-evaluate.
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier() {
    _sub = supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: AuthChangeNotifier(),
    redirect: (context, state) {
      // Read claims straight off the live session: the Riverpod session
      // provider updates one event-loop turn after signIn completes, and a
      // redirect that runs in that gap would see stale (null) claims and
      // wrongly park members on the tier page.
      final session = supabase.auth.currentSession;
      final isAuth = session != null;
      final claims = decodeJwtClaims(session?.accessToken);
      final isAdmin = claims['is_admin'] == true;
      final tier = claims['membership_tier'] as String?;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == '/' || loc == '/login' || loc.startsWith('/auth');

      if (!isAuth && !isAuthRoute) return '/';
      if (isAuth && (loc == '/' || loc == '/login')) return '/dashboard';
      if (loc.startsWith('/admin') && !isAdmin) return '/dashboard';

      // Members with an active tier have no business on the tier page.
      if (isAuth && (tier != null || isAdmin) && loc == '/auth/tier') {
        return '/dashboard';
      }

      // Authenticated but no active tier (payment pending / lapsed):
      // only tier selection, welcome, and settings are reachable.
      if (isAuth &&
          tier == null &&
          !isAdmin &&
          !isAuthRoute &&
          !loc.startsWith('/settings')) {
        return '/auth/tier';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LandingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/auth/invite', builder: (_, _) => const InviteCodePage()),
      GoRoute(
        path: '/auth/register',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? const {};
          return RegisterPage(
            inviteCodeId: extra['invite_code_id'] as String?,
            defaultTier: extra['default_tier'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/auth/tier',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? const {};
          return TierSelectionPage(
              defaultTier: extra['default_tier'] as String?);
        },
      ),
      GoRoute(path: '/auth/welcome', builder: (_, _) => const WelcomePage()),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(
              path: '/positions',
              builder: (_, _) =>
                  const TradesListPage(status: 'in_flight')),
          GoRoute(
              path: '/ideas',
              builder: (_, _) =>
                  const TradesListPage(status: 'pre_flight')),
          GoRoute(
              path: '/trade/:id',
              builder: (_, state) =>
                  TradeDetailPage(tradeId: state.pathParameters['id']!)),
          GoRoute(
              path: '/community',
              builder: (_, _) => const CommunityPage()),
          GoRoute(
              path: '/settings',
              builder: (_, _) => const PlaceholderPage(title: 'Settings')),
          GoRoute(
              path: '/admin/trade',
              builder: (_, _) => const TradeEntryPage()),
          GoRoute(
              path: '/admin/invites',
              builder: (_, _) => const InvitesPage()),
        ],
      ),
    ],
  );
});

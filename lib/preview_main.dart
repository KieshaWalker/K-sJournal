// Dev-only preview harness: mounts the member app with a fake session and
// canned rows so layout can be checked in a plain browser without logging
// in. Never deployed — Vercel builds lib/main.dart.
//
//   flutter run -d web-server -t lib/preview_main.dart
//   flutter build web -t lib/preview_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/providers/auth_provider.dart';
import 'core/theme.dart';
import 'features/community/community_page.dart';
import 'features/community/providers/community_providers.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/dashboard/providers/dashboard_providers.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/placeholder_page.dart';
import 'features/trades/providers/trade_providers.dart';
import 'features/trades/trades_list_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fake project: nothing here ever answers, but every data source below is
  // overridden so no request is actually made.
  await Supabase.initialize(
    url: 'https://preview.invalid',
    publishableKey: 'preview-key',
  );
  runApp(ProviderScope(overrides: _overrides, child: const _PreviewApp()));
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "K's Journal (preview)",
      debugShowCheckedModeBanner: false,
      theme: buildAuthTheme(),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (_, _, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
        GoRoute(
            path: '/positions',
            builder: (_, _) => const TradesListPage(status: 'in_flight')),
        GoRoute(
            path: '/ideas',
            builder: (_, _) => const TradesListPage(status: 'pre_flight')),
        GoRoute(path: '/community', builder: (_, _) => const CommunityPage()),
        GoRoute(
            path: '/settings',
            builder: (_, _) => const PlaceholderPage(title: 'Settings')),
      ],
    ),
  ],
);

final _overrides = [
  jwtClaimsProvider.overrideWith((ref) => const {
        'username': 'kiesha',
        'is_admin': true,
        'membership_tier': 'inner_circle',
      }),
  insightsFeedProvider.overrideWith((ref) async => _insights),
  macroTilesProvider.overrideWith((ref) async => _macroTiles),
  preFlightIdeasProvider.overrideWith((ref) async => _preFlight),
  activeTradesProvider.overrideWith((ref) async => _inFlight),
  recentlyLandedProvider.overrideWith((ref) async => _landed),
  preFlightTradesProvider.overrideWith((ref) async => _preFlight),
  inFlightTradesProvider.overrideWith((ref) async => _inFlight),
  communityProfilesProvider.overrideWith((ref) async => _profiles),
  communityPostsProvider.overrideWith((ref) async => _posts),
];

final _insights = <Map<String, dynamic>>[
  {
    'id': 'i1',
    'title': 'Vol stays bid into CPI',
    'body': 'Front-month IV is holding a premium to realized even after the '
        'bounce. I want short delta into the print and I want to own the '
        'wings cheap. Watching SPX 30-delta skew all week.',
    'insight_date': '2026-06-10',
    'market_bias': 'cautious',
    'scope': 'market',
    'ticker': null,
    'image_url': null,
  },
  {
    'id': 'i2',
    'title': 'NVDA earnings setup',
    'body': 'IV rank north of 70 with the stock pinned at the gamma wall. '
        'Premium selling territory if you size small.',
    'insight_date': '2026-06-08',
    'market_bias': 'neutral',
    'scope': 'ticker',
    'ticker': 'NVDA',
    'image_url': null,
  },
  {
    'id': 'i3',
    'title': 'Dollar softness, gold strength',
    'body': 'DXY rolling over while GLD grinds new highs. Macro tailwind for '
        'the long side of metals.',
    'insight_date': '2026-06-05',
    'market_bias': 'bullish',
    'scope': 'market',
    'ticker': null,
    'image_url': null,
  },
];

const _macroTiles = [
  MacroTile(ticker: 'SPY', label: 'S&P 500', close: 612.43, changePct: 0.8, ivRank: 22),
  MacroTile(ticker: 'QQQ', label: 'Nasdaq', close: 548.11, changePct: 1.2, ivRank: 31),
  MacroTile(ticker: 'IWM', label: 'Russell', close: 228.07, changePct: -0.4, ivRank: 44),
  MacroTile(ticker: 'VIX', label: 'Vol', close: 14.92, changePct: -3.1),
  MacroTile(ticker: 'GLD', label: 'Gold', close: 312.55, changePct: 0.6, ivRank: 18),
];

final _preFlight = <Map<String, dynamic>>[
  {
    'id': 't1',
    'status': 'pre_flight',
    'ticker': 'NVDA',
    'strategy_type': 'iron_condor',
    'direction': 'neutral',
    'thesis_notes': 'IV rank 72 into earnings. Selling the move while the '
        'stock pins at the gamma wall. Small size, defined risk only.',
    'entry_iv_rank': 72,
    'tags': ['earnings', 'premium-selling'],
    'created_at': '2026-06-09T14:00:00Z',
  },
  {
    'id': 't2',
    'status': 'pre_flight',
    'ticker': 'GLD',
    'strategy_type': 'call_debit_spread',
    'direction': 'bullish',
    'thesis_notes': 'Dollar rolling over, gold at highs. Cheap upside while '
        'IV is asleep at 18 rank.',
    'entry_iv_rank': 18,
    'tags': ['macro'],
    'created_at': '2026-06-08T14:00:00Z',
  },
];

final _inFlight = <Map<String, dynamic>>[
  {
    'id': 't3',
    'status': 'in_flight',
    'ticker': 'SPY',
    'strategy_type': 'put_credit_spread',
    'direction': 'bullish',
    'unrealized_pnl': 340,
    'pnl_percent': 28,
    'entry_date': '2026-06-02',
    'entry_price': 2.15,
    'entry_iv_rank': 38,
    'thesis_notes': 'Sold the 595/590 put spread on the pullback to the '
        '20-day. Theta does the work from here.',
    'trade_comments': [
      {'is_question': true},
      {'is_question': false},
      {'is_question': false},
    ],
  },
  {
    'id': 't4',
    'status': 'in_flight',
    'ticker': 'TSLA',
    'strategy_type': 'long_put',
    'direction': 'bearish',
    'unrealized_pnl': -120,
    'pnl_percent': -15,
    'entry_date': '2026-06-05',
    'entry_price': 8.10,
    'entry_iv_rank': 55,
    'thesis_notes': 'Lower highs on declining volume. Risk one, looking for '
        'three on the breakdown.',
    'trade_comments': [
      {'is_question': false},
    ],
  },
];

final _landed = <Map<String, dynamic>>[
  {
    'id': 't5',
    'ticker': 'AMD',
    'strategy_type': 'call_debit_spread',
    'realized_pnl': 410,
    'pnl_percent': 64.5,
    'outcome': 'win',
    'entry_date': '2026-05-12',
    'exit_date': '2026-05-28',
    'trade_comments': [
      {'is_question': false},
      {'is_question': false},
    ],
  },
  {
    'id': 't6',
    'ticker': 'META',
    'strategy_type': 'iron_condor',
    'realized_pnl': -180,
    'pnl_percent': -22.0,
    'outcome': 'loss',
    'entry_date': '2026-05-02',
    'exit_date': '2026-05-20',
    'trade_comments': [],
  },
  {
    'id': 't7',
    'ticker': 'XLE',
    'strategy_type': 'covered_call',
    'realized_pnl': 95,
    'pnl_percent': 4.1,
    'outcome': 'win',
    'entry_date': '2026-04-21',
    'exit_date': '2026-05-16',
    'trade_comments': [],
  },
];

final _profiles = <Map<String, dynamic>>[
  {
    'id': 'u1',
    'username': 'kiesha',
    'display_name': 'K',
    'is_admin': true,
    'membership_tier': null,
    'avatar_url': null,
    'bio': 'The house. Options on the record, win or lose.',
    'location': 'Houston',
    'age': null,
    'trades_followed': 0,
    'member_since': '2026-01-01',
    'recent_activity': 12,
  },
  {
    'id': 'u2',
    'username': 'marcus_t',
    'display_name': 'Marcus',
    'is_admin': false,
    'membership_tier': 'inner_circle',
    'avatar_url': null,
    'bio': 'Spreads and patience.',
    'location': 'Atlanta',
    'age': 34,
    'trades_followed': 8,
    'member_since': '2026-02-10',
    'recent_activity': 7,
  },
  {
    'id': 'u3',
    'username': 'lena.w',
    'display_name': null,
    'is_admin': false,
    'membership_tier': 'analyst',
    'avatar_url': null,
    'bio': null,
    'location': null,
    'age': null,
    'trades_followed': 3,
    'member_since': '2026-03-04',
    'recent_activity': 2,
  },
];

final _posts = <Map<String, dynamic>>[
  {
    'id': 'p1',
    'user_id': 'u2',
    'parent_post_id': null,
    'body': 'That SPY put spread from Monday is already at 50% max. '
        'Taking mine off — thanks K.',
    'image_url': null,
    'created_at':
        DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    'post_likes': [
      {'user_id': 'u1'},
      {'user_id': 'u3'},
    ],
  },
  {
    'id': 'p2',
    'user_id': 'u1',
    'parent_post_id': 'p1',
    'body': 'Half off at 50%, runner to 75%. House rules.',
    'image_url': null,
    'created_at':
        DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    'post_likes': [],
  },
];

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

class MacroTile {
  const MacroTile({
    required this.ticker,
    required this.label,
    this.close,
    this.changePct,
    this.ivRank,
  });

  final String ticker;
  final String label;
  final double? close;
  final double? changePct;
  final double? ivRank;
}

/// Latest snapshot per active watchlist ticker, joined with IV context.
final macroTilesProvider = FutureProvider<List<MacroTile>>((ref) async {
  final watchlist = await supabase
      .from('watchlist_tickers')
      .select('ticker, label, display_order')
      .eq('is_active', true)
      .order('display_order');

  final tickers = [for (final w in watchlist) w['ticker'] as String];
  if (tickers.isEmpty) return const [];

  // A recent-days window rather than a row limit: tables now hold full
  // history per ticker, and a laggard like a ticker last snapped two days
  // ago must not be crowded out by fresher tickers' rows.
  final cutoff = DateTime.now()
      .subtract(const Duration(days: 14))
      .toIso8601String()
      .split('T')
      .first;

  final snapshots = await supabase
      .from('market_snapshots')
      .select('ticker, snapshot_date, close, price_change_pct')
      .inFilter('ticker', tickers)
      .gte('snapshot_date', cutoff)
      .order('snapshot_date', ascending: false);

  final vol = await supabase
      .from('volatility_data')
      .select('ticker, snapshot_date, iv_rank')
      .inFilter('ticker', tickers)
      .gte('snapshot_date', cutoff)
      .order('snapshot_date', ascending: false);

  final latestSnap = <String, Map<String, dynamic>>{};
  for (final s in snapshots) {
    latestSnap.putIfAbsent(s['ticker'] as String, () => s);
  }
  final latestVol = <String, Map<String, dynamic>>{};
  for (final v in vol) {
    latestVol.putIfAbsent(v['ticker'] as String, () => v);
  }

  return [
    for (final w in watchlist)
      MacroTile(
        ticker: w['ticker'] as String,
        label: w['label'] as String,
        close: (latestSnap[w['ticker']]?['close'] as num?)?.toDouble(),
        changePct: (latestSnap[w['ticker']]?['price_change_pct'] as num?)
            ?.toDouble(),
        ivRank: (latestVol[w['ticker']]?['iv_rank'] as num?)?.toDouble(),
      ),
  ];
});

/// One directional outcome for a calendar event: what happens, and which way
/// it cuts. [effect] is one of bullish | neutral | bearish.
class EventScenario {
  const EventScenario({required this.label, required this.effect});

  final String label;
  final String effect;

  factory EventScenario.fromJson(Map<String, dynamic> j) => EventScenario(
        label: (j['label'] as String?) ?? '',
        effect: (j['effect'] as String?) ?? 'neutral',
      );
}

/// A dated market catalyst on K's docket — an FOMC decision, a CPI print, a
/// marquee earnings date. Shown beneath the Macro Pulse tiles.
class MacroEvent {
  const MacroEvent({
    required this.id,
    required this.title,
    this.detail,
    required this.eventDate,
    this.eventTime,
    this.category,
    this.scenarios = const [],
  });

  final String id;
  final String title;
  final String? detail;
  final DateTime eventDate;
  final String? eventTime;
  final String? category;
  final List<EventScenario> scenarios;

  factory MacroEvent.fromRow(Map<String, dynamic> r) => MacroEvent(
        id: r['id'] as String,
        title: r['title'] as String,
        detail: r['detail'] as String?,
        eventDate: DateTime.parse(r['event_date'] as String),
        eventTime: r['event_time'] as String?,
        category: r['category'] as String?,
        scenarios: [
          for (final s in (r['scenarios'] as List? ?? const []))
            EventScenario.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}

/// Upcoming catalysts for the dashboard calendar — today onward, soonest
/// first. Past events stay in the table but drop off the feed on their own.
final macroEventsProvider = FutureProvider<List<MacroEvent>>((ref) async {
  final today =
      DateTime.now().toIso8601String().split('T').first;
  final rows = await supabase
      .from('macro_events')
      .select('id, title, detail, event_date, event_time, category, scenarios')
      .eq('is_active', true)
      .gte('event_date', today)
      .order('event_date')
      .order('display_order')
      .limit(8);
  return [for (final r in rows) MacroEvent.fromRow(r)];
});

/// Published insights newest-first — macro takes and ticker notes alike.
/// The dashboard shows them as one scrollable feed, so a single-name note
/// no longer displaces the market-level take; the limit keeps the first
/// paint light.
final insightsFeedProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('insights')
      .select('id, title, body, insight_date, market_bias, macro_tags, '
          'scope, ticker, image_url, insight_comments(is_question)')
      .eq('is_published', true)
      .order('insight_date', ascending: false)
      .order('created_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(rows);
});

/// In-flight trades for the active positions summary.
final activeTradesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, direction, status, unrealized_pnl, '
          'pnl_percent, current_price, current_as_of, entry_date, entry_price, '
          'entry_iv_rank, thesis_notes, tags, trade_comments(is_question), '
          'trade_underlying_legs(side, shares, entry_price, current_price, '
          'exit_price)')
      .eq('status', 'in_flight')
      .order('updated_at', ascending: false);
});

/// Early-stage ideas (the rawest lifecycle stage, ahead of pre-flight) for the
/// dashboard summary. RLS exposes 'idea' rows to inner_circle only; every other
/// tier gets an empty list and the dashboard hides the section entirely.
final earlyIdeasProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, direction, thesis_notes, '
          'entry_iv_rank, tags, created_at, '
          'trade_underlying_legs(side, shares, entry_price, current_price, '
          'exit_price)')
      .eq('status', 'idea')
      .order('created_at', ascending: false)
      .limit(6);
});

/// Pre-flight ideas for the dashboard summary. RLS returns rows only for
/// analyst and inner_circle tiers; observers simply get an empty list.
final preFlightIdeasProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, direction, thesis_notes, '
          'entry_iv_rank, tags, created_at, '
          'trade_underlying_legs(side, shares, entry_price, current_price, '
          'exit_price)')
      .eq('status', 'pre_flight')
      .order('created_at', ascending: false)
      .limit(6);
});

/// Recently landed trades.
final recentlyLandedProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, realized_pnl, pnl_percent, '
          'outcome, entry_date, exit_date, tags, trade_comments(is_question), '
          'trade_underlying_legs(side, shares, entry_price, current_price, '
          'exit_price)')
      .eq('status', 'landed')
      .order('exit_date', ascending: false)
      .limit(5);
});

/// Section-header stats across ALL landed trades — total realized P&L and the
/// win/loss/scratch tally — not just the recent five the cards show. Win rate
/// is wins / (wins + losses); scratches (breakeven) sit out of the
/// denominator. Null realized_pnl counts as zero in the P&L sum.
class LandedStats {
  const LandedStats({
    required this.count,
    required this.realizedPnl,
    required this.wins,
    required this.losses,
    required this.scratches,
    required this.winPnl,
    required this.lossPnl,
  });

  final int count;
  final double realizedPnl;
  final int wins;
  final int losses;
  final int scratches;

  /// Summed realized P&L of winning trades (positive) and losing trades
  /// (negative) — the numerators for the averages.
  final double winPnl;
  final double lossPnl;

  /// Decided trades — the win-rate denominator.
  int get decided => wins + losses;

  /// Wins as a fraction of decided trades, or null when nothing is decided
  /// (no landed trades, or every landed trade scratched).
  double? get winRate => decided == 0 ? null : wins / decided;

  /// Average winner (positive) / average loser (negative), or null when there
  /// are none of that kind yet.
  double? get avgWin => wins == 0 ? null : winPnl / wins;
  double? get avgLoss => losses == 0 ? null : lossPnl / losses;
}

final landedStatsProvider = FutureProvider<LandedStats>((ref) async {
  final rows = await supabase
      .from('trades')
      .select('realized_pnl, outcome')
      .eq('status', 'landed');
  var pnl = 0.0, winPnl = 0.0, lossPnl = 0.0;
  var wins = 0, losses = 0, scratches = 0;
  for (final r in rows) {
    final v = (r['realized_pnl'] as num?)?.toDouble() ?? 0;
    pnl += v;
    switch (r['outcome'] as String?) {
      case 'win':
        wins++;
        winPnl += v;
      case 'loss':
        losses++;
        lossPnl += v;
      case 'scratch':
        scratches++;
    }
  }
  return LandedStats(
    count: rows.length,
    realizedPnl: pnl,
    wins: wins,
    losses: losses,
    scratches: scratches,
    winPnl: winPnl,
    lossPnl: lossPnl,
  );
});

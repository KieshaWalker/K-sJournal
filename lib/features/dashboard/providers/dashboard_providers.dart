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
          'entry_iv_rank, thesis_notes, trade_comments(is_question)')
      .eq('status', 'in_flight')
      .order('updated_at', ascending: false);
});

/// Pre-flight ideas for the dashboard summary. RLS returns rows only for
/// analyst and inner_circle tiers; observers simply get an empty list.
final preFlightIdeasProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, direction, thesis_notes, '
          'entry_iv_rank, tags, created_at')
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
          'outcome, entry_date, exit_date, trade_comments(is_question)')
      .eq('status', 'landed')
      .order('exit_date', ascending: false)
      .limit(5);
});

/// Total realized P&L across ALL landed trades — the section header total,
/// not just the recent five the cards show. One lightweight column, summed
/// over whatever the viewer's RLS lets them read (members see every landed
/// trade). Null realized_pnl counts as zero; null is returned when there are
/// no landed trades at all, so the header can omit the total entirely.
final landedPnlTotalProvider = FutureProvider<double?>((ref) async {
  final rows =
      await supabase.from('trades').select('realized_pnl').eq('status', 'landed');
  if (rows.isEmpty) return null;
  return rows.fold<double>(
      0, (sum, r) => sum + ((r['realized_pnl'] as num?)?.toDouble() ?? 0));
});

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

  final snapshots = await supabase
      .from('market_snapshots')
      .select('ticker, snapshot_date, close, price_change_pct')
      .inFilter('ticker', tickers)
      .order('snapshot_date', ascending: false)
      .limit(tickers.length * 2);

  final vol = await supabase
      .from('volatility_data')
      .select('ticker, snapshot_date, iv_rank')
      .inFilter('ticker', tickers)
      .order('snapshot_date', ascending: false)
      .limit(tickers.length * 2);

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

/// Latest published insight (K's Take).
final latestInsightProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final rows = await supabase
      .from('insights')
      .select('id, title, body, insight_date, market_bias, macro_tags')
      .eq('is_published', true)
      .order('insight_date', ascending: false)
      .limit(1);
  return rows.isEmpty ? null : rows.first;
});

/// In-flight trades for the active positions summary.
final activeTradesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, direction, unrealized_pnl, '
          'pnl_percent, entry_date')
      .eq('status', 'in_flight')
      .order('updated_at', ascending: false);
});

/// Recently landed trades.
final recentlyLandedProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, realized_pnl, pnl_percent, '
          'outcome, entry_date, exit_date')
      .eq('status', 'landed')
      .order('exit_date', ascending: false)
      .limit(5);
});

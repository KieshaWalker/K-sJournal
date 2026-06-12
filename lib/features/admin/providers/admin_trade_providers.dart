import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// All non-landed trades for the admin workbench, newest first.
final adminTradesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('*')
      .neq('status', 'landed')
      .order('updated_at', ascending: false);
});

/// Insights newest-first for the workbench — drafts included, so K can
/// delete or audit anything members can't see yet.
final adminInsightsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('insights')
      .select('id, title, body, insight_date, scope, ticker, market_bias, '
          'macro_tags, is_published, published_at, image_url')
      .order('insight_date', ascending: false)
      .order('created_at', ascending: false)
      .limit(15);
  return List<Map<String, dynamic>>.from(rows);
});

/// K's private scratchpad, most recently touched first. Admin-only RLS —
/// members have no read path to this table at all.
final adminNotesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('admin_notes')
      .select('*')
      .order('updated_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});

/// Recently landed, for reference at the bottom of the workbench.
final adminLandedProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('id, ticker, strategy_type, realized_pnl, pnl_percent, outcome, '
          'exit_date')
      .eq('status', 'landed')
      .order('exit_date', ascending: false)
      .limit(10);
});

const strategyTypes = [
  'long_call', 'long_put', 'short_call', 'short_put',
  'call_spread', 'put_spread', 'iron_condor', 'iron_butterfly',
  'straddle', 'strangle', 'covered_call', 'cash_secured_put',
  'butterfly', 'calendar', 'diagonal',
];

/// Credit strategies: position_size_usd is buying-power effect and P&L is
/// entry minus exit (premium collected).
const creditStrategies = {
  'iron_condor', 'iron_butterfly', 'short_put', 'short_call',
  'covered_call', 'cash_secured_put',
};

String strategyLabel(String s) =>
    s.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// All pre-flight trades, full detail. RLS limits these to analyst and
/// inner_circle tiers; observers simply get an empty list.
final preFlightTradesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('*')
      .eq('status', 'pre_flight')
      .order('created_at', ascending: false);
});

/// All in-flight trades, full detail, with comment flags for card counts.
final inFlightTradesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('trades')
      .select('*, trade_comments(is_question)')
      .eq('status', 'in_flight')
      .order('updated_at', ascending: false);
});

/// One trade with everything RLS allows the viewer to see; null when the
/// trade does not exist or the viewer's tier cannot read it.
final tradeDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, tradeId) async {
  final rows =
      await supabase.from('trades').select('*').eq('id', tradeId).limit(1);
  return rows.isEmpty ? null : rows.first;
});

/// Legs for a trade, in leg order. Visible for in-flight/landed trades.
final tradeLegsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, tradeId) async {
  return supabase
      .from('trade_legs')
      .select('*')
      .eq('trade_id', tradeId)
      .order('leg_number');
});

/// A trade's comment thread plus a user_id → username lookup for display.
class TradeThread {
  const TradeThread({required this.comments, required this.usernames});

  final List<Map<String, dynamic>> comments;
  final Map<String, String> usernames;
}

final tradeThreadProvider = FutureProvider.autoDispose
    .family<TradeThread, String>((ref, tradeId) async {
  final comments = await supabase
      .from('trade_comments')
      .select('id, user_id, parent_comment_id, body, is_question, '
          'created_at, updated_at')
      .eq('trade_id', tradeId)
      .order('created_at');

  final userIds = {for (final c in comments) c['user_id'] as String};
  var usernames = const <String, String>{};
  if (userIds.isNotEmpty) {
    final profiles = await supabase
        .from('public_profiles')
        .select('id, username')
        .inFilter('id', userIds.toList());
    usernames = {
      for (final p in profiles)
        p['id'] as String: (p['username'] as String?) ?? 'member',
    };
  }
  return TradeThread(
    comments: List<Map<String, dynamic>>.from(comments),
    usernames: usernames,
  );
});

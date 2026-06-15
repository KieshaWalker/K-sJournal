import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// One published insight with everything RLS allows the viewer to see; null
/// when it does not exist or is not published.
final insightDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, insightId) async {
  final rows = await supabase
      .from('insights')
      .select('id, title, body, insight_date, market_bias, macro_tags, '
          'scope, ticker, image_url')
      .eq('id', insightId)
      .limit(1);
  return rows.isEmpty ? null : rows.first;
});

/// An insight's comment thread plus a user_id → username lookup for display.
class InsightThread {
  const InsightThread({required this.comments, required this.usernames});

  final List<Map<String, dynamic>> comments;
  final Map<String, String> usernames;
}

final insightThreadProvider = FutureProvider.autoDispose
    .family<InsightThread, String>((ref, insightId) async {
  final comments = await supabase
      .from('insight_comments')
      .select('id, user_id, parent_comment_id, body, is_question, '
          'created_at, updated_at')
      .eq('insight_id', insightId)
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
  return InsightThread(
    comments: List<Map<String, dynamic>>.from(comments),
    usernames: usernames,
  );
});

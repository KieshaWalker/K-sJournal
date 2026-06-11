import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// Every member profile from the public_profiles view: K (the host) first,
/// then by how long they have been in the room.
final communityProfilesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('public_profiles')
      .select('*')
      .order('member_since', ascending: true);
  final profiles = List<Map<String, dynamic>>.from(rows);
  profiles.sort((a, b) {
    if (a['is_admin'] == true && b['is_admin'] != true) return -1;
    if (b['is_admin'] == true && a['is_admin'] != true) return 1;
    return 0; // already ordered by member_since
  });
  return profiles;
});

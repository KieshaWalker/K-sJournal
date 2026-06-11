import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// Every invitation code, newest first. Admin-only via RLS.
final inviteCodesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return supabase
      .from('invitation_codes')
      .select('*')
      .order('created_at', ascending: false);
});

/// A code is usable when active, approved, not depleted, and not past its
/// expiry — the status column alone can lag behind the expiry date.
bool inviteIsLive(Map<String, dynamic> c) {
  if (c['status'] != 'active') return false;
  final expires = c['expires_at'] as String?;
  if (expires == null) return true;
  return DateTime.parse(expires).isAfter(DateTime.now());
}

/// KJ-prefixed code from an unambiguous alphabet (no 0/O/1/I).
String generateInviteCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  final chars =
      List.generate(8, (_) => alphabet[rng.nextInt(alphabet.length)]);
  return 'KJ-${chars.sublist(0, 4).join()}-${chars.sublist(4).join()}';
}

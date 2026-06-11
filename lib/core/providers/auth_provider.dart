import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';

/// Current session, kept in sync with Supabase auth state changes.
final sessionProvider =
    NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    final sub = supabase.auth.onAuthStateChange.listen((data) {
      state = data.session;
    });
    ref.onDispose(sub.cancel);
    return supabase.auth.currentSession;
  }
}

/// Custom claims injected by the custom_access_token_hook live at the TOP
/// LEVEL of the JWT — not in user.appMetadata. Decode the access token to
/// read them.
Map<String, dynamic> decodeJwtClaims(String? token) {
  if (token == null) return const {};
  final parts = token.split('.');
  if (parts.length != 3) return const {};
  final payload =
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  return jsonDecode(payload) as Map<String, dynamic>;
}

final jwtClaimsProvider = Provider<Map<String, dynamic>>((ref) {
  final session = ref.watch(sessionProvider);
  return decodeJwtClaims(session?.accessToken);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(sessionProvider)?.user;
});

final memberTierProvider = Provider<String?>((ref) {
  return ref.watch(jwtClaimsProvider)['membership_tier'] as String?;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(jwtClaimsProvider)['is_admin'] == true;
});

final usernameProvider = Provider<String?>((ref) {
  return ref.watch(jwtClaimsProvider)['username'] as String?;
});

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// What a member goes by on screen: display_name when set, otherwise the
/// @handle.
String memberDisplayName(Map<String, dynamic>? profile) {
  final name = (profile?['display_name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return name;
  return '@${profile?['username'] as String? ?? 'member'}';
}

/// One uppercase letter for the gold-foil fallback: from the display name
/// when set, otherwise the username.
String memberInitial(Map<String, dynamic>? profile) {
  final name = (profile?['display_name'] as String?)?.trim();
  final username = profile?['username'] as String? ?? 'member';
  final source = name != null && name.isNotEmpty
      ? name
      : (username.isNotEmpty ? username : 'member');
  return source[0].toUpperCase();
}

/// Circular member photo with a gold-foil initial as the fallback. Used at
/// 52 on profile cards, 54 on the active rail, 42 on posts and the
/// composer, 30 on replies.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.url,
    required this.fallbackInitial,
    this.size = 52,
  });

  final String? url;
  final String fallbackInitial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: KGold.foil,
        shape: BoxShape.circle,
      ),
      child: Text(
        fallbackInitial,
        style: KFonts.heading(color: Colors.black, size: size * 0.42),
      ),
    );
    if (url == null || url!.isEmpty) return initial;
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => initial,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Circular member photo with a gold-foil initial as the fallback. Used at
/// 52 on directory cards, 56 on the active rail, 40-ish in the post feed.
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

import 'package:flutter/material.dart';

import '../theme.dart';

/// The house tag chips — a soft gold pill per tag, wrapping across lines.
/// Renders nothing when there are no tags, so callers can drop it in directly
/// (guard the preceding spacer with `tags.isNotEmpty` to avoid a stray gap).
class TagChips extends StatelessWidget {
  const TagChips(this.tags, {super.key});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x14C9A84C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tag,
              style: const TextStyle(fontSize: 11, color: KColors.memberAccent),
            ),
          ),
      ],
    );
  }
}

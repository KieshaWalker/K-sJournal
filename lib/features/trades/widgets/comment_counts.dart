import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// "2 questions · 3 comments" caption for a trade card. Expects the trade row
/// to carry embedded `trade_comments(is_question)`; renders nothing when the
/// thread is empty or not embedded (e.g. pre-flight, where members cannot
/// read comments).
class TradeCommentCounts extends StatelessWidget {
  const TradeCommentCounts({
    super.key,
    required this.trade,
    this.padding = EdgeInsets.zero,
  });

  final Map<String, dynamic> trade;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final rows = (trade['trade_comments'] as List?) ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    final questions =
        rows.where((r) => (r as Map)['is_question'] == true).length;
    final comments = rows.length - questions;
    final parts = [
      if (questions > 0) '$questions question${questions == 1 ? '' : 's'}',
      if (comments > 0) '$comments comment${comments == 1 ? '' : 's'}',
    ];
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mode_comment_outlined,
            size: 12,
            color: KColors.memberTextSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            parts.join(' · '),
            style: const TextStyle(
              fontSize: 11,
              color: KColors.memberTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

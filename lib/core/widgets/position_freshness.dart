import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// A small freshness line for an in-flight position, driven by the trade's
/// `current_price` and `current_as_of` (the market-data snapshot date the
/// live figures came from, stamped by admin_pull_market_data).
///
/// Three states:
///  * no live mark yet  → "Awaiting market data" (amber) — the position
///    hasn't matched the market-data source, so its P&L/greeks are blank
///    rather than wrong.
///  * recent mark       → "as of Jun 12" (muted) — purely informational.
///  * stale mark        → "as of Jun 12 · stale" (amber) — the snapshot is
///    old enough that a trading day is missing (≥ 4 calendar days, which
///    tolerates a normal Fri→Mon weekend gap).
///
/// Renders nothing for non-in-flight trades, or for legacy rows that have a
/// mark but no recorded as-of date (those gain a date on the next pull).
class PositionFreshness extends StatelessWidget {
  const PositionFreshness({super.key, required this.trade});

  final Map<String, dynamic> trade;

  /// A mark older than this many calendar days is flagged stale.
  static const _staleDays = 4;

  @override
  Widget build(BuildContext context) {
    if (trade['status'] != 'in_flight') return const SizedBox.shrink();

    final hasMark = trade['current_price'] != null;
    final asOf = DateTime.tryParse((trade['current_as_of'] as String?) ?? '');

    final String label;
    final Color color;
    final IconData icon;

    if (!hasMark) {
      label = 'Awaiting market data';
      color = KColors.pending;
      icon = Icons.cloud_off_outlined;
    } else if (asOf != null) {
      final now = DateTime.now();
      final ageDays = DateTime(now.year, now.month, now.day)
          .difference(DateTime(asOf.year, asOf.month, asOf.day))
          .inDays;
      final date = DateFormat('MMM d').format(asOf);
      final stale = ageDays >= _staleDays;
      label = stale ? 'as of $date · stale' : 'as of $date';
      color = stale ? KColors.pending : KColors.memberTextSecondary;
      icon = Icons.schedule;
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

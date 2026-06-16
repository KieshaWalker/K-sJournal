import 'package:flutter/material.dart';

import '../theme.dart';

/// Underlying stock positions embedded in a trade map under the
/// `trade_underlying_legs` key (added to the trade selects), or empty.
List<Map<String, dynamic>> underlyingRowsOf(Map<String, dynamic> trade) {
  final raw = trade['trade_underlying_legs'];
  return raw is List
      ? [for (final r in raw) Map<String, dynamic>.from(r as Map)]
      : const [];
}

/// Σ (current − entry) · shares, signed by side — the underlying's unrealized
/// P&L from the embedded rows.
double underlyingUnrealized(List<Map<String, dynamic>> rows) {
  var pnl = 0.0;
  for (final r in rows) {
    final shares = (r['shares'] as num?)?.toDouble();
    final entry = (r['entry_price'] as num?)?.toDouble();
    final current = (r['current_price'] as num?)?.toDouble();
    if (shares == null || entry == null || current == null) continue;
    pnl += (current - entry) * shares * (r['side'] == 'short' ? -1 : 1);
  }
  return pnl;
}

/// In-flight P&L blended with the underlying: the trade's options unrealized
/// plus the underlying contribution. Null only when neither side has a number.
/// Realized (landed) P&L is already blended at land time, so reads use the
/// stored `realized_pnl` directly — this is unrealized-only.
double? combinedUnrealizedPnl(Map<String, dynamic> trade) {
  final base = (trade['unrealized_pnl'] as num?)?.toDouble();
  final rows = underlyingRowsOf(trade);
  if (base == null && rows.isEmpty) return null;
  return (base ?? 0) + underlyingUnrealized(rows);
}

/// Compact one-line summary of a trade's underlying positions (e.g.
/// "+100 sh · −50 sh  underlying"); renders nothing when there are none.
class UnderlyingLine extends StatelessWidget {
  const UnderlyingLine(this.trade, {super.key});

  final Map<String, dynamic> trade;

  @override
  Widget build(BuildContext context) {
    final rows = underlyingRowsOf(trade);
    if (rows.isEmpty) return const SizedBox.shrink();
    final parts = [
      for (final r in rows)
        '${r['side'] == 'short' ? '−' : '+'}${r['shares']} sh',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined,
              size: 13, color: KColors.memberTextSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${parts.join('  ·  ')}  underlying',
              style: KFonts.data(size: 11, color: KColors.memberTextSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

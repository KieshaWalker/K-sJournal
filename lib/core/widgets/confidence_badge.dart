import 'package:flutter/material.dart';

import '../theme.dart';

/// K's conviction grade for a setup — how much confidence she's putting behind
/// the name, and by inversion how much risk it carries. Three levels plus
/// ungraded (null/unknown), which the badge renders as nothing.
enum Conviction { low, medium, high }

/// Maps the stored `confidence` value ('low'|'medium'|'high') to a [Conviction],
/// or null for an ungraded / unrecognised value.
Conviction? convictionOf(Object? raw) => switch (raw) {
      'low' => Conviction.low,
      'medium' => Conviction.medium,
      'high' => Conviction.high,
      _ => null,
    };

extension ConvictionStyle on Conviction {
  /// Risk-coded: green for high confidence, amber for medium, house-red for
  /// low (high risk).
  Color get color => switch (this) {
        Conviction.high => KColors.positive,
        Conviction.medium => KColors.pending,
        Conviction.low => KColors.negative,
      };

  /// Full pill label, in K's own phrasing.
  String get label => switch (this) {
        Conviction.high => 'HIGH CONFIDENCE',
        Conviction.medium => 'MEDIUM CONFIDENCE',
        Conviction.low => 'LOW CONF · HIGH RISK',
      };

  /// One word, for grid headings and dense rows.
  String get shortLabel => switch (this) {
        Conviction.high => 'High',
        Conviction.medium => 'Medium',
        Conviction.low => 'Low',
      };

  /// Dropdown label spelling out the grade, ungraded handled by the caller.
  String get longLabel => switch (this) {
        Conviction.high => 'High confidence',
        Conviction.medium => 'Medium confidence',
        Conviction.low => 'Low confidence · High risk',
      };

  /// The stored column value.
  String get value => name;
}

/// A soft pill carrying K's conviction grade, coloured by risk. Renders nothing
/// for an ungraded setup so callers can drop it in unguarded — pair it with a
/// `convictionOf(...) != null` guard when it owns a leading spacer.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.confidence, {super.key});

  final Object? confidence;

  @override
  Widget build(BuildContext context) {
    final c = convictionOf(confidence);
    if (c == null) return const SizedBox.shrink();
    final color = c.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        c.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}

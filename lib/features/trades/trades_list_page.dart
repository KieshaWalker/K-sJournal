import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import 'providers/trade_providers.dart';
import 'widgets/comment_counts.dart';

/// Member-facing list for one trade status: /ideas shows pre-flight,
/// /positions shows in-flight. Cards open the full trade detail page.
class TradesListPage extends ConsumerWidget {
  const TradesListPage({super.key, required this.status});

  /// 'pre_flight' or 'in_flight'.
  final String status;

  bool get _isPreFlight => status == 'pre_flight';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(
      _isPreFlight ? preFlightTradesProvider : inFlightTradesProvider,
    );
    final tier = ref.watch(memberTierProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPreFlight ? 'Pre-Flight' : 'In-Flight',
                style: KFonts.heading(size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                _isPreFlight
                    ? 'Setups on the runway'
                    : 'Live positions, as K updates them.',
                style: const TextStyle(
                  fontSize: 13,
                  color: KColors.memberTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              trades.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => const GlossyCard(
                  child: Text(
                    'Could not load trades.',
                    style: TextStyle(color: KColors.negative, fontSize: 13),
                  ),
                ),
                data: (data) {
                  if (data.isEmpty) {
                    final observerLocked =
                        _isPreFlight && !isAdmin && tier == 'observer';
                    return GlossyCard(
                      child: Text(
                        observerLocked
                            ? 'Pre-flight setups are an Analyst and Inner '
                                'Circle feature.'
                            : _isPreFlight
                                ? 'Nothing on the runway.'
                                : 'No in-flight positions.',
                        style: const TextStyle(
                          color: KColors.memberTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final t in data) _TradeCard(trade: t)],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({required this.trade});

  final Map<String, dynamic> trade;

  @override
  Widget build(BuildContext context) {
    final t = trade;
    final inFlight = t['status'] == 'in_flight';
    final pnl = (t['unrealized_pnl'] as num?)?.toDouble();
    final pnlPct = (t['pnl_percent'] as num?)?.toDouble();
    final ivr = (t['entry_iv_rank'] as num?)?.toDouble();
    final pnlColor = pnl == null
        ? KColors.neutral
        : pnl >= 0
        ? KColors.positive
        : KColors.negative;

    return GlossyCard(
      width: 348,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/trade/${t['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t['ticker'] as String,
                    style: KFonts.data(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tradeStrategyLabel(t['strategy_type'] as String)}'
                      ' · ${t['direction']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KColors.memberTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ivr != null)
                    Text(
                      'IVR ${ivr.toStringAsFixed(0)}',
                      style: KFonts.data(size: 11, color: KColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (inFlight) ...[
                Text(
                  pnl == null
                      ? '—'
                      : '${pnl >= 0 ? '+' : '−'}'
                            '\$${pnl.abs().toStringAsFixed(0)}'
                            '${pnlPct == null ? '' : '  ${pnl >= 0 ? '+' : '−'}'
                                '${pnlPct.abs().toStringAsFixed(0)}%'}',
                  style: KFonts.data(
                    size: 17,
                    color: pnlColor,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                (t['thesis_notes'] as String?) ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TradeCommentCounts(trade: t),
                  const Spacer(),
                  const Text(
                    'Full details →',
                    style: TextStyle(fontSize: 12, color: KColors.accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String tradeStrategyLabel(String s) => s
    .split('_')
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

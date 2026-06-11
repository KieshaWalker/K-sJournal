import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import 'providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InsightCard(),
            const SizedBox(height: 32),
            const _SectionLabel('Macro Pulse'),
            const SizedBox(height: 12),
            const _MacroTilesGrid(),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(child: _ActivePositions()),
                SizedBox(width: 24),
                Expanded(child: _RecentlyLanded()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: KColors.memberTextSecondary,
      ),
    );
  }
}

class _InsightCard extends ConsumerWidget {
  const _InsightCard();

  static const _biasColors = {
    'bullish': KColors.positive,
    'bearish': KColors.negative,
    'neutral': KColors.neutral,
    'cautious': KColors.pending,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(latestInsightProvider);
    return insight.when(
      loading: () => const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _ErrorCard('Could not load insight.'),
      data: (data) {
        if (data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No insight published yet.',
                  style: TextStyle(color: KColors.memberTextSecondary)),
            ),
          );
        }
        final date = DateTime.parse(data['insight_date'] as String);
        final bias = data['market_bias'] as String?;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SectionLabel(
                        "K's Take — ${DateFormat('MMMM d, yyyy').format(date)}"),
                    const Spacer(),
                    if (bias != null)
                      Row(children: [
                        Icon(Icons.circle,
                            size: 8,
                            color: _biasColors[bias] ?? KColors.neutral),
                        const SizedBox(width: 6),
                        Text(bias.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: _biasColors[bias] ?? KColors.neutral)),
                      ]),
                  ],
                ),
                const SizedBox(height: 12),
                Text(data['title'] as String, style: KFonts.heading(size: 22)),
                const SizedBox(height: 8),
                Text(
                  data['body'] as String,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MacroTilesGrid extends ConsumerWidget {
  const _MacroTilesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(macroTilesProvider);
    return tiles.when(
      loading: () => const SizedBox(
          height: 90, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _ErrorCard('Could not load market data.'),
      data: (data) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final t in data) _MacroTileCard(tile: t)],
      ),
    );
  }
}

class _MacroTileCard extends StatelessWidget {
  const _MacroTileCard({required this.tile});
  final MacroTile tile;

  @override
  Widget build(BuildContext context) {
    final change = tile.changePct;
    final color = change == null
        ? KColors.neutral
        : change >= 0
            ? KColors.positive
            : KColors.negative;
    return Container(
      width: 128,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KColors.memberBgSurface,
        border: Border.all(color: KColors.memberBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tile.ticker,
              style: KFonts.data(size: 13, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            tile.close == null
                ? '—'
                : NumberFormat('#,##0.00').format(tile.close),
            style: KFonts.data(size: 15),
          ),
          const SizedBox(height: 4),
          Text(
            change == null
                ? '—'
                : '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%',
            style: KFonts.data(size: 12, color: color),
          ),
          if (tile.ivRank != null) ...[
            const SizedBox(height: 4),
            Text('IVR ${tile.ivRank!.toStringAsFixed(0)}',
                style: KFonts.data(
                    size: 11, color: KColors.memberTextSecondary)),
          ],
        ],
      ),
    );
  }
}

class _ActivePositions extends ConsumerWidget {
  const _ActivePositions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(activeTradesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        trades.maybeWhen(
          data: (d) => _SectionLabel('Active Positions (${d.length})'),
          orElse: () => const _SectionLabel('Active Positions'),
        ),
        const SizedBox(height: 12),
        trades.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorCard('Could not load positions.'),
          data: (data) => data.isEmpty
              ? const _EmptyCard('No active positions.')
              : Card(
                  child: Column(children: [
                    for (final t in data) _TradeRow(trade: t, live: true),
                  ]),
                ),
        ),
      ],
    );
  }
}

class _RecentlyLanded extends ConsumerWidget {
  const _RecentlyLanded();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(recentlyLandedProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Recently Landed'),
        const SizedBox(height: 12),
        trades.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorCard('Could not load history.'),
          data: (data) => data.isEmpty
              ? const _EmptyCard('No landed trades yet.')
              : Card(
                  child: Column(children: [
                    for (final t in data) _TradeRow(trade: t, live: false),
                  ]),
                ),
        ),
      ],
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.trade, required this.live});

  final Map<String, dynamic> trade;
  final bool live;

  static String _strategyLabel(String s) =>
      s.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  @override
  Widget build(BuildContext context) {
    final pnl = ((live ? trade['unrealized_pnl'] : trade['realized_pnl'])
            as num?)
        ?.toDouble();
    final pnlPct = (trade['pnl_percent'] as num?)?.toDouble();
    final outcome = trade['outcome'] as String?;
    final color = pnl == null
        ? KColors.neutral
        : pnl >= 0
            ? KColors.positive
            : KColors.negative;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(trade['ticker'] as String,
                style: KFonts.data(size: 13, weight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(_strategyLabel(trade['strategy_type'] as String),
                style: const TextStyle(fontSize: 13)),
          ),
          if (outcome != null) ...[
            Icon(Icons.circle,
                size: 8,
                color: outcome == 'win'
                    ? KColors.positive
                    : outcome == 'loss'
                        ? KColors.negative
                        : KColors.neutral),
            const SizedBox(width: 12),
          ],
          Text(
            pnl == null
                ? '—'
                : '${pnl >= 0 ? '+' : '−'}\$${pnl.abs().toStringAsFixed(0)}'
                    '${pnlPct == null ? '' : '  ${pnl >= 0 ? '+' : '−'}${pnlPct.abs().toStringAsFixed(0)}%'}',
            style: KFonts.data(size: 13, color: color),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text,
            style: const TextStyle(
                color: KColors.memberTextSecondary, fontSize: 13)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text,
            style: const TextStyle(color: KColors.negative, fontSize: 13)),
      ),
    );
  }
}

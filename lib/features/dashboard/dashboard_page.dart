import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import '../trades/widgets/comment_counts.dart';
import 'providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Insights'),
                        SizedBox(height: 12),
                        _InsightCard(),
                      ],
                    ),
                  ),
                  SizedBox(width: 24),
                  Expanded(child: _MacroPulse()),
                ],
              ),
              const SizedBox(height: 32),
              const _IdeasSection(),
              const SizedBox(height: 32),
              const _InFlightSection(),
              const SizedBox(height: 32),
              const _RecentlyLanded(),
            ],
          ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.linkLabel, this.linkPath});

  final String label;
  final String? linkLabel;
  final String? linkPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SectionLabel(label),
        const Spacer(),
        if (linkLabel != null && linkPath != null)
          TextButton(
            onPressed: () => context.go(linkPath!),
            child: Text(
              linkLabel!,
              style: const TextStyle(fontSize: 12, letterSpacing: 0.5),
            ),
          ),
      ],
    );
  }
}

// ---- K's Take (expandable) ----

class _InsightCard extends ConsumerStatefulWidget {
  const _InsightCard();

  @override
  ConsumerState<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<_InsightCard> {
  bool _expanded = false;

  static const _biasColors = {
    'bullish': KColors.positive,
    'bearish': KColors.negative,
    'neutral': KColors.neutral,
    'cautious': KColors.pending,
  };

  @override
  Widget build(BuildContext context) {
    final insight = ref.watch(latestInsightProvider);
    return insight.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          const _MessageCard('Could not load insight.', color: KColors.negative),
      data: (data) {
        if (data == null) {
          return const _MessageCard('No insight published yet.');
        }
        final date = DateTime.parse(data['insight_date'] as String);
        final bias = data['market_bias'] as String?;
        return GlossyCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SectionLabel(
                      "K's Take — ${DateFormat('MMMM d, yyyy').format(date)}",
                    ),
                    const Spacer(),
                    if (bias != null) ...[
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _biasColors[bias] ?? KColors.neutral,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        bias.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: _biasColors[bias] ?? KColors.neutral,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(data['title'] as String, style: KFonts.heading(size: 22)),
                const SizedBox(height: 8),
                Text(
                  data['body'] as String,
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: KColors.memberTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---- Macro Pulse ----

class _MacroPulse extends ConsumerWidget {
  const _MacroPulse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(macroTilesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Macro Pulse'),
        const SizedBox(height: 12),
        tiles.when(
          loading: () => const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const _MessageCard('Could not load market data.',
              color: KColors.negative),
          data: (data) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final t in data) _MacroTileCard(tile: t)],
          ),
        ),
      ],
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
    return GlossyCard(
      width: 118,
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tile.ticker,
            style: KFonts.data(size: 12, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            tile.close == null
                ? '—'
                : NumberFormat('#,##0.00').format(tile.close),
            style: KFonts.data(size: 14),
          ),
          const SizedBox(height: 4),
          Text(
            change == null
                ? '—'
                : '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%',
            style: KFonts.data(size: 11, color: color),
          ),
          if (tile.ivRank != null) ...[
            const SizedBox(height: 4),
            Text(
              'IVR ${tile.ivRank!.toStringAsFixed(0)}',
              style: KFonts.data(size: 10, color: KColors.memberTextSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Ideas (pre-flight) ----

class _IdeasSection extends ConsumerWidget {
  const _IdeasSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(preFlightIdeasProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ideas.maybeWhen(
          data: (d) => _SectionHeader('Pre-Flight (${d.length})',
              linkLabel: 'View all →', linkPath: '/ideas'),
          orElse: () => const _SectionHeader('Ideas — Pre-Flight'),
        ),
        const SizedBox(height: 4),
        ideas.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const _MessageCard('Could not load ideas.',
              color: KColors.negative),
          data: (data) => data.isEmpty
              ? const _MessageCard('Nothing on the runway.')
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [for (final t in data) _IdeaCard(trade: t)],
                ),
        ),
      ],
    );
  }
}

class _IdeaCard extends StatefulWidget {
  const _IdeaCard({required this.trade});
  final Map<String, dynamic> trade;

  @override
  State<_IdeaCard> createState() => _IdeaCardState();
}

class _IdeaCardState extends State<_IdeaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final ivr = (t['entry_iv_rank'] as num?)?.toDouble();
    final tags = (t['tags'] as List?)?.cast<String>() ?? const [];
    return GlossyCard(
      width: 348,
      padding: const EdgeInsets.all(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
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
                    '${strategyLabelOf(t['strategy_type'] as String)} · ${t['direction']}',
                    style: const TextStyle(
                        fontSize: 12, color: KColors.memberTextSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ivr != null)
                  Text('IVR ${ivr.toStringAsFixed(0)}',
                      style: KFonts.data(size: 11, color: KColors.accent)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              (t['thesis_notes'] as String?) ?? '',
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            if (_expanded) ...[
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x14C9A84C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(tag,
                            style: const TextStyle(
                                fontSize: 11,
                                color: KColors.memberAccentHover)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/trade/${t['id']}'),
                  child: const Text('Full details →',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---- In-Flight ----

class _InFlightSection extends ConsumerWidget {
  const _InFlightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(activeTradesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        trades.maybeWhen(
          data: (d) => _SectionHeader('In-Flight (${d.length})',
              linkLabel: 'View all →', linkPath: '/positions'),
          orElse: () => const _SectionHeader('In-Flight'),
        ),
        const SizedBox(height: 4),
        trades.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const _MessageCard('Could not load positions.',
              color: KColors.negative),
          data: (data) => data.isEmpty
              ? const _MessageCard('No in-flight positions.')
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [for (final t in data) _InFlightCard(trade: t)],
                ),
        ),
      ],
    );
  }
}

class _InFlightCard extends StatefulWidget {
  const _InFlightCard({required this.trade});
  final Map<String, dynamic> trade;

  @override
  State<_InFlightCard> createState() => _InFlightCardState();
}

class _InFlightCardState extends State<_InFlightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final pnl = (t['unrealized_pnl'] as num?)?.toDouble();
    final pnlPct = (t['pnl_percent'] as num?)?.toDouble();
    final color = pnl == null
        ? KColors.neutral
        : pnl >= 0
        ? KColors.positive
        : KColors.negative;
    return GlossyCard(
      width: 348,
      padding: const EdgeInsets.all(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
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
                    '${strategyLabelOf(t['strategy_type'] as String)} · ${t['direction']}',
                    style: const TextStyle(
                        fontSize: 12, color: KColors.memberTextSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pnl == null
                  ? '—'
                  : '${pnl >= 0 ? '+' : '−'}\$${pnl.abs().toStringAsFixed(0)}'
                        '${pnlPct == null ? '' : '  ${pnl >= 0 ? '+' : '−'}${pnlPct.abs().toStringAsFixed(0)}%'}',
              style: KFonts.data(size: 17, color: color, weight: FontWeight.w600),
            ),
            TradeCommentCounts(
              trade: t,
              padding: const EdgeInsets.only(top: 8),
            ),
            if (_expanded) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  _Detail('Entry', t['entry_date'] as String? ?? '—'),
                  _Detail(
                    'Entry Price',
                    t['entry_price'] == null
                        ? '—'
                        : '\$${(t['entry_price'] as num).toStringAsFixed(2)}',
                  ),
                  _Detail(
                    'IVR',
                    t['entry_iv_rank'] == null
                        ? '—'
                        : (t['entry_iv_rank'] as num).toStringAsFixed(0),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/trade/${t['id']}'),
                  child: const Text('Full details →',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: KColors.memberTextSecondary)),
          const SizedBox(height: 2),
          Text(value, style: KFonts.data(size: 13)),
        ],
      ),
    );
  }
}

// ---- Recently landed ----

class _RecentlyLanded extends ConsumerWidget {
  const _RecentlyLanded();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(recentlyLandedProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Landed',
            linkLabel: 'View all →', linkPath: '/ideas'),
        const SizedBox(height: 4),
        trades.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const _MessageCard('Could not load history.',
              color: KColors.negative),
          data: (data) => data.isEmpty
              ? const _MessageCard('No landed trades yet.')
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [for (final t in data) _LandedCard(trade: t)],
                ),
        ),
      ],
    );
  }

}

class _LandedCard extends StatelessWidget {
  const _LandedCard({required this.trade});
  final Map<String, dynamic> trade;

  @override
  Widget build(BuildContext context) {
    final t = trade;
    final pnl = (t['realized_pnl'] as num?)?.toDouble();
    final pct = (t['pnl_percent'] as num?)?.toDouble();
    final positive = (pnl ?? 0) >= 0;
    final outcome = t['outcome'] as String?;
    return GlossyCard(
      width: 220,
      radius: 14,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/trade/${t['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t['ticker'] as String,
                    style: KFonts.data(size: 13, weight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: outcome == 'win'
                        ? KColors.positive
                        : outcome == 'loss'
                        ? KColors.negative
                        : KColors.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                strategyLabelOf(t['strategy_type'] as String),
                style: const TextStyle(
                    fontSize: 12, color: KColors.memberTextSecondary),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                pnl == null
                    ? '—'
                    : '${positive ? '+' : '−'}\$${pnl.abs().toStringAsFixed(0)}'
                          '${pct == null ? '' : '  ${positive ? '+' : '−'}${pct.abs().toStringAsFixed(1)}%'}',
                style: KFonts.data(
                  size: 15,
                  weight: FontWeight.w600,
                  color: positive ? KColors.positive : KColors.negative,
                ),
              ),
              TradeCommentCounts(
                trade: t,
                padding: const EdgeInsets.only(top: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Shared ----

String strategyLabelOf(String s) => s
    .split('_')
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.text, {this.color = KColors.memberTextSecondary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import '../../core/widgets/photo_attach.dart';
import '../../core/widgets/position_freshness.dart';
import '../../core/widgets/tag_chips.dart';
import '../../core/widgets/underlying_summary.dart';
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
              const _Reveal(order: 0, child: _TopSection()),
              const _Reveal(order: 1, child: _EarlyIdeasSection()),
              const SizedBox(height: 32),
              const _Reveal(order: 2, child: _IdeasSection()),
              const SizedBox(height: 32),
              const _Reveal(order: 3, child: _InFlightSection()),
              const SizedBox(height: 32),
              const _Reveal(order: 4, child: _RecentlyLanded()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insights and Macro Pulse split the top row on wide screens; on phones two
/// columns would crush both, so they stack.
class _TopSection extends StatelessWidget {
  const _TopSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Insights'),
            SizedBox(height: 12),
            _InsightsFeed(),
            SizedBox(height: 32),
            _MacroPulse(),
          ],
        );
      }
      return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel('Insights'),
                SizedBox(height: 12),
                _InsightsFeed(),
              ],
            ),
          ),
          SizedBox(width: 24),
          Expanded(child: _MacroPulse()),
        ],
      );
    });
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 2,
          margin: const EdgeInsets.only(right: 10),
          decoration: const BoxDecoration(gradient: KGold.foil),
        ),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: KColors.memberAccent,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.trailing, this.linkLabel, this.linkPath});

  final String label;

  /// Optional widget sat against the hairline before the link — the running
  /// P&L total for the section.
  final Widget? trailing;
  final String? linkLabel;
  final String? linkPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SectionLabel(label),
        const SizedBox(width: 16),
        // The rule of the house: a gold hairline that dissolves rightward.
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(gradient: KGold.hairline),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
        if (linkLabel != null && linkPath != null) ...[
          const SizedBox(width: 16),
          TextButton(
            onPressed: () => context.go(linkPath!),
            child: Text(
              linkLabel!,
              style: const TextStyle(fontSize: 12, letterSpacing: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

/// A section's running P&L total — gold-green for gains, house-red for
/// losses, neutral at flat. Used in the In-Flight (unrealized) and Landed
/// (realized) section headers.
class _PnlTotal extends StatelessWidget {
  const _PnlTotal(this.value);

  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value > 0
        ? KColors.positive
        : value < 0
            ? KColors.negative
            : KColors.neutral;
    final sign = value >= 0 ? '+' : '−';
    return Text(
      '$sign\$${NumberFormat('#,##0').format(value.abs())}',
      style: KFonts.data(size: 13, color: color, weight: FontWeight.w600),
    );
  }
}

/// A section's win rate — wins over decided (win + loss) trades, muted so the
/// P&L total beside it carries the colour. Tooltip spells out the tally.
class _WinRate extends StatelessWidget {
  const _WinRate(this.stats);

  final LandedStats stats;

  @override
  Widget build(BuildContext context) {
    final wr = stats.winRate;
    final label = wr == null ? '— W' : '${(wr * 100).round()}% W';
    final tip = '${stats.wins}W · ${stats.losses}L'
        '${stats.scratches > 0 ? ' · ${stats.scratches} scratch' : ''}';
    return Tooltip(
      message: tip,
      child: Text(
        label,
        style: KFonts.data(size: 13, color: KColors.memberTextSecondary),
      ),
    );
  }
}

/// Average winner / average loser for a section — green over red, behind a
/// muted "avg" so it reads apart from the running total. A side with no
/// trades yet shows an em dash.
class _AvgWinLoss extends StatelessWidget {
  const _AvgWinLoss(this.stats);

  final LandedStats stats;

  static String _amt(double? v) =>
      v == null ? '—' : '${v >= 0 ? '+' : '−'}\$${NumberFormat('#,##0').format(v.abs())}';

  @override
  Widget build(BuildContext context) {
    final muted = KFonts.data(size: 13, color: KColors.memberTextSecondary);
    return Tooltip(
      message: 'avg win / avg loss',
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'avg ', style: muted),
            TextSpan(
              text: _amt(stats.avgWin),
              style: KFonts.data(size: 13, color: KColors.positive),
            ),
            TextSpan(text: ' / ', style: muted),
            TextSpan(
              text: _amt(stats.avgLoss),
              style: KFonts.data(size: 13, color: KColors.negative),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sections rise into place as the page opens — staggered, brief, once.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 + widget.order * 90), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ---- K's Take (scrollable feed, each entry expandable) ----

class _InsightsFeed extends ConsumerWidget {
  const _InsightsFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsFeedProvider);
    return insights.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          const _MessageCard('Could not load insights.', color: KColors.negative),
      data: (rows) {
        if (rows.isEmpty) {
          return const _MessageCard('No insight published yet.');
        }
        // Grows with content up to the cap, then the feed scrolls — keeps
        // the slot level with Macro Pulse no matter how much K writes.
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: GlossyCard(
            padding: EdgeInsets.zero,
            hoverLift: false,
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (_, _) => Container(
                height: 1,
                decoration: const BoxDecoration(gradient: KGold.hairline),
              ),
              itemBuilder: (_, i) => _InsightTile(insight: rows[i]),
            ),
          ),
        );
      },
    );
  }
}

class _InsightTile extends StatefulWidget {
  const _InsightTile({required this.insight});

  final Map<String, dynamic> insight;

  @override
  State<_InsightTile> createState() => _InsightTileState();
}

class _InsightTileState extends State<_InsightTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.insight;
    final date = DateTime.parse(i['insight_date'] as String);
    final bias = i['market_bias'] as String?;
    final ticker = i['scope'] == 'ticker' ? i['ticker'] as String? : null;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: KColors.memberTextSecondary,
                  ),
                ),
                if (ticker != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    ticker.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: KColors.memberAccent,
                    ),
                  ),
                ],
                const Spacer(),
                if (bias != null) _BiasChip(bias: bias),
              ],
            ),
            const SizedBox(height: 6),
            Text(i['title'] as String, style: KFonts.heading(size: 16)),
            const SizedBox(height: 4),
            Text(
              i['body'] as String,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.55),
            ),
            _InsightCommentCounts(
              insight: i,
              padding: const EdgeInsets.only(top: 8),
            ),
            if (_expanded) ...[
              if ((i['image_url'] as String?)?.isNotEmpty == true)
                AttachedPhoto(url: i['image_url'] as String, maxHeight: 260),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/insight/${i['id']}'),
                  child: const Text('View & discuss →',
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

/// "2 questions · 3 comments" caption for an insight tile, from the embedded
/// `insight_comments(is_question)` rows; renders nothing when the thread is
/// empty.
class _InsightCommentCounts extends StatelessWidget {
  const _InsightCommentCounts({required this.insight, required this.padding});

  final Map<String, dynamic> insight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final rows = (insight['insight_comments'] as List?) ?? const [];
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

class _BiasChip extends StatelessWidget {
  const _BiasChip({required this.bias});

  final String bias;

  static const _biasColors = {
    'bullish': KColors.positive,
    'bearish': KColors.negative,
    'neutral': KColors.neutral,
    'cautious': KColors.pending,
  };

  @override
  Widget build(BuildContext context) {
    final color = _biasColors[bias] ?? KColors.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        bias.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: color,
        ),
      ),
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
        const SizedBox(height: 28),
        const _MacroCalendar(),
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

// ---- On the Calendar (macro catalysts, beneath Macro Pulse) ----

class _MacroCalendar extends ConsumerWidget {
  const _MacroCalendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(macroEventsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('On the Calendar'),
        const SizedBox(height: 12),
        events.when(
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const _MessageCard('Could not load the calendar.',
              color: KColors.negative),
          data: (rows) => rows.isEmpty
              ? const _MessageCard('Nothing on the calendar.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _EventCard(event: rows[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final MacroEvent event;

  /// "TODAY · JUN 16", "TOMORROW · JUN 17", or "TUE · JUN 17".
  static String _when(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    final rel = diff == 0
        ? 'TODAY'
        : diff == 1
            ? 'TOMORROW'
            : DateFormat('EEE').format(d).toUpperCase();
    return '$rel · ${DateFormat('MMM d').format(d).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 13, color: KColors.memberAccent),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  _when(event.eventDate) +
                      (event.eventTime == null ? '' : '  ·  ${event.eventTime}'),
                  style: KFonts.data(
                    size: 11,
                    weight: FontWeight.w600,
                    color: KColors.memberAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.category != null) ...[
                const SizedBox(width: 8),
                _CategoryTag(event.category!),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(event.title, style: KFonts.heading(size: 16)),
          if ((event.detail ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.detail!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
          if (event.scenarios.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in event.scenarios) _ScenarioChip(scenario: s),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A short uppercase tag — the event's category (FOMC, CPI, …).
class _CategoryTag extends StatelessWidget {
  const _CategoryTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KColors.memberAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KColors.memberAccent.withValues(alpha: 0.30)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: KColors.memberAccent,
        ),
      ),
    );
  }
}

/// One outcome chip: the condition (e.g. "Cut") in ink, the direction it
/// carries (e.g. "↗ Bullish") in the matching P&L colour.
class _ScenarioChip extends StatelessWidget {
  const _ScenarioChip({required this.scenario});
  final EventScenario scenario;

  static const _effects = {
    'bullish': (KColors.positive, '↗', 'Bullish'),
    'bearish': (KColors.negative, '↘', 'Bearish'),
    'neutral': (KColors.neutral, '→', 'Neutral'),
  };

  @override
  Widget build(BuildContext context) {
    final (color, arrow, word) =
        _effects[scenario.effect] ?? _effects['neutral']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: scenario.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: KColors.memberTextPrimary,
              ),
            ),
            TextSpan(
              text: '  $arrow $word',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Early Ideas (status = 'idea', Inner Circle perk) ----

class _EarlyIdeasSection extends ConsumerWidget {
  const _EarlyIdeasSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(earlyIdeasProvider);
    // Hidden whenever there's nothing to show: observers and analysts get an
    // empty list via RLS, so the section never renders an empty shell — only
    // inner_circle members (and admin) with live ideas see it. The leading gap
    // is owned here so a hidden section leaves no double spacing above
    // pre-flight.
    return ideas.maybeWhen(
      data: (data) => data.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _SectionHeader('Ideas (${data.length})'),
                const SizedBox(height: 4),
                CardWrap(
                  maxWidth: 348,
                  count: data.length,
                  itemBuilder: (_, i, w) => _IdeaCard(trade: data[i], width: w),
                ),
              ],
            ),
      orElse: () => const SizedBox.shrink(),
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
              : CardWrap(
                  maxWidth: 348,
                  count: data.length,
                  itemBuilder: (_, i, w) => _IdeaCard(trade: data[i], width: w),
                ),
        ),
      ],
    );
  }
}

class _IdeaCard extends StatefulWidget {
  const _IdeaCard({required this.trade, required this.width});
  final Map<String, dynamic> trade;
  final double width;

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
      width: widget.width,
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
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              TagChips(tags),
            ],
            UnderlyingLine(t),
            if (_expanded) ...[
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
          data: (d) {
            final total = d.fold<double>(
                0, (s, t) => s + ((t['unrealized_pnl'] as num?)?.toDouble() ?? 0));
            return _SectionHeader('In-Flight (${d.length})',
                trailing: d.isEmpty ? null : _PnlTotal(total),
                linkLabel: 'View all →', linkPath: '/positions');
          },
          orElse: () => const _SectionHeader('In-Flight'),
        ),
        const SizedBox(height: 4),
        trades.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const _MessageCard('Could not load positions.',
              color: KColors.negative),
          data: (data) => data.isEmpty
              ? const _MessageCard('No in-flight positions.')
              : CardWrap(
                  maxWidth: 348,
                  count: data.length,
                  itemBuilder: (_, i, w) =>
                      _InFlightCard(trade: data[i], width: w),
                ),
        ),
      ],
    );
  }
}

class _InFlightCard extends StatefulWidget {
  const _InFlightCard({required this.trade, required this.width});
  final Map<String, dynamic> trade;
  final double width;

  @override
  State<_InFlightCard> createState() => _InFlightCardState();
}

class _InFlightCardState extends State<_InFlightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final pnl = combinedUnrealizedPnl(t);
    final pnlPct = (t['pnl_percent'] as num?)?.toDouble();
    final tags = (t['tags'] as List?)?.cast<String>() ?? const [];
    final color = pnl == null
        ? KColors.neutral
        : pnl >= 0
        ? KColors.positive
        : KColors.negative;
    return GlossyCard(
      width: widget.width,
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
            PositionFreshness(trade: t),
            TradeCommentCounts(
              trade: t,
              padding: const EdgeInsets.only(top: 8),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              TagChips(tags),
            ],
            UnderlyingLine(t),
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
    final landedStats = ref.watch(landedStatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Landed',
            trailing: landedStats.maybeWhen(
                data: (st) => st.count == 0
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WinRate(st),
                          const SizedBox(width: 14),
                          _AvgWinLoss(st),
                          const SizedBox(width: 14),
                          _PnlTotal(st.realizedPnl),
                        ],
                      ),
                orElse: () => null),
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

/// M/d/yy for a stored 'yyyy-mm-dd' date string, em dash when absent.
String _mdy(Object? iso) {
  final d = DateTime.tryParse((iso as String?) ?? '');
  return d == null ? '—' : DateFormat('M/d/yy').format(d);
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
    final tags = (t['tags'] as List?)?.cast<String>() ?? const [];
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
                  if (outcome != null) _OutcomePill(outcome),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                strategyLabelOf(t['strategy_type'] as String),
                style: const TextStyle(
                    fontSize: 12, color: KColors.memberTextSecondary),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${_mdy(t['entry_date'])} - ${_mdy(t['exit_date'])}',
                style: KFonts.data(
                    size: 11, color: KColors.memberTextSecondary),
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
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                TagChips(tags),
              ],
              UnderlyingLine(t),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill(this.outcome);
  final String outcome;

  @override
  Widget build(BuildContext context) {
    final color = outcome == 'win'
        ? KColors.positive
        : outcome == 'loss'
        ? KColors.negative
        : KColors.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        outcome.toUpperCase(),
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

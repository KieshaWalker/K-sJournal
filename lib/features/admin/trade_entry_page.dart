import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'providers/admin_trade_providers.dart';
import 'widgets/idea_form.dart';
import 'widgets/in_flight_form.dart';
import 'widgets/land_form.dart';
import 'widgets/pre_flight_form.dart';

class TradeEntryPage extends ConsumerWidget {
  const TradeEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(adminTradesProvider);
    final landed = ref.watch(adminLandedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Trade Workbench',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: KColors.accent,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Idea'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const IdeaFormDialog(),
                  ).then((_) => ref.invalidate(adminTradesProvider)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            trades.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load trades: $e',
                  style: const TextStyle(color: KColors.negative)),
              data: (data) {
                final byStatus = <String, List<Map<String, dynamic>>>{};
                for (final t in data) {
                  byStatus.putIfAbsent(t['status'] as String, () => []).add(t);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusSection(
                      title: 'Ideas',
                      trades: byStatus['idea'] ?? const [],
                      emptyText: 'No ideas captured.',
                      actionLabel: 'Refine Setup →',
                      onAction: (t) => _openDialog(
                          context, ref, PreFlightFormDialog(trade: t)),
                    ),
                    _StatusSection(
                      title: 'Pre-Flight',
                      trades: byStatus['pre_flight'] ?? const [],
                      emptyText: 'Nothing on the runway.',
                      actionLabel: 'Promote to In-Flight →',
                      onAction: (t) => _openDialog(
                          context, ref, InFlightFormDialog(trade: t)),
                    ),
                    _StatusSection(
                      title: 'In-Flight',
                      trades: byStatus['in_flight'] ?? const [],
                      emptyText: 'No live positions.',
                      actionLabel: 'Close Trade →',
                      onAction: (t) =>
                          _openDialog(context, ref, LandFormDialog(trade: t)),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            const Text('RECENTLY LANDED',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: KColors.memberTextSecondary)),
            const SizedBox(height: 12),
            landed.maybeWhen(
              data: (rows) => rows.isEmpty
                  ? const Text('None yet.',
                      style: TextStyle(
                          color: KColors.memberTextSecondary, fontSize: 13))
                  : Card(
                      child: Column(children: [
                        for (final t in rows)
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.circle,
                                size: 8,
                                color: t['outcome'] == 'win'
                                    ? KColors.positive
                                    : t['outcome'] == 'loss'
                                        ? KColors.negative
                                        : KColors.neutral),
                            title: Text(
                                '${t['ticker']}  ·  ${strategyLabel(t['strategy_type'] as String)}',
                                style: const TextStyle(fontSize: 13)),
                            trailing: Text(
                              _pnlText(t),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: ((t['realized_pnl'] as num?) ?? 0) >= 0
                                      ? KColors.positive
                                      : KColors.negative),
                            ),
                          ),
                      ]),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  static String _pnlText(Map<String, dynamic> t) {
    final pnl = (t['realized_pnl'] as num?)?.toDouble();
    final pct = (t['pnl_percent'] as num?)?.toDouble();
    if (pnl == null) return '—';
    final sign = pnl >= 0 ? '+' : '−';
    return '$sign\$${pnl.abs().toStringAsFixed(0)}'
        '${pct == null ? '' : '  $sign${pct.abs().toStringAsFixed(1)}%'}';
  }

  void _openDialog(BuildContext context, WidgetRef ref, Widget dialog) {
    showDialog(context: context, builder: (_) => dialog)
        .then((_) => ref.invalidate(adminTradesProvider));
  }
}

class _StatusSection extends ConsumerWidget {
  const _StatusSection({
    required this.title,
    required this.trades,
    required this.emptyText,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final List<Map<String, dynamic>> trades;
  final String emptyText;
  final String actionLabel;
  final void Function(Map<String, dynamic>) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${title.toUpperCase()} (${trades.length})',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: KColors.memberTextSecondary)),
        const SizedBox(height: 12),
        if (trades.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(emptyText,
                style: const TextStyle(
                    color: KColors.memberTextSecondary, fontSize: 13)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Card(
              child: Column(children: [
                for (final t in trades)
                  ListTile(
                    title: Text(
                      '${t['ticker']}  ·  ${strategyLabel(t['strategy_type'] as String)}  ·  ${t['direction']}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      (t['thesis_notes'] as String?) ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t['status'] == 'idea' ||
                            t['status'] == 'pre_flight')
                          IconButton(
                            tooltip: 'Delete (allowed pre-execution only)',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _confirmDelete(context, ref, t),
                          ),
                        TextButton(
                          onPressed: () => onAction(t),
                          child: Text(actionLabel,
                              style: const TextStyle(
                                  fontSize: 12, color: KColors.accent)),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${t['ticker']} ${t['status']}?'),
        content: const Text(
            'Only ideas and pre-flight entries can be deleted. '
            'Executed trades are permanent.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: KColors.negative))),
        ],
      ),
    );
    if (ok == true) {
      await supabase.from('trades').delete().eq('id', t['id'] as String);
      ref.invalidate(adminTradesProvider);
    }
  }
}

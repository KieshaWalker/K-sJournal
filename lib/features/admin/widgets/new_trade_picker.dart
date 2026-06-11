import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/admin_trade_providers.dart';

/// Trades can only be opened from a captured idea, so the New Trade flow
/// starts here: pick an idea, and the dialog pops with its row.
class NewTradePickerDialog extends ConsumerWidget {
  const NewTradePickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(adminTradesProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Trade',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Every trade starts from an idea. Pick the one this '
                'trade executes.',
                style: TextStyle(
                  fontSize: 13,
                  color: KColors.memberTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              trades.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text(
                  'Failed to load ideas: $e',
                  style: const TextStyle(color: KColors.negative),
                ),
                data: (rows) {
                  final ideas = [
                    for (final t in rows)
                      if (t['status'] == 'idea') t,
                  ];
                  if (ideas.isEmpty) {
                    return const Text(
                      'No ideas captured yet. Add a New Idea first — '
                      'trades cannot be created from scratch.',
                      style: TextStyle(
                        color: KColors.memberTextSecondary,
                        fontSize: 13,
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final t in ideas)
                            ListTile(
                              title: Text(
                                '${t['ticker']}  ·  '
                                '${strategyLabel(t['strategy_type'] as String)}'
                                '  ·  ${t['direction']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                (t['thesis_notes'] as String?) ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontSize: 12, height: 1.5),
                              ),
                              onTap: () => Navigator.pop(context, t),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../trades/providers/trade_providers.dart';
import '../providers/admin_trade_providers.dart';
import '../../../core/theme.dart';


/// One press passes the market-data app's numbers through: exact per-leg
/// greeks and marks onto every open position, ATM IV onto ideas, and the
/// macro pulse (closes, day change, IV stats) onto the watchlist tables.
/// K runs it by hand after confirming the morning pull looks right over
/// there, so nothing needs a schedule. The heavy lifting (and the
/// market-data key) lives server-side in admin_pull_market_data().
class PullMarketDataButton extends ConsumerStatefulWidget {
  const PullMarketDataButton({super.key});

  @override
  ConsumerState<PullMarketDataButton> createState() =>
      _PullMarketDataButtonState();
}

class _PullMarketDataButtonState extends ConsumerState<PullMarketDataButton> {
  bool _busy = false;

  Future<void> _pull() async {
    setState(() => _busy = true);
    try {
      final res = await supabase.rpc('admin_pull_market_data');
      final m = Map<String, dynamic>.from(res as Map);
      ref.invalidate(adminTradesProvider);
      ref.invalidate(activeTradesProvider);
      ref.invalidate(preFlightIdeasProvider);
      ref.invalidate(inFlightTradesProvider);
      ref.invalidate(preFlightTradesProvider);
      ref.invalidate(tradeDetailProvider);
      ref.invalidate(tradeLegsProvider);
      ref.invalidate(macroTilesProvider);
      if (!mounted) return;
      final unmatched =
          List<String>.from(m['unmatched_legs'] as List? ?? const []);
      final failed =
          List<String>.from(m['failed_sources'] as List? ?? const []);
      final tail = [
        if (unmatched.isNotEmpty)
          ' — no match in market-data app for ${unmatched.join('; ')}',
        if (failed.isNotEmpty) ' — could not reach ${failed.join(', ')}',
      ].join();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Market data as of ${m['as_of'] ?? '—'}: '
          '${m['legs_updated']} legs, ${m['trades_updated']} positions, '
          '${m['ideas_updated']} ideas, ${m['macro_quotes']} quotes, '
          '${m['macro_vol']} IV rows$tail',
        ),
      ));
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pull failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _busy
          ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync, size: 18, color: KColors.accent),
      label: const Text('Pull Market Data', style: TextStyle(color: KColors.accent)),
      onPressed: _busy ? null : _pull,
    );
  }
}

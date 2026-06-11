import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../providers/admin_trade_providers.dart';
import 'form_helpers.dart';

class PreFlightFormDialog extends StatefulWidget {
  const PreFlightFormDialog({super.key, required this.trade});

  final Map<String, dynamic> trade;

  @override
  State<PreFlightFormDialog> createState() => _PreFlightFormDialogState();
}

class _PreFlightFormDialogState extends State<PreFlightFormDialog> {
  late final _thesis =
      TextEditingController(text: widget.trade['thesis_notes'] as String?);
  final _iv = TextEditingController();
  final _ivRank = TextEditingController();
  final _ivPct = TextEditingController();
  late String _strategy = widget.trade['strategy_type'] as String;
  String? _error;
  bool _busy = false;

  Future<void> _autofill() async {
    final rows = await supabase
        .from('volatility_data')
        .select('iv_current, iv_rank, iv_percentile')
        .eq('ticker', widget.trade['ticker'] as String)
        .order('snapshot_date', ascending: false)
        .limit(1);
    if (rows.isEmpty) {
      setState(() =>
          _error = 'No volatility data for ${widget.trade['ticker']} yet.');
      return;
    }
    final v = rows.first;
    setState(() {
      _error = null;
      _iv.text = '${v['iv_current'] ?? ''}';
      _ivRank.text = '${v['iv_rank'] ?? ''}';
      _ivPct.text = '${v['iv_percentile'] ?? ''}';
    });
  }

  Future<void> _save() async {
    final iv = parseNum(_iv);
    if (iv == null || iv <= 0 || iv > 5.0) {
      setState(() =>
          _error = 'IV must be a decimal between 0.01 and 5.00 (0.38 = 38%).');
      return;
    }
    if (_thesis.text.trim().length < 50) {
      setState(
          () => _error = 'Pre-flight thesis must be at least 50 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('trades').update({
        'status': 'pre_flight',
        'strategy_type': _strategy,
        'entry_iv': iv,
        'entry_iv_rank': parseNum(_ivRank),
        'entry_iv_pct': parseNum(_ivPct),
        'thesis_notes': _thesis.text.trim(),
      }).eq('id', widget.trade['id'] as String);
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogShell(
      title:
          'Pre-Flight: ${widget.trade['ticker']} (${widget.trade['direction']})',
      submitLabel: 'Save Pre-Flight',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _strategy,
          decoration:
              const InputDecoration(labelText: 'Strategy (confirmed)'),
          items: [
            for (final s in strategyTypes)
              DropdownMenuItem(value: s, child: Text(strategyLabel(s))),
          ],
          onChanged: (v) => setState(() => _strategy = v!),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: NumField(
                  controller: _iv, label: 'IV Current', hint: '0.38 = 38%')),
          const SizedBox(width: 12),
          Expanded(
              child:
                  NumField(controller: _ivRank, label: 'IV Rank', hint: '0–100')),
          const SizedBox(width: 12),
          Expanded(
              child: NumField(
                  controller: _ivPct, label: 'IV Percentile', hint: '0–100')),
        ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _autofill,
            child: const Text('Auto-fill from market data ↓',
                style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _thesis,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Updated Thesis / Structure Notes',
            helperText:
                'Strikes, expiry, max risk, profit target, entry trigger, '
                'sizing. Min 50 characters.',
          ),
        ),
      ],
    );
  }
}

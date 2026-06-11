import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../providers/admin_trade_providers.dart';
import 'form_helpers.dart';

class IdeaFormDialog extends StatefulWidget {
  const IdeaFormDialog({super.key});

  @override
  State<IdeaFormDialog> createState() => _IdeaFormDialogState();
}

class _IdeaFormDialogState extends State<IdeaFormDialog> {
  final _ticker = TextEditingController();
  final _thesis = TextEditingController();
  final _tags = TextEditingController();
  String _direction = 'bearish';
  String _strategy = 'put_spread';
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final ticker = _ticker.text.trim().toUpperCase();
    if (ticker.isEmpty || ticker.length > 5) {
      setState(() => _error = 'Ticker is required (1–5 characters).');
      return;
    }
    if (_thesis.text.trim().length < 20) {
      setState(() => _error = 'Thesis must be at least 20 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('trades').insert({
        'ticker': ticker,
        'direction': _direction,
        'strategy_type': _strategy,
        'status': 'idea',
        'thesis_notes': _thesis.text.trim(),
        'tags': _tags.text.trim().isEmpty
            ? null
            : _tags.text.split(',').map((t) => t.trim()).toList(),
      });
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
      title: 'New Trade Idea',
      submitLabel: 'Save as Idea',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        TextField(
          controller: _ticker,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Ticker'),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'bullish', label: Text('Bullish')),
            ButtonSegment(value: 'bearish', label: Text('Bearish')),
            ButtonSegment(value: 'neutral', label: Text('Neutral')),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => setState(() => _direction = s.first),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _strategy,
          decoration:
              const InputDecoration(labelText: 'Strategy (tentative)'),
          items: [
            for (final s in strategyTypes)
              DropdownMenuItem(value: s, child: Text(strategyLabel(s))),
          ],
          onChanged: (v) => setState(() => _strategy = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _thesis,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Initial Thesis',
            helperText: 'What caught your eye. Min 20 characters.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            helperText: 'Comma-separated: earnings, tech, high_iv',
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import 'form_helpers.dart';

class InsightFormDialog extends StatefulWidget {
  const InsightFormDialog({super.key});

  @override
  State<InsightFormDialog> createState() => _InsightFormDialogState();
}

class _InsightFormDialogState extends State<InsightFormDialog> {
  final _ticker = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController();
  String _scope = 'ticker';
  String? _bias;
  bool _publish = true;
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final ticker = _ticker.text.trim().toUpperCase();
    if (_scope == 'ticker' && (ticker.isEmpty || ticker.length > 5)) {
      setState(() => _error = 'Ticker is required (1–5 characters).');
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_body.text.trim().length < 20) {
      setState(() => _error = 'Body must be at least 20 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      await supabase.from('insights').insert({
        'author_id': supabase.auth.currentUser!.id,
        'insight_date': '${now.year}'
            '-${now.month.toString().padLeft(2, '0')}'
            '-${now.day.toString().padLeft(2, '0')}',
        'scope': _scope,
        'ticker': _scope == 'ticker' ? ticker : null,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'market_bias': _bias,
        'macro_tags': _tags.text.trim().isEmpty
            ? null
            : _tags.text.split(',').map((t) => t.trim()).toList(),
        'is_published': _publish,
        'published_at': _publish ? now.toUtc().toIso8601String() : null,
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
      title: 'New Insight',
      submitLabel: _publish ? 'Publish Insight' : 'Save Draft',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ticker', label: Text('Ticker')),
            ButtonSegment(value: 'macro', label: Text('Macro Theme')),
          ],
          selected: {_scope},
          onSelectionChanged: (s) => setState(() => _scope = s.first),
        ),
        const SizedBox(height: 16),
        if (_scope == 'ticker') ...[
          TextField(
            controller: _ticker,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Ticker'),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _body,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Body',
            helperText: 'The read itself. Min 20 characters.',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _bias,
          decoration: const InputDecoration(labelText: 'Market Bias'),
          items: const [
            DropdownMenuItem(value: null, child: Text('No bias')),
            DropdownMenuItem(value: 'bullish', child: Text('Bullish')),
            DropdownMenuItem(value: 'bearish', child: Text('Bearish')),
            DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
            DropdownMenuItem(value: 'cautious', child: Text('Cautious')),
          ],
          onChanged: (v) => setState(() => _bias = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(
            labelText: 'Macro Tags',
            helperText: 'Comma-separated: rates, ai_capex, energy',
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _publish,
          onChanged: (v) => setState(() => _publish = v),
          title: const Text('Publish immediately',
              style: TextStyle(fontSize: 14)),
          subtitle: const Text('Drafts stay hidden from members.',
              style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

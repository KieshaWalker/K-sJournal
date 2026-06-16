import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/photo_attach.dart';
import '../providers/admin_trade_providers.dart';
import 'form_helpers.dart';
import 'underlying_legs_field.dart';

class IdeaFormDialog extends StatefulWidget {
  const IdeaFormDialog({super.key, this.trade});

  /// When non-null, the dialog edits this existing idea in place instead of
  /// creating a new one.
  final Map<String, dynamic>? trade;

  @override
  State<IdeaFormDialog> createState() => _IdeaFormDialogState();
}

class _IdeaFormDialogState extends State<IdeaFormDialog> {
  late final _ticker =
      TextEditingController(text: widget.trade?['ticker'] as String?);
  late final _thesis =
      TextEditingController(text: widget.trade?['thesis_notes'] as String?);
  late final _tags = TextEditingController(
      text: (widget.trade?['tags'] as List?)?.cast<String>().join(', ') ?? '');
  final _photo = PhotoAttachController();
  final _underlying = UnderlyingLegsController();
  late String _direction = widget.trade?['direction'] as String? ?? 'bearish';
  late String _strategy =
      widget.trade?['strategy_type'] as String? ?? 'put_spread';
  String? _error;
  bool _busy = false;

  bool get _isEdit => widget.trade != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _underlying.loadFor(widget.trade!['id'] as String);
  }

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
    final underlyingError = _underlying.validate();
    if (underlyingError != null) {
      setState(() => _error = underlyingError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final imageUrl = _photo.hasPhoto ? await _photo.upload() : null;
      final Map<String, dynamic> payload = {
        'ticker': ticker,
        'direction': _direction,
        'strategy_type': _strategy,
        'thesis_notes': _thesis.text.trim(),
        'tags': _tags.text.trim().isEmpty
            ? null
            : _tags.text.split(',').map((t) => t.trim()).toList(),
        // Only overwrites the image when a new one was attached; an unchanged
        // edit keeps the existing chart.
        'image_url': ?imageUrl,
      };
      String tradeId;
      if (_isEdit) {
        tradeId = widget.trade!['id'] as String;
        await supabase.from('trades').update(payload).eq('id', tradeId);
      } else {
        final row = await supabase
            .from('trades')
            .insert({...payload, 'status': 'idea'})
            .select('id')
            .single();
        tradeId = row['id'] as String;
      }
      await _underlying.persist(tradeId);
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
      title: _isEdit ? 'Edit Idea' : 'New Trade Idea',
      submitLabel: _isEdit ? 'Save Changes' : 'Save as Idea',
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
        const SizedBox(height: 16),
        UnderlyingLegsField(controller: _underlying),
        const SizedBox(height: 8),
        Row(children: [
          PhotoAttachField(
            controller: _photo,
            existingUrl: widget.trade?['image_url'] as String?,
          ),
          const SizedBox(width: 4),
          const Text(
            'Attach a chart or photo (optional)',
            style: TextStyle(
              fontSize: 12,
              color: KColors.memberTextSecondary,
            ),
          ),
        ]),
      ],
    );
  }
}

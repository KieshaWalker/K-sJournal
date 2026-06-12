import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/photo_attach.dart';
import 'form_helpers.dart';

class InsightFormDialog extends StatefulWidget {
  const InsightFormDialog({super.key, this.insight});

  /// When set, the dialog edits this insight in place; otherwise it
  /// creates a new one dated today.
  final Map<String, dynamic>? insight;

  @override
  State<InsightFormDialog> createState() => _InsightFormDialogState();
}

class _InsightFormDialogState extends State<InsightFormDialog> {
  late final _ticker = TextEditingController(
      text: (widget.insight?['ticker'] as String?) ?? '');
  late final _title = TextEditingController(
      text: (widget.insight?['title'] as String?) ?? '');
  late final _body = TextEditingController(
      text: (widget.insight?['body'] as String?) ?? '');
  late final _tags = TextEditingController(
      text: (widget.insight?['macro_tags'] as List?)?.join(', ') ?? '');
  late String _scope = (widget.insight?['scope'] as String?) ?? 'ticker';
  late String? _bias = widget.insight?['market_bias'] as String?;
  late bool _publish = (widget.insight?['is_published'] as bool?) ?? true;
  final _photo = PhotoAttachController();
  bool _imageCleared = false;
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
      final imageUrl = _photo.hasPhoto ? await _photo.upload() : null;
      final payload = {
        'scope': _scope,
        'ticker': _scope == 'ticker' ? ticker : null,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'market_bias': _bias,
        'macro_tags': _tags.text.trim().isEmpty
            ? null
            : _tags.text.split(',').map((t) => t.trim()).toList(),
        'is_published': _publish,
      };
      if (imageUrl != null) {
        payload['image_url'] = imageUrl;
      } else if (_imageCleared) {
        payload['image_url'] = null;
      }
      final existing = widget.insight;
      if (existing == null) {
        await supabase.from('insights').insert({
          ...payload,
          'author_id': supabase.auth.currentUser!.id,
          'insight_date': '${now.year}'
              '-${now.month.toString().padLeft(2, '0')}'
              '-${now.day.toString().padLeft(2, '0')}',
          'published_at': _publish ? now.toUtc().toIso8601String() : null,
        });
      } else {
        // Keep the original date; stamp published_at on first publish and
        // clear it when pulled back to draft.
        if (!_publish) {
          payload['published_at'] = null;
        } else if (existing['published_at'] == null) {
          payload['published_at'] = now.toUtc().toIso8601String();
        }
        await supabase
            .from('insights')
            .update(payload)
            .eq('id', existing['id'] as String);
      }
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
      title: widget.insight == null ? 'New Insight' : 'Edit Insight',
      submitLabel: widget.insight != null
          ? 'Save Changes'
          : _publish
              ? 'Publish Insight'
              : 'Save Draft',
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
        Row(children: [
          PhotoAttachField(
            controller: _photo,
            existingUrl: _imageCleared
                ? null
                : widget.insight?['image_url'] as String?,
            onCleared: () => setState(() => _imageCleared = true),
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

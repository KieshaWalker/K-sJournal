import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import 'form_helpers.dart';

/// One editable scenario row: a condition label paired with its market effect.
class _ScenarioRow {
  _ScenarioRow({String label = '', this.effect = 'neutral'})
      : label = TextEditingController(text: label);
  final TextEditingController label;
  String effect;
}

/// Add or edit a macro-calendar event — the catalysts shown beneath the
/// dashboard's Macro Pulse. New events seed the common three-way outcome
/// (bullish / neutral / bearish) so the dominant FOMC/CPI pattern is one fill
/// away; blank rows are dropped on save.
class MacroEventFormDialog extends StatefulWidget {
  const MacroEventFormDialog({super.key, this.event});

  final Map<String, dynamic>? event;

  @override
  State<MacroEventFormDialog> createState() => _MacroEventFormDialogState();
}

class _MacroEventFormDialogState extends State<MacroEventFormDialog> {
  late final _title =
      TextEditingController(text: (widget.event?['title'] as String?) ?? '');
  late final _detail =
      TextEditingController(text: (widget.event?['detail'] as String?) ?? '');
  late final _time = TextEditingController(
      text: (widget.event?['event_time'] as String?) ?? '');
  late final _category = TextEditingController(
      text: (widget.event?['category'] as String?) ?? '');
  late DateTime _date = widget.event?['event_date'] == null
      ? DateTime.now().add(const Duration(days: 1))
      : DateTime.parse(widget.event!['event_date'] as String);
  late final List<_ScenarioRow> _scenarios = _initialScenarios();

  String? _error;
  bool _busy = false;

  List<_ScenarioRow> _initialScenarios() {
    final existing = widget.event?['scenarios'] as List?;
    if (existing != null && existing.isNotEmpty) {
      return [
        for (final s in existing)
          _ScenarioRow(
            label: ((s as Map)['label'] as String?) ?? '',
            effect: (s['effect'] as String?) ?? 'neutral',
          ),
      ];
    }
    return [
      _ScenarioRow(effect: 'bullish'),
      _ScenarioRow(effect: 'neutral'),
      _ScenarioRow(effect: 'bearish'),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _time.dispose();
    _category.dispose();
    for (final s in _scenarios) {
      s.label.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scenarios = [
        for (final s in _scenarios)
          if (s.label.text.trim().isNotEmpty)
            {'label': s.label.text.trim(), 'effect': s.effect},
      ];
      final payload = {
        'title': _title.text.trim(),
        'detail': _detail.text.trim().isEmpty ? null : _detail.text.trim(),
        'event_date': DateFormat('yyyy-MM-dd').format(_date),
        'event_time': _time.text.trim().isEmpty ? null : _time.text.trim(),
        'category': _category.text.trim().isEmpty
            ? null
            : _category.text.trim().toUpperCase(),
        'scenarios': scenarios,
      };
      final existing = widget.event;
      if (existing == null) {
        await supabase.from('macro_events').insert(payload);
      } else {
        await supabase
            .from('macro_events')
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
      title: widget.event == null ? 'New Event' : 'Edit Event',
      submitLabel: widget.event == null ? 'Add Event' : 'Save Changes',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'FOMC Rate Decision',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _detail,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Detail',
            helperText: 'The context — why it matters (optional).',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _time,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: '1:00 PM ET',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _category,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Tag',
            hintText: 'FOMC',
            helperText: 'Short label shown as a chip (optional).',
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'OUTCOMES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: KColors.memberTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'What each move means for the tape. Empty rows are dropped.',
          style: TextStyle(fontSize: 12, color: KColors.memberTextSecondary),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _scenarios.length; i++) ...[
          _scenarioRow(_scenarios[i]),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add outcome'),
            onPressed: () =>
                setState(() => _scenarios.add(_ScenarioRow())),
          ),
        ),
      ],
    );
  }

  Widget _scenarioRow(_ScenarioRow row) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: row.label,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Cut',
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<String>(
            initialValue: row.effect,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: const [
              DropdownMenuItem(value: 'bullish', child: Text('Bullish')),
              DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
              DropdownMenuItem(value: 'bearish', child: Text('Bearish')),
            ],
            onChanged: (v) => setState(() => row.effect = v ?? 'neutral'),
          ),
        ),
        IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close, size: 18),
          onPressed: _scenarios.length == 1
              ? null
              : () => setState(() {
                    _scenarios.remove(row);
                    row.label.dispose();
                  }),
        ),
      ],
    );
  }
}

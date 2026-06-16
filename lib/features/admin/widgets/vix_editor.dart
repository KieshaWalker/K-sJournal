import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import 'form_helpers.dart';

/// Set today's VIX level by hand. The external market-data project doesn't
/// carry VIX, so K types it here; the value lands in market_snapshots under
/// the 'VIX' ticker and rides the Macro Pulse like every other tile.
class VixEditorDialog extends StatefulWidget {
  const VixEditorDialog({super.key, this.current});

  /// The latest stored VIX snapshot, for prefill.
  final Map<String, dynamic>? current;

  @override
  State<VixEditorDialog> createState() => _VixEditorDialogState();
}

class _VixEditorDialogState extends State<VixEditorDialog> {
  late final _level = TextEditingController(
      text: (widget.current?['close'] as num?)?.toString() ?? '');
  late final _change = TextEditingController(
      text: (widget.current?['price_change_pct'] as num?)?.toString() ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _level.dispose();
    _change.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final level = parseNum(_level);
    if (level == null || level <= 0) {
      setState(() => _error = 'Enter the current VIX level.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await supabase.from('market_snapshots').upsert({
        'ticker': 'VIX',
        'snapshot_date': today,
        'close': level,
        'price_change_pct': parseNum(_change),
      }, onConflict: 'ticker,snapshot_date');
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogShell(
      title: 'Set VIX',
      submitLabel: 'Save VIX',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      maxWidth: 380,
      children: [
        NumField(
          controller: _level,
          label: 'VIX Level',
          hint: 'e.g. 17.50',
        ),
        const SizedBox(height: 16),
        NumField(
          controller: _change,
          label: 'Day Change %',
          hint: 'Optional — e.g. -3.2',
        ),
      ],
    );
  }
}

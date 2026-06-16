import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/photo_attach.dart';
import '../providers/admin_trade_providers.dart';
import 'form_helpers.dart';
import 'trade_photos_field.dart';
import 'underlying_legs_field.dart';

class LandFormDialog extends StatefulWidget {
  const LandFormDialog({super.key, required this.trade});

  final Map<String, dynamic> trade;

  @override
  State<LandFormDialog> createState() => _LandFormDialogState();
}

class _LandFormDialogState extends State<LandFormDialog> {
  final _exitDate = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0]);
  final _exitPrice = TextEditingController();
  final _exitNotes = TextEditingController();
  final _photo = PhotoAttachController();
  final _underlying = UnderlyingLegsController();
  final _photos = TradePhotosController();
  bool _imageCleared = false;
  String? _outcomeOverride;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final id = widget.trade['id'] as String;
    _underlying.loadFor(id);
    _photos.loadFor(id);
  }

  bool get _isCredit =>
      creditStrategies.contains(widget.trade['strategy_type'] as String);

  /// Combined realized P&L: the options leg plus every underlying position's
  /// gain/loss, over the combined capital (option position size + share basis).
  ({double pnl, double pct})? _calc() {
    final exit = parseNum(_exitPrice);
    final entry = (widget.trade['entry_price'] as num?)?.toDouble();
    final qty = (widget.trade['quantity'] as num?)?.toDouble();
    final size = (widget.trade['position_size_usd'] as num?)?.toDouble();
    if (exit == null || entry == null || qty == null || size == null) {
      return null;
    }
    final optionsPnl = (_isCredit ? (entry - exit) : (exit - entry)) * qty * 100;
    final u = _underlying.realizedFromInputs();
    final pnl = optionsPnl + u.pnl;
    final basis = size + u.basis;
    return (pnl: pnl, pct: basis == 0 ? 0 : pnl / basis * 100);
  }

  String _autoOutcome(double pct) =>
      pct >= 5 ? 'win' : (pct <= -5 ? 'loss' : 'scratch');

  Future<void> _save() async {
    final calc = _calc();
    final exitDate = DateTime.tryParse(_exitDate.text.trim());
    final entryDate =
        DateTime.tryParse((widget.trade['entry_date'] as String?) ?? '');
    if (calc == null) {
      setState(() => _error = 'Exit price is required.');
      return;
    }
    if (exitDate == null ||
        (entryDate != null && exitDate.isBefore(entryDate))) {
      setState(() => _error = 'Exit date must be on or after the entry date.');
      return;
    }
    // Exit is optional per underlying row: close the ones you're exiting,
    // leave the rest open even though the options leg is landing.
    final inputError = _underlying.validate() ?? _photos.validate();
    if (inputError != null) {
      setState(() => _error = inputError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tradeId = widget.trade['id'] as String;
      final imageUrl = _photo.hasPhoto ? await _photo.upload() : null;
      await supabase.from('trades').update({
        'status': 'landed',
        'exit_date': _exitDate.text.trim(),
        'exit_price': parseNum(_exitPrice),
        'realized_pnl': double.parse(calc.pnl.toStringAsFixed(2)),
        'pnl_percent': double.parse(calc.pct.toStringAsFixed(4)),
        'outcome': _outcomeOverride ?? _autoOutcome(calc.pct),
        'exit_notes':
            _exitNotes.text.trim().isEmpty ? null : _exitNotes.text.trim(),
        if (imageUrl != null)
          'image_url': imageUrl
        else if (_imageCleared)
          'image_url': null,
      }).eq('id', tradeId);
      await _underlying.persist(tradeId);
      await _photos.persist(tradeId);
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calc = _calc();
    final autoOutcome = calc == null ? null : _autoOutcome(calc.pct);
    return FormDialogShell(
      title: 'Land: ${widget.trade['ticker']} '
          '${strategyLabel(widget.trade['strategy_type'] as String)}',
      submitLabel: 'Confirm Landing',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        Row(children: [
          Expanded(
              child: TextField(
            controller: _exitDate,
            decoration: const InputDecoration(
                labelText: 'Exit Date', helperText: 'yyyy-mm-dd'),
          )),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _exitPrice,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Exit Price',
                  helperText: 'net debit/credit to close'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (calc != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KColors.memberBgBase,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(children: [
              Text(
                'Realized P&L:  ${calc.pnl >= 0 ? '+' : '−'}\$${calc.pnl.abs().toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        calc.pnl >= 0 ? KColors.positive : KColors.negative),
              ),
              const SizedBox(width: 24),
              Text(
                'Return:  ${calc.pct >= 0 ? '+' : '−'}${calc.pct.abs().toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 14),
              ),
            ]),
          ),
        const SizedBox(height: 16),
        UnderlyingLegsField(
          controller: _underlying,
          showExit: true,
          onChanged: () => setState(() {}),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Set an exit to close a stock position; leave it blank to keep '
            'that position open after the options land.',
            style:
                TextStyle(fontSize: 11, color: KColors.memberTextSecondary),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'win', label: Text('Win')),
            ButtonSegment(value: 'scratch', label: Text('Scratch')),
            ButtonSegment(value: 'loss', label: Text('Loss')),
          ],
          selected: {_outcomeOverride ?? autoOutcome ?? 'scratch'},
          onSelectionChanged: (s) =>
              setState(() => _outcomeOverride = s.first),
        ),
        if (autoOutcome != null && _outcomeOverride == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Auto-set from return (±5% threshold). Tap to override.',
                style: const TextStyle(
                    fontSize: 11, color: KColors.memberTextSecondary)),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _exitNotes,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Exit Notes',
            helperText:
                'Why closed, what worked, what didn\'t. The record is '
                'immutable after landing.',
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          PhotoAttachField(
            controller: _photo,
            existingUrl: _imageCleared
                ? null
                : widget.trade['image_url'] as String?,
            onCleared: () => setState(() => _imageCleared = true),
          ),
          const SizedBox(width: 4),
          const Text(
            'Attach the exit chart (optional)',
            style: TextStyle(
              fontSize: 12,
              color: KColors.memberTextSecondary,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TradePhotosField(controller: _photos),
      ],
    );
  }
}

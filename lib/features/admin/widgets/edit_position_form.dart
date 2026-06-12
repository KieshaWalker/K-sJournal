import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../providers/admin_trade_providers.dart';
import 'form_helpers.dart';

class _LegEdit {
  _LegEdit(Map<String, dynamic> row)
      : id = row['id'] as String,
        action = row['action'] as String,
        optionType = row['option_type'] as String,
        strike = TextEditingController(text: '${row['strike'] ?? ''}'),
        expiry =
            TextEditingController(text: (row['expiry_date'] as String?) ?? ''),
        qty = TextEditingController(text: '${row['quantity'] ?? ''}'),
        fill = TextEditingController(text: '${row['entry_price'] ?? ''}');

  final String id;
  String action;
  String optionType;
  final TextEditingController strike;
  final TextEditingController expiry;
  final TextEditingController qty;
  final TextEditingController fill;

  void dispose() {
    strike.dispose();
    expiry.dispose();
    qty.dispose();
    fill.dispose();
  }
}

/// Correct an in-flight position that was keyed in wrong: strategy,
/// direction, fill details, thesis, and the existing legs. Entry greeks
/// stay out of reach — the DB keeps them immutable once set — and legs
/// can only be corrected here, not added or removed.
class EditPositionDialog extends StatefulWidget {
  const EditPositionDialog({super.key, required this.trade});

  final Map<String, dynamic> trade;

  @override
  State<EditPositionDialog> createState() => _EditPositionDialogState();
}

class _EditPositionDialogState extends State<EditPositionDialog> {
  late final _entryDate = TextEditingController(
      text: (widget.trade['entry_date'] as String?) ?? '');
  late final _entryPrice =
      TextEditingController(text: '${widget.trade['entry_price'] ?? ''}');
  late final _quantity =
      TextEditingController(text: '${widget.trade['quantity'] ?? ''}');
  late final _stockPrice = TextEditingController(
      text: '${widget.trade['stock_price_at_entry'] ?? ''}');
  late final _positionSize = TextEditingController(
      text: '${widget.trade['position_size_usd'] ?? ''}');
  late final _thesis = TextEditingController(
      text: (widget.trade['thesis_notes'] as String?) ?? '');
  late String _strategy = widget.trade['strategy_type'] as String;
  late String _direction = widget.trade['direction'] as String;
  List<_LegEdit>? _legs;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLegs();
  }

  @override
  void dispose() {
    _entryDate.dispose();
    _entryPrice.dispose();
    _quantity.dispose();
    _stockPrice.dispose();
    _positionSize.dispose();
    _thesis.dispose();
    for (final leg in _legs ?? const <_LegEdit>[]) {
      leg.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLegs() async {
    try {
      final rows = await supabase
          .from('trade_legs')
          .select('*')
          .eq('trade_id', widget.trade['id'] as String)
          .order('leg_number');
      if (mounted) {
        setState(() => _legs = [for (final r in rows) _LegEdit(r)]);
      }
    } on Exception {
      if (mounted) setState(() => _error = 'Could not load legs.');
    }
  }

  Future<void> _save() async {
    final entryPrice = parseNum(_entryPrice);
    final qty = parseNum(_quantity)?.toInt();
    final entryDate = DateTime.tryParse(_entryDate.text.trim());

    if (entryDate == null) {
      setState(() => _error = 'Entry date must be yyyy-mm-dd.');
      return;
    }
    if (entryPrice == null || entryPrice <= 0) {
      setState(() => _error = 'Entry price must be > 0.');
      return;
    }
    if (qty == null || qty < 1) {
      setState(() => _error = 'Quantity must be an integer ≥ 1.');
      return;
    }
    for (final leg in _legs ?? const <_LegEdit>[]) {
      final expiry = DateTime.tryParse(leg.expiry.text.trim());
      if (expiry == null ||
          parseNum(leg.strike) == null ||
          (parseNum(leg.qty)?.toInt() ?? 0) < 1) {
        setState(() =>
            _error = 'Each leg needs strike, expiry (yyyy-mm-dd), and qty ≥ 1.');
        return;
      }
      if (expiry.isBefore(entryDate)) {
        setState(() => _error =
            'Leg expiry ${leg.expiry.text.trim()} is before the entry date — '
            'check the year.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('trades').update({
        'strategy_type': _strategy,
        'direction': _direction,
        'entry_date': _entryDate.text.trim(),
        'entry_price': entryPrice,
        'quantity': qty,
        'stock_price_at_entry': parseNum(_stockPrice),
        'position_size_usd': parseNum(_positionSize),
        'thesis_notes': _thesis.text.trim(),
      }).eq('id', widget.trade['id'] as String);
      for (final leg in _legs ?? const <_LegEdit>[]) {
        await supabase.from('trade_legs').update({
          'action': leg.action,
          'option_type': leg.optionType,
          'strike': parseNum(leg.strike),
          'expiry_date': leg.expiry.text.trim(),
          'quantity': parseNum(leg.qty)!.toInt(),
          'entry_price': parseNum(leg.fill),
        }).eq('id', leg.id);
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
      title: 'Edit Position: ${widget.trade['ticker']}',
      submitLabel: 'Save Changes',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      maxWidth: 680,
      children: [
        const Text('CLASSIFICATION',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: KColors.memberTextSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _strategy,
              decoration: const InputDecoration(labelText: 'Strategy'),
              items: [
                for (final s in strategyTypes)
                  DropdownMenuItem(value: s, child: Text(strategyLabel(s))),
              ],
              onChanged: (v) => setState(() => _strategy = v!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _direction,
              decoration: const InputDecoration(labelText: 'Direction'),
              items: const [
                DropdownMenuItem(value: 'bullish', child: Text('Bullish')),
                DropdownMenuItem(value: 'bearish', child: Text('Bearish')),
                DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
              ],
              onChanged: (v) => setState(() => _direction = v!),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('FILL INFORMATION',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: KColors.memberTextSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TextField(
            controller: _entryDate,
            decoration: const InputDecoration(
                labelText: 'Entry Date', helperText: 'yyyy-mm-dd'),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: NumField(
                  controller: _entryPrice,
                  label: 'Entry Price',
                  hint: 'net debit/credit per share')),
          const SizedBox(width: 12),
          Expanded(
              child: NumField(
                  controller: _quantity, label: 'Quantity', hint: 'contracts')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child:
                  NumField(controller: _stockPrice, label: 'Stock at Entry')),
          const SizedBox(width: 12),
          Expanded(
              child: NumField(
                  controller: _positionSize, label: 'Position Size USD')),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _thesis,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Thesis Notes'),
        ),
        const SizedBox(height: 20),
        const Text('TRADE LEGS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: KColors.memberTextSecondary)),
        const SizedBox(height: 12),
        if (_legs == null)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ))
        else if (_legs!.isEmpty)
          const Text(
            'No legs recorded for this position.',
            style:
                TextStyle(fontSize: 13, color: KColors.memberTextSecondary),
          )
        else
          for (final leg in _legs!) _legRow(leg),
        const SizedBox(height: 4),
        const Text(
          'After fixing legs, press Pull Market Data so the live greeks '
          'match the corrected contract.',
          style: TextStyle(fontSize: 12, color: KColors.memberTextSecondary),
        ),
      ],
    );
  }

  Widget _legRow(_LegEdit leg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        DropdownButton<String>(
          value: leg.action,
          items: const [
            DropdownMenuItem(value: 'buy', child: Text('Buy')),
            DropdownMenuItem(value: 'sell', child: Text('Sell')),
          ],
          onChanged: (v) => setState(() => leg.action = v!),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: leg.optionType,
          items: const [
            DropdownMenuItem(value: 'call', child: Text('Call')),
            DropdownMenuItem(value: 'put', child: Text('Put')),
          ],
          onChanged: (v) => setState(() => leg.optionType = v!),
        ),
        const SizedBox(width: 8),
        Expanded(child: NumField(controller: leg.strike, label: 'Strike')),
        const SizedBox(width: 8),
        Expanded(
            child: TextField(
          controller: leg.expiry,
          decoration: const InputDecoration(labelText: 'Expiry yyyy-mm-dd'),
        )),
        const SizedBox(width: 8),
        SizedBox(width: 64, child: NumField(controller: leg.qty, label: 'Qty')),
        const SizedBox(width: 8),
        Expanded(child: NumField(controller: leg.fill, label: 'Fill Px')),
      ]),
    );
  }
}

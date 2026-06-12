import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/photo_attach.dart';
import '../providers/admin_trade_providers.dart';
import 'form_helpers.dart';

class _LegInput {
  String action = 'buy';
  String optionType = 'put';
  final strike = TextEditingController();
  final expiry = TextEditingController(); // yyyy-mm-dd
  final qty = TextEditingController();
  final fill = TextEditingController();
}

class InFlightFormDialog extends StatefulWidget {
  const InFlightFormDialog({super.key, required this.trade});

  final Map<String, dynamic> trade;

  @override
  State<InFlightFormDialog> createState() => _InFlightFormDialogState();
}

class _InFlightFormDialogState extends State<InFlightFormDialog> {
  final _entryDate = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0]);
  final _entryPrice = TextEditingController();
  final _quantity = TextEditingController();
  final _stockPrice = TextEditingController();
  final _positionSize = TextEditingController();
  final _delta = TextEditingController();
  final _gamma = TextEditingController();
  final _theta = TextEditingController();
  final _vega = TextEditingController();
  final _iv = TextEditingController(text: '');
  final _legs = <_LegInput>[_LegInput()];
  final _photo = PhotoAttachController();
  bool _imageCleared = false;
  String? _error;
  bool _busy = false;

  bool get _isCredit =>
      creditStrategies.contains(widget.trade['strategy_type'] as String);

  void _autoPositionSize() {
    final price = parseNum(_entryPrice);
    final qty = parseNum(_quantity);
    if (price != null && qty != null && !_isCredit) {
      _positionSize.text = (price * qty * 100).toStringAsFixed(2);
    }
  }

  double? _legNet() {
    double net = 0;
    for (final leg in _legs) {
      final fill = parseNum(leg.fill);
      if (fill == null) return null;
      net += leg.action == 'buy' ? fill : -fill;
    }
    // For credit structures net is negative (credit received); compare on
    // magnitude against entry_price which is recorded as a positive number.
    return net.abs();
  }

  Future<void> _save() async {
    final entryPrice = parseNum(_entryPrice);
    final qty = parseNum(_quantity)?.toInt();
    final stockPrice = parseNum(_stockPrice);
    final posSize = parseNum(_positionSize);
    final entryDate = DateTime.tryParse(_entryDate.text.trim());

    if (entryDate == null) {
      setState(() => _error = 'Entry date must be yyyy-mm-dd.');
      return;
    }
    if (entryDate.isAfter(DateTime.now())) {
      setState(() => _error = 'Entry date cannot be in the future.');
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
    if (stockPrice == null || stockPrice <= 0) {
      setState(() => _error = 'Stock price at entry is required.');
      return;
    }
    if (posSize == null || posSize <= 0) {
      setState(() => _error = _isCredit
          ? 'Position size = buying power effect (margin requirement) for '
              'credit trades.'
          : 'Position size is required.');
      return;
    }
    final net = _legNet();
    if (net == null) {
      setState(() => _error = 'Every leg needs a fill price.');
      return;
    }
    if ((net - entryPrice).abs() > 0.05) {
      setState(() => _error =
          'Leg net (\$${net.toStringAsFixed(2)}) does not match entry price '
          '(\$${entryPrice.toStringAsFixed(2)}) within \$0.05.');
      return;
    }
    for (final leg in _legs) {
      if (DateTime.tryParse(leg.expiry.text.trim()) == null ||
          parseNum(leg.strike) == null ||
          (parseNum(leg.qty)?.toInt() ?? 0) < 1) {
        setState(() =>
            _error = 'Each leg needs strike, expiry (yyyy-mm-dd), and qty ≥ 1.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tradeId = widget.trade['id'] as String;
      await supabase.from('trade_legs').insert([
        for (var i = 0; i < _legs.length; i++)
          {
            'trade_id': tradeId,
            'leg_number': i + 1,
            'action': _legs[i].action,
            'option_type': _legs[i].optionType,
            'strike': parseNum(_legs[i].strike),
            'expiry_date': _legs[i].expiry.text.trim(),
            'quantity': parseNum(_legs[i].qty)!.toInt(),
            'entry_price': parseNum(_legs[i].fill),
          }
      ]);
      final imageUrl = _photo.hasPhoto ? await _photo.upload() : null;
      await supabase.from('trades').update({
        'status': 'in_flight',
        'entry_date': _entryDate.text.trim(),
        'entry_price': entryPrice,
        'quantity': qty,
        'stock_price_at_entry': stockPrice,
        'position_size_usd': posSize,
        'entry_delta': parseNum(_delta),
        'entry_gamma': parseNum(_gamma),
        'entry_theta': parseNum(_theta),
        'entry_vega': parseNum(_vega),
        'entry_iv': parseNum(_iv) ?? widget.trade['entry_iv'],
        if (imageUrl != null)
          'image_url': imageUrl
        else if (_imageCleared)
          'image_url': null,
      }).eq('id', tradeId);
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
      title: 'In-Flight: ${widget.trade['ticker']} '
          '${strategyLabel(widget.trade['strategy_type'] as String)}',
      submitLabel: 'Promote to In-Flight',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      maxWidth: 680,
      children: [
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
              controller: _positionSize,
              label: 'Position Size USD',
              hint: _isCredit
                  ? 'buying power effect (margin)'
                  : 'auto: price × qty × 100',
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
              onPressed: () {
                _autoPositionSize();
                setState(() {});
              },
              child: const Text('Auto', style: TextStyle(fontSize: 12))),
        ]),
        const SizedBox(height: 20),
        const Text('ENTRY GREEKS (from brokerage at fill)',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: KColors.memberTextSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: NumField(controller: _delta, label: 'Delta')),
          const SizedBox(width: 12),
          Expanded(child: NumField(controller: _gamma, label: 'Gamma')),
          const SizedBox(width: 12),
          Expanded(child: NumField(controller: _theta, label: 'Theta')),
          const SizedBox(width: 12),
          Expanded(child: NumField(controller: _vega, label: 'Vega')),
          const SizedBox(width: 12),
          Expanded(
              child: NumField(controller: _iv, label: 'IV', hint: '0.38')),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          const Text('TRADE LEGS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: KColors.memberTextSecondary)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => setState(() => _legs.add(_LegInput())),
          ),
        ]),
        for (var i = 0; i < _legs.length; i++) _legRow(i),
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

  Widget _legRow(int i) {
    final leg = _legs[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text('${i + 1}',
            style:
                const TextStyle(fontSize: 12, color: KColors.memberTextSecondary)),
        const SizedBox(width: 8),
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
        SizedBox(
            width: 64, child: NumField(controller: leg.qty, label: 'Qty')),
        const SizedBox(width: 8),
        Expanded(child: NumField(controller: leg.fill, label: 'Fill Px')),
        if (_legs.length > 1)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _legs.removeAt(i)),
          ),
      ]),
    );
  }
}

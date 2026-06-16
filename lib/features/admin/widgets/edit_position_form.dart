import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../providers/admin_trade_providers.dart';
import 'form_helpers.dart';
import 'trade_photos_field.dart';
import 'underlying_legs_field.dart';

String _numStr(Object? v) => v == null ? '' : '$v';

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
/// direction, fill details, thesis, tags, the existing option legs, and the
/// underlying stock positions (which can be added, edited, or removed, and
/// their live marks updated). Entry greeks stay out of reach — the DB keeps
/// them immutable once set — and option legs can only be corrected here, not
/// added or removed.
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
  late final _tags = TextEditingController(
      text: (widget.trade['tags'] as List?)?.cast<String>().join(', ') ?? '');
  late final _curDelta =
      TextEditingController(text: _numStr(widget.trade['current_delta']));
  late final _curGamma =
      TextEditingController(text: _numStr(widget.trade['current_gamma']));
  late final _curTheta =
      TextEditingController(text: _numStr(widget.trade['current_theta']));
  late final _curVega =
      TextEditingController(text: _numStr(widget.trade['current_vega']));
  late final _curIv =
      TextEditingController(text: _numStr(widget.trade['current_iv']));
  late final _curPrice =
      TextEditingController(text: _numStr(widget.trade['current_price']));
  late String _strategy = widget.trade['strategy_type'] as String;
  late String _direction = widget.trade['direction'] as String;
  final _underlying = UnderlyingLegsController();
  final _photos = TradePhotosController();
  // Snapshot of the greek fields as loaded, to tell whether the admin touched
  // them (only then do we re-stamp today's greeks snapshot).
  late final List<String> _greekOrig;
  List<_LegEdit>? _legs;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLegs();
    final id = widget.trade['id'] as String;
    _underlying.loadFor(id);
    _photos.loadFor(id);
    _greekOrig = [
      _curDelta.text, _curGamma.text, _curTheta.text,
      _curVega.text, _curIv.text, _curPrice.text,
    ];
  }

  @override
  void dispose() {
    _entryDate.dispose();
    _entryPrice.dispose();
    _quantity.dispose();
    _stockPrice.dispose();
    _positionSize.dispose();
    _thesis.dispose();
    _tags.dispose();
    _curDelta.dispose();
    _curGamma.dispose();
    _curTheta.dispose();
    _curVega.dispose();
    _curIv.dispose();
    _curPrice.dispose();
    for (final leg in _legs ?? const <_LegEdit>[]) {
      leg.dispose();
    }
    super.dispose();
  }

  bool get _greeksTouched {
    final now = [
      _curDelta.text, _curGamma.text, _curTheta.text,
      _curVega.text, _curIv.text, _curPrice.text,
    ];
    for (var i = 0; i < now.length; i++) {
      if (now[i].trim() != _greekOrig[i].trim()) return true;
    }
    return false;
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
      final Map<String, dynamic> updates = {
        'strategy_type': _strategy,
        'direction': _direction,
        'entry_date': _entryDate.text.trim(),
        'entry_price': entryPrice,
        'quantity': qty,
        'stock_price_at_entry': parseNum(_stockPrice),
        'position_size_usd': parseNum(_positionSize),
        'thesis_notes': _thesis.text.trim(),
        'tags': _tags.text.trim().isEmpty
            ? null
            : _tags.text.split(',').map((t) => t.trim()).toList(),
      };
      // Touching the greek fields records/replaces TODAY's snapshot (the sync
      // trigger turns this current_* write into a trade_greeks row); the cost-
      // to-close convention matches the land form / pull.
      if (_greeksTouched) {
        final isCredit = creditStrategies.contains(_strategy);
        final cur = parseNum(_curPrice);
        final unrealized = (cur != null)
            ? double.parse(
                ((isCredit ? entryPrice - cur : cur - entryPrice) * qty * 100)
                    .toStringAsFixed(2))
            : null;
        updates.addAll({
          'current_delta': parseNum(_curDelta),
          'current_gamma': parseNum(_curGamma),
          'current_theta': parseNum(_curTheta),
          'current_vega': parseNum(_curVega),
          'current_iv': parseNum(_curIv),
          'current_price': cur,
          'current_as_of': DateTime.now().toIso8601String().split('T').first,
          'unrealized_pnl': unrealized,
        });
      }
      await supabase.from('trades').update(updates).eq('id', tradeId);
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
        const SizedBox(height: 12),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            helperText: 'Comma-separated: earnings, tech, high_iv',
          ),
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
        const SizedBox(height: 20),
        UnderlyingLegsField(controller: _underlying, showCurrent: true),
        const SizedBox(height: 20),
        const Text('CURRENT GREEKS (AS OF TODAY)',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: KColors.memberTextSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: NumField(controller: _curDelta, label: 'Delta')),
          const SizedBox(width: 12),
          Expanded(child: NumField(controller: _curGamma, label: 'Gamma')),
          const SizedBox(width: 12),
          Expanded(child: NumField(controller: _curTheta, label: 'Theta')),
          const SizedBox(width: 12),
          Expanded(child: NumField(controller: _curVega, label: 'Vega')),
          const SizedBox(width: 12),
          Expanded(
              child: NumField(controller: _curIv, label: 'IV', hint: '0.38')),
          const SizedBox(width: 12),
          Expanded(
              child: NumField(
                  controller: _curPrice,
                  label: 'Price',
                  hint: 'net mark to close')),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Editing any greek records today\'s snapshot (replacing an earlier '
            'one from today). Past days are frozen; a later pull overwrites only '
            'today.',
            style: TextStyle(fontSize: 11, color: KColors.memberTextSecondary),
          ),
        ),
        const SizedBox(height: 20),
        TradePhotosField(controller: _photos),
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

import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import 'form_helpers.dart';

/// One editable underlying-position row.
class UnderlyingLegInput {
  UnderlyingLegInput({this.side = 'long'});

  UnderlyingLegInput.fromRow(Map<String, dynamic> r)
      : side = (r['side'] as String?) ?? 'long' {
    shares.text = r['shares'] == null ? '' : '${r['shares']}';
    entry.text = _fmtNum(r['entry_price']);
    current.text = _fmtNum(r['current_price']);
    exit.text = _fmtNum(r['exit_price']);
  }

  String side;
  final shares = TextEditingController();
  final entry = TextEditingController();
  final current = TextEditingController();
  final exit = TextEditingController();
}

/// Holds the underlying stock positions being edited in a stage form, and
/// persists them back to `trade_underlying_legs`. Mirrors the controller
/// pattern of [PhotoAttachController]. A trade may have several rows (scaling
/// in/out); persistence replaces the whole set for simplicity.
class UnderlyingLegsController extends ChangeNotifier {
  final List<UnderlyingLegInput> rows = [];
  bool _loaded = false;

  /// True once [loadFor] has run — lets a form show a spinner until existing
  /// rows arrive in edit mode.
  bool get isLoaded => _loaded;

  void add() {
    rows.add(UnderlyingLegInput());
    notifyListeners();
  }

  void removeAt(int i) {
    rows.removeAt(i);
    notifyListeners();
  }

  /// Rebuild after a non-list field (e.g. side) changes in place.
  void update() => notifyListeners();

  /// Seed the editor from an existing trade's saved rows (edit mode).
  Future<void> loadFor(String tradeId) async {
    final data = await supabase
        .from('trade_underlying_legs')
        .select('side, shares, entry_price, current_price, exit_price')
        .eq('trade_id', tradeId)
        .order('created_at');
    rows
      ..clear()
      ..addAll([for (final r in data) UnderlyingLegInput.fromRow(r)]);
    _loaded = true;
    notifyListeners();
  }

  /// Live realized P&L and cost basis from the editor's current text — used by
  /// the land form's preview before the rows are persisted. Only positions
  /// with an exit price (i.e. being closed at this landing) count; rows left
  /// open contribute nothing to realized P&L or its basis.
  ({double pnl, double basis}) realizedFromInputs() {
    var pnl = 0.0, basis = 0.0;
    for (final r in rows) {
      final shares = double.tryParse(r.shares.text.trim());
      final entry = double.tryParse(r.entry.text.trim());
      final exit = double.tryParse(r.exit.text.trim());
      if (shares == null || entry == null || exit == null) continue;
      basis += entry * shares;
      pnl += (exit - entry) * shares * (r.side == 'short' ? -1 : 1);
    }
    return (pnl: pnl, basis: basis);
  }

  /// null when valid; otherwise a message. [requireExit] applies at landing.
  String? validate({bool requireExit = false}) {
    for (final r in rows) {
      final shares = int.tryParse(r.shares.text.trim());
      final entry = double.tryParse(r.entry.text.trim());
      if (shares == null || shares < 1 || entry == null || entry <= 0) {
        return 'Each underlying position needs shares ≥ 1 and entry price > 0.';
      }
      if (requireExit && double.tryParse(r.exit.text.trim()) == null) {
        return 'Each underlying position needs an exit price to land.';
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _payload(String tradeId) => [
        for (final r in rows)
          {
            'trade_id': tradeId,
            'side': r.side,
            'shares': int.parse(r.shares.text.trim()),
            'entry_price': double.parse(r.entry.text.trim()),
            'current_price': ?double.tryParse(r.current.text.trim()),
            'exit_price': ?double.tryParse(r.exit.text.trim()),
          },
      ];

  /// Replace this trade's underlying legs with the editor's current rows.
  /// Call after [validate] passes.
  Future<void> persist(String tradeId) async {
    await supabase
        .from('trade_underlying_legs')
        .delete()
        .eq('trade_id', tradeId);
    final payload = _payload(tradeId);
    if (payload.isNotEmpty) {
      await supabase.from('trade_underlying_legs').insert(payload);
    }
  }
}

/// Add/remove list of underlying stock positions. [showCurrent] reveals a live
/// mark column (in-flight); [showExit] reveals a close column (landed).
class UnderlyingLegsField extends StatelessWidget {
  const UnderlyingLegsField({
    super.key,
    required this.controller,
    this.showCurrent = false,
    this.showExit = false,
    this.onChanged,
  });

  final UnderlyingLegsController controller;
  final bool showCurrent;
  final bool showExit;

  /// Fired as any row value is typed — lets a parent (e.g. the land form's
  /// P&L preview) recompute live.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('UNDERLYING POSITION(S)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: KColors.memberTextSecondary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add underlying position',
                onPressed: controller.add,
              ),
            ]),
            if (controller.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('No underlying stock position.',
                    style: TextStyle(
                        fontSize: 12, color: KColors.memberTextSecondary)),
              ),
            for (var i = 0; i < controller.rows.length; i++) _row(i),
          ],
        );
      },
    );
  }

  Widget _row(int i) {
    final r = controller.rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        DropdownButton<String>(
          value: r.side,
          items: const [
            DropdownMenuItem(value: 'long', child: Text('Long')),
            DropdownMenuItem(value: 'short', child: Text('Short')),
          ],
          onChanged: (v) {
            r.side = v!;
            controller.update();
            onChanged?.call();
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 84,
            child: NumField(
                controller: r.shares,
                label: 'Shares',
                onChanged: (_) => onChanged?.call())),
        const SizedBox(width: 8),
        Expanded(
            child: NumField(
                controller: r.entry,
                label: 'Entry',
                onChanged: (_) => onChanged?.call())),
        if (showCurrent) ...[
          const SizedBox(width: 8),
          Expanded(child: NumField(controller: r.current, label: 'Current')),
        ],
        if (showExit) ...[
          const SizedBox(width: 8),
          Expanded(
              child: NumField(
                  controller: r.exit,
                  label: 'Exit',
                  onChanged: (_) => onChanged?.call())),
        ],
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Remove',
          onPressed: () => controller.removeAt(i),
        ),
      ]),
    );
  }
}

String _fmtNum(Object? v) {
  if (v == null) return '';
  final n = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (n == null) return '';
  return n == n.roundToDouble()
      ? n.toStringAsFixed(0)
      : n.toString();
}

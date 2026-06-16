import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import '../../core/widgets/photo_attach.dart';
import '../../core/widgets/position_freshness.dart';
import '../../core/widgets/underlying_summary.dart';
import 'providers/trade_providers.dart';
import 'trades_list_page.dart';

/// Full detail for one trade: thesis, entry/exit data, Greeks, legs, and the
/// member discussion thread (questions and comments).
class TradeDetailPage extends ConsumerWidget {
  const TradeDetailPage({super.key, required this.tradeId});

  final String tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trade = ref.watch(tradeDetailProvider(tradeId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: trade.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const GlossyCard(
              child: Text(
                'Could not load this trade.',
                style: TextStyle(color: KColors.negative, fontSize: 13),
              ),
            ),
            data: (t) {
              if (t == null) {
                return GlossyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This trade is not available on your membership.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/dashboard'),
                        child: const Text('← Back to dashboard',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }
              return _TradeDetail(trade: t, tradeId: tradeId);
            },
          ),
        ),
      ),
    );
  }
}

class _TradeDetail extends StatelessWidget {
  const _TradeDetail({required this.trade, required this.tradeId});

  final Map<String, dynamic> trade;
  final String tradeId;

  @override
  Widget build(BuildContext context) {
    final t = trade;
    final status = t['status'] as String;
    final inFlight = status == 'in_flight';
    final landed = status == 'landed';
    final backPath = status == 'pre_flight' ? '/ideas' : '/positions';
    final tags = (t['tags'] as List?)?.cast<String>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go(backPath),
          icon: const Icon(Icons.arrow_back, size: 14),
          label: Text(
            status == 'pre_flight' ? 'Pre-Flight' : 'In-Flight',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        GlossyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t['ticker'] as String,
                    style: KFonts.heading(size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${tradeStrategyLabel(t['strategy_type'] as String)}'
                      ' · ${t['direction']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: KColors.memberTextSecondary,
                      ),
                    ),
                  ),
                  _StatusChip(status: status, outcome: t['outcome'] as String?),
                ],
              ),
              if (inFlight || landed) ...[
                const SizedBox(height: 14),
                Text(
                  _pnlText(t, landed: landed),
                  style: KFonts.data(
                    size: 22,
                    weight: FontWeight.w600,
                    color: _pnlColor(t, landed: landed),
                  ),
                ),
                PositionFreshness(trade: t),
              ],
              if ((t['thesis_notes'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 18),
                const _Label('Thesis'),
                const SizedBox(height: 8),
                Text(
                  t['thesis_notes'] as String,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ],
              if ((t['image_url'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 14),
                AttachedPhoto(url: t['image_url'] as String, maxHeight: 420),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x14C9A84C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            color: KColors.memberAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StatsCard(
          label: 'Volatility at Entry',
          stats: [
            ('IV', _num(t['entry_iv'], 2)),
            ('IV Rank', _num(t['entry_iv_rank'], 0)),
            ('IV %ile', _num(t['entry_iv_pct'], 0)),
          ],
        ),
        if (underlyingRowsOf(t).isNotEmpty) ...[
          const SizedBox(height: 16),
          _UnderlyingCard(rows: underlyingRowsOf(t)),
        ],
        if (_childRows(t, 'trade_photos').isNotEmpty) ...[
          const SizedBox(height: 16),
          _PhotoGallery(photos: _childRows(t, 'trade_photos')),
        ],
        if (inFlight || landed) ...[
          const SizedBox(height: 16),
          _StatsCard(
            label: 'Entry',
            stats: [
              ('Date', t['entry_date'] as String? ?? '—'),
              ('Price', _money(t['entry_price'])),
              ('Qty', '${t['quantity'] ?? '—'}'),
              ('Size', _money(t['position_size_usd'], digits: 0)),
              ('Stock', _money(t['stock_price_at_entry'])),
            ],
          ),
          const SizedBox(height: 16),
          _StatsCard(
            label: 'Greeks at Entry',
            stats: [
              ('Delta', _num(t['entry_delta'], 2)),
              ('Gamma', _num(t['entry_gamma'], 3)),
              ('Theta', _num(t['entry_theta'], 2)),
              ('Vega', _num(t['entry_vega'], 2)),
            ],
          ),
        ],
        if (inFlight) ...[
          const SizedBox(height: 16),
          _StatsCard(
            label: 'Live',
            stats: [
              ('Price', _money(t['current_price'])),
              ('Delta', _num(t['current_delta'], 2)),
              ('Gamma', _num(t['current_gamma'], 3)),
              ('Theta', _num(t['current_theta'], 2)),
              ('Vega', _num(t['current_vega'], 2)),
              ('IV', _num(t['current_iv'], 2)),
            ],
          ),
        ],
        if (landed) ...[
          const SizedBox(height: 16),
          _StatsCard(
            label: 'Exit',
            stats: [
              ('Date', t['exit_date'] as String? ?? '—'),
              ('Price', _money(t['exit_price'])),
              ('Realized', _money(t['realized_pnl'], digits: 0)),
              ('Return', '${_num(t['pnl_percent'], 1)}%'),
            ],
          ),
          if ((t['exit_notes'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            GlossyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Exit Notes'),
                  const SizedBox(height: 8),
                  Text(
                    t['exit_notes'] as String,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (inFlight || landed) ...[
          if (_childRows(t, 'trade_greeks').isNotEmpty) ...[
            const SizedBox(height: 16),
            _GreeksHistoryCard(rows: _childRows(t, 'trade_greeks')),
          ],
          const SizedBox(height: 16),
          _LegsCard(tradeId: tradeId),
          const SizedBox(height: 16),
          _DiscussionCard(tradeId: tradeId),
        ] else ...[
          const SizedBox(height: 16),
          const GlossyCard(
            child: Text(
              'Discussion opens when this trade goes live.',
              style: TextStyle(
                fontSize: 13,
                color: KColors.memberTextSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Landed P&L is the stored (already blended) realized figure; in-flight is
  /// the options unrealized blended with the underlying.
  static double? _pnl(Map<String, dynamic> t, {required bool landed}) => landed
      ? (t['realized_pnl'] as num?)?.toDouble()
      : combinedUnrealizedPnl(t);

  static String _pnlText(Map<String, dynamic> t, {required bool landed}) {
    final pnl = _pnl(t, landed: landed);
    final pct = (t['pnl_percent'] as num?)?.toDouble();
    if (pnl == null) return '—';
    final sign = pnl >= 0 ? '+' : '−';
    return '$sign\$${pnl.abs().toStringAsFixed(0)}'
        '${pct == null ? '' : '  $sign${pct.abs().toStringAsFixed(1)}%'}'
        '${landed ? '' : '  unrealized'}';
  }

  static Color _pnlColor(Map<String, dynamic> t, {required bool landed}) {
    final pnl = _pnl(t, landed: landed);
    if (pnl == null) return KColors.neutral;
    return pnl >= 0 ? KColors.positive : KColors.negative;
  }
}

String _num(Object? v, int digits) =>
    v == null ? '—' : (v as num).toStringAsFixed(digits);

String _money(Object? v, {int digits = 2}) => v == null
    ? '—'
    : '\$${NumberFormat('#,##0${digits == 0 ? '' : '.${'0' * digits}'}').format(v as num)}';

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: KColors.memberTextSecondary,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.outcome});

  final String status;
  final String? outcome;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pre_flight' => ('PRE-FLIGHT', KColors.pending),
      'in_flight' => ('IN-FLIGHT', KColors.accent),
      'landed' => (
          'LANDED · ${(outcome ?? '').toUpperCase()}',
          outcome == 'win'
              ? KColors.positive
              : outcome == 'loss'
                  ? KColors.negative
                  : KColors.neutral,
        ),
      _ => (status.toUpperCase(), KColors.neutral),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.label, required this.stats});

  final String label;
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.every((s) => s.$2 == '—')) return const SizedBox.shrink();
    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          const SizedBox(height: 12),
          Wrap(
            spacing: 36,
            runSpacing: 12,
            children: [
              for (final (name, value) in stats)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: KColors.memberTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: KFonts.data(size: 14)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegsCard extends ConsumerWidget {
  const _LegsCard({required this.tradeId});

  final String tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legs = ref.watch(tradeLegsProvider(tradeId));
    return legs.maybeWhen(
      data: (rows) => rows.isEmpty
          ? const SizedBox.shrink()
          : GlossyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Legs'),
                  const SizedBox(height: 12),
                  for (final l in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${(l['action'] as String).toUpperCase()} '
                        '${l['quantity']}× '
                        '${(l['option_type'] as String).toUpperCase()} '
                        '${_num(l['strike'], 0)} '
                        'exp ${l['expiry_date']} '
                        '@ ${_num(l['entry_price'], 2)}'
                        '${l['exit_price'] == null ? '' : ' → ${_num(l['exit_price'], 2)}'}',
                        style: KFonts.data(size: 13),
                      ),
                    ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ---- Underlying ----

class _UnderlyingCard extends StatelessWidget {
  const _UnderlyingCard({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Underlying'),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_line(r), style: KFonts.data(size: 13)),
            ),
        ],
      ),
    );
  }

  // SIDE shares sh @ entry [→ exit|current] — exit wins once landed.
  static String _line(Map<String, dynamic> r) {
    final side = (r['side'] as String? ?? 'long').toUpperCase();
    final close = r['exit_price'] ?? r['current_price'];
    final tail = close == null ? '' : ' → ${_num(close, 2)}';
    return '$side ${r['shares']} sh @ ${_num(r['entry_price'], 2)}$tail';
  }
}

// ---- Photos & greeks history ----

/// Embedded child rows of a trade map (e.g. `trade_photos`, `trade_greeks`),
/// or empty when absent.
List<Map<String, dynamic>> _childRows(Map<String, dynamic> t, String key) {
  final raw = t[key];
  return raw is List
      ? [for (final r in raw) Map<String, dynamic>.from(r as Map)]
      : const [];
}

/// Dated photo gallery — newest first, each shot under its date.
class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.photos});

  final List<Map<String, dynamic>> photos;

  @override
  Widget build(BuildContext context) {
    final sorted = [...photos]
      ..sort((a, b) => ('${b['photo_date']}').compareTo('${a['photo_date']}'));
    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Photos'),
          for (final p in sorted) ...[
            const SizedBox(height: 12),
            Text('${p['photo_date']}',
                style: KFonts.data(
                    size: 12, color: KColors.memberTextSecondary)),
            AttachedPhoto(url: p['image_url'] as String, maxHeight: 360),
          ],
        ],
      ),
    );
  }
}

/// Dated greeks/IV/price snapshots — newest first; one frozen row per day.
class _GreeksHistoryCard extends StatelessWidget {
  const _GreeksHistoryCard({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) =>
          ('${b['snapshot_date']}').compareTo('${a['snapshot_date']}'));
    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Greeks History'),
          const SizedBox(height: 12),
          for (final g in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${g['snapshot_date']}   '
                'Δ ${_num(g['delta'], 2)}   Γ ${_num(g['gamma'], 3)}   '
                'Θ ${_num(g['theta'], 2)}   V ${_num(g['vega'], 2)}   '
                'IV ${_num(g['iv'], 2)}   @ ${_num(g['price'], 2)}',
                style: KFonts.data(size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Discussion ----

class _DiscussionCard extends ConsumerStatefulWidget {
  const _DiscussionCard({required this.tradeId});

  final String tradeId;

  @override
  ConsumerState<_DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends ConsumerState<_DiscussionCard> {
  final _body = TextEditingController();
  bool _isQuestion = false;
  bool _busy = false;
  String? _error;

  Future<void> _post() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('trade_comments').insert({
        'trade_id': widget.tradeId,
        'user_id': supabase.auth.currentUser!.id,
        'body': body,
        'is_question': _isQuestion,
      });
      _body.clear();
      setState(() => _isQuestion = false);
      ref.invalidate(tradeThreadProvider(widget.tradeId));
    } on Exception catch (e) {
      setState(() => _error = 'Could not post: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(tradeThreadProvider(widget.tradeId));
    final tier = ref.watch(memberTierProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final canPost = isAdmin || tier == 'inner_circle';

    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thread.maybeWhen(
            data: (d) {
              if (d.comments.isEmpty) return const _Label('Discussion');
              final q =
                  d.comments.where((c) => c['is_question'] == true).length;
              final c = d.comments.length - q;
              final parts = [
                if (q > 0) '$q question${q == 1 ? '' : 's'}',
                if (c > 0) '$c comment${c == 1 ? '' : 's'}',
              ];
              return _Label('Discussion · ${parts.join(' · ')}');
            },
            orElse: () => const _Label('Discussion'),
          ),
          const SizedBox(height: 8),
          thread.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Text(
              'Could not load the discussion.',
              style: TextStyle(color: KColors.negative, fontSize: 13),
            ),
            data: (d) => d.comments.isEmpty
                ? const Text(
                    'No comments yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: KColors.memberTextSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in d.comments)
                        _CommentTile(
                          key: ValueKey(c['id']),
                          comment: c,
                          username:
                              d.usernames[c['user_id']] ?? 'member',
                          tradeId: widget.tradeId,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          if (canPost) ...[
            Container(
              height: 1,
              decoration: const BoxDecoration(gradient: KGold.hairline),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              maxLines: 4,
              minLines: 1,
              maxLength: 2000,
              style: const TextStyle(fontSize: 14, height: 1.45),
              decoration: const InputDecoration(
                hintText: 'Add a comment or ask K a question…',
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _QuestionChip(
                  selected: _isQuestion,
                  onTap: () => setState(() => _isQuestion = !_isQuestion),
                ),
                const Spacer(),
                FilledButton(
                  style: glossyPrimaryButton().copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    ),
                  ),
                  onPressed: _busy ? null : _post,
                  child: _busy
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Post', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: KColors.negative, fontSize: 12)),
            ],
          ] else
            const Text(
              'Questions and comments are an Inner Circle feature.',
              style: TextStyle(
                fontSize: 12,
                color: KColors.memberTextSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// The question toggle as a quiet pill instead of a full Material switch —
/// gold when armed, hairline when not.
class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? KColors.memberAccent : KColors.memberTextSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0x14C9A84C) : null,
          border: Border.all(
            color: selected ? const Color(0x59C9A84C) : KColors.memberBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              'Question for K',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.username,
    required this.tradeId,
  });

  final Map<String, dynamic> comment;
  final String username;
  final String tradeId;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  /// Non-null while the comment is being edited.
  TextEditingController? _edit;
  bool _busy = false;

  /// Mirrors the RLS author window; the server enforces it regardless.
  static const _authorWindow = Duration(hours: 48);

  Future<void> _saveEdit() async {
    final body = _edit!.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await supabase
          .from('trade_comments')
          .update({'body': body}).eq('id', widget.comment['id'] as String);
      ref.invalidate(tradeThreadProvider(widget.tradeId));
      if (mounted) setState(() => _edit = null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this comment?'),
        content: const Text('It will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: KColors.negative),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await supabase
        .from('trade_comments')
        .delete()
        .eq('id', widget.comment['id'] as String);
    ref.invalidate(tradeThreadProvider(widget.tradeId));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final created = DateTime.tryParse(c['created_at'] as String? ?? '');
    final updated = DateTime.tryParse(c['updated_at'] as String? ?? '');
    final isQuestion = c['is_question'] == true;
    final isAdmin = ref.watch(isAdminProvider);
    final isOwn = c['user_id'] == supabase.auth.currentUser?.id;
    final inWindow = created != null &&
        DateTime.now().toUtc().difference(created.toUtc()) < _authorWindow;
    final canEdit = isOwn && (isAdmin || inWindow);
    final canDelete = isAdmin || (isOwn && inWindow);
    final wasEdited = created != null &&
        updated != null &&
        updated.difference(created).inSeconds > 1;
    final editing = _edit != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '@${widget.username}',
                style: KFonts.data(
                  size: 12,
                  weight: FontWeight.w600,
                  color: KColors.memberAccent,
                ),
              ),
              const SizedBox(width: 8),
              if (isQuestion)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0x14C9A84C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'QUESTION',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: KColors.memberAccent,
                    ),
                  ),
                ),
              if (wasEdited) ...[
                const SizedBox(width: 8),
                const Text(
                  '(edited)',
                  style: TextStyle(
                    fontSize: 11,
                    color: KColors.memberTextSecondary,
                  ),
                ),
              ],
              const Spacer(),
              if (created != null)
                Text(
                  DateFormat('MMM d, h:mm a').format(created.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: KColors.memberTextSecondary,
                  ),
                ),
              if (canEdit && !editing) ...[
                const SizedBox(width: 4),
                _TinyIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit (within 48h)',
                  onTap: () => setState(() {
                    _edit = TextEditingController(text: c['body'] as String);
                  }),
                ),
              ],
              if (canDelete && !editing) ...[
                const SizedBox(width: 4),
                _TinyIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete (within 48h)',
                  onTap: () => _delete(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (editing) ...[
            TextField(
              controller: _edit,
              maxLines: 3,
              minLines: 1,
              maxLength: 2000,
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _edit = null),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _busy ? null : _saveEdit,
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 12, color: KColors.accent),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              c['body'] as String,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: KColors.memberTextSecondary),
        ),
      ),
    );
  }
}

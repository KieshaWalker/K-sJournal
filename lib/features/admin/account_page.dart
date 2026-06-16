import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import 'providers/account_providers.dart';
import 'widgets/form_helpers.dart';

final _money = NumberFormat('#,##0');

String _usd(double v) => '\$${_money.format(v)}';
String _signedUsd(double v) =>
    '${v >= 0 ? '+' : '−'}\$${_money.format(v.abs())}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

Color _pnlColor(double v) => v > 0
    ? KColors.positive
    : v < 0
        ? KColors.negative
        : KColors.neutral;

/// Admin-only ledger view: every account in the book, the aggregate balance
/// and tax posture, and a monthly P&L calendar. The route is admin-guarded
/// and the `accounts` table is admin-only at the database, so a member can
/// neither reach this page nor read the numbers behind it.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(accountBookProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Accounts', style: KFonts.heading(size: 24)),
                  const Spacer(),
                  book.maybeWhen(
                    data: (b) => FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: KColors.accent,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Account'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AccountFormDialog(book: b),
                      ).then((_) => ref.invalidate(accountBookProvider)),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Private to you. Members never see the account names, sizes, '
                'or tax posture.',
                style: TextStyle(
                    fontSize: 12.5, color: KColors.memberTextSecondary),
              ),
              const SizedBox(height: 24),
              book.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Failed to load accounts: $e',
                  style: const TextStyle(color: KColors.negative),
                ),
                data: (b) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(book: b),
                    const SizedBox(height: 20),
                    _AccountsList(book: b),
                    const SizedBox(height: 28),
                    _MovementSection(book: b),
                    const SizedBox(height: 32),
                    _CalendarSection(book: b),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.book});

  final AccountBook book;

  @override
  Widget build(BuildContext context) {
    final b = book;
    final rate = b.tradingAccount?.taxRate ?? 0;

    return GlossyCard(
      hoverLift: false,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('CURRENT BALANCE'),
          const SizedBox(height: 8),
          Text(
            _usd(b.currentBalance),
            style: KFonts.data(size: 36, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${_usd(b.includedStartingTotal)} started  ·  '
            '${_signedUsd(b.realizedPnl)} realized',
            style: const TextStyle(
                fontSize: 13, color: KColors.memberTextSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            height: 1,
            decoration: const BoxDecoration(gradient: KGold.hairline),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 40,
            runSpacing: 22,
            children: [
              _Metric(
                  label: 'Realized P&L',
                  value: _signedUsd(b.realizedPnl),
                  color: _pnlColor(b.realizedPnl)),
              _Metric(
                  label: 'Tax Rate',
                  value: '${(rate * 100).toStringAsFixed(0)}%'),
              _Metric(
                label: 'Tax Reserve',
                value: '−${_usd(b.taxReserve)}',
                color: b.taxReserve > 0 ? KColors.negative : null,
              ),
              _Metric(
                label: 'After-Tax Balance',
                value: _usd(b.afterTaxBalance),
                color: KColors.memberAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            b.tradingAccount == null
                ? 'No trading account is set, so realized P&L is not added to '
                    'any balance.'
                : 'P&L lands in “${b.tradingAccount!.name}”. Reserve is set '
                    'aside against net realized gains; a net loss reserves '
                    'nothing.',
            style: const TextStyle(
                fontSize: 11.5, color: KColors.memberTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _AccountsList extends ConsumerWidget {
  const _AccountsList({required this.book});

  final AccountBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = book.accounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('ALL ACCOUNTS'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < accounts.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    decoration: const BoxDecoration(gradient: KGold.hairline),
                  ),
                _AccountRow(book: book, account: accounts[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.book, required this.account});

  final AccountBook book;
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = account;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        a.name,
                        overflow: TextOverflow.ellipsis,
                        style: KFonts.data(size: 15, weight: FontWeight.w600),
                      ),
                    ),
                    if (a.affectsPnl) ...[
                      const SizedBox(width: 8),
                      const _Tag('TRADING · P&L', color: KColors.memberAccent),
                    ],
                    if (!a.affectsBalance) ...[
                      const SizedBox(width: 8),
                      const _Tag('OFF TOTAL', color: KColors.neutral),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_usd(a.startingBalance)} started'
                  '${a.affectsPnl ? '  ·  holds P&L' : ''}'
                  '  ·  ${(a.taxRate * 100).toStringAsFixed(0)}% tax',
                  style: const TextStyle(
                      fontSize: 12, color: KColors.memberTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _usd(book.balanceOf(a)),
            style: KFonts.data(size: 15, weight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Edit account',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AccountFormDialog(book: book, account: a),
            ).then((_) => ref.invalidate(accountBookProvider)),
          ),
          IconButton(
            tooltip: 'Delete account',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: book.accounts.length <= 1
                ? null
                : () => _confirmDelete(context, ref, a),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Account a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete “${a.name}”?'),
        content: Text(
          a.affectsPnl
              ? 'This is the trading account that holds the realized P&L. '
                  'Deleting it leaves no account holding P&L until you mark '
                  'another. This cannot be undone.'
              : 'This removes the account from the book. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: KColors.negative)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await supabase.from('accounts').delete().eq('id', a.id);
      ref.invalidate(accountBookProvider);
    }
  }
}

// ---- Money movement (deposits, withdrawals, transfers) ----

class _MovementSection extends ConsumerWidget {
  const _MovementSection({required this.book});

  final AccountBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = book.transactions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Label('MONEY MOVEMENT'),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Move Money'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => MoveMoneyDialog(book: book),
              ).then((_) => ref.invalidate(accountBookProvider)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (txns.isEmpty)
          const Text(
            'No deposits, withdrawals, or transfers recorded.',
            style:
                TextStyle(color: KColors.memberTextSecondary, fontSize: 13),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < txns.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      decoration:
                          const BoxDecoration(gradient: KGold.hairline),
                    ),
                  _TxnRow(book: book, txn: txns[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TxnRow extends ConsumerWidget {
  const _TxnRow({required this.book, required this.txn});

  final AccountBook book;
  final AccountTxn txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = txn;
    final (IconData icon, Color color, String title) = switch (t.kind) {
      'deposit' => (
          Icons.south_west,
          KColors.positive,
          'Deposit to ${book.nameOf(t.toAccount)}'
        ),
      'withdrawal' => (
          Icons.north_east,
          KColors.negative,
          'Withdraw from ${book.nameOf(t.fromAccount)}'
        ),
      _ => (
          Icons.swap_horiz,
          KColors.memberAccent,
          '${book.nameOf(t.fromAccount)} → ${book.nameOf(t.toAccount)}'
        ),
    };
    final amountText = switch (t.kind) {
      'deposit' => '+${_usd(t.amount)}',
      'withdrawal' => '−${_usd(t.amount)}',
      _ => _usd(t.amount),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: KFonts.data(size: 13, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  [
                    DateFormat('MMM d, yyyy').format(t.occurredOn),
                    if (t.note != null && t.note!.isNotEmpty) t.note!,
                  ].join('  ·  '),
                  style: const TextStyle(
                      fontSize: 12, color: KColors.memberTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(amountText,
              style: KFonts.data(
                  size: 14, weight: FontWeight.w600, color: color)),
          IconButton(
            tooltip: 'Delete movement',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this movement?'),
        content: const Text(
            'Removing it adjusts the affected balances back. This cannot '
            'be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: KColors.negative)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await supabase.from('account_transactions').delete().eq('id', txn.id);
      ref.invalidate(accountBookProvider);
    }
  }
}

class MoveMoneyDialog extends StatefulWidget {
  const MoveMoneyDialog({super.key, required this.book});

  final AccountBook book;

  @override
  State<MoveMoneyDialog> createState() => _MoveMoneyDialogState();
}

class _MoveMoneyDialogState extends State<MoveMoneyDialog> {
  String _kind = 'transfer';
  String? _from;
  String? _to;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseNum(_amount);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Amount must be greater than zero.');
      return;
    }
    if (_kind == 'deposit' && _to == null) {
      setState(() => _error = 'Choose the account to deposit into.');
      return;
    }
    if (_kind == 'withdrawal' && _from == null) {
      setState(() => _error = 'Choose the account to withdraw from.');
      return;
    }
    if (_kind == 'transfer') {
      if (_from == null || _to == null) {
        setState(() => _error = 'Choose both accounts.');
        return;
      }
      if (_from == _to) {
        setState(() => _error = 'Pick two different accounts.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('account_transactions').insert({
        'kind': _kind,
        'from_account': _kind == 'deposit' ? null : _from,
        'to_account': _kind == 'withdrawal' ? null : _to,
        'amount': amount,
        'occurred_on': DateFormat('yyyy-MM-dd').format(_date),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      setState(() {
        _error = 'Save failed: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final a in widget.book.accounts)
        DropdownMenuItem(value: a.id, child: Text(a.name)),
    ];
    final showFrom = _kind != 'deposit';
    final showTo = _kind != 'withdrawal';

    return FormDialogShell(
      title: 'Move Money',
      submitLabel: 'Record',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'transfer', label: Text('Transfer')),
            ButtonSegment(value: 'withdrawal', label: Text('Withdraw')),
            ButtonSegment(value: 'deposit', label: Text('Deposit')),
          ],
          selected: {_kind},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 16),
        if (showFrom) ...[
          DropdownButtonFormField<String>(
            initialValue: _from,
            decoration: const InputDecoration(labelText: 'From account'),
            items: items,
            onChanged: (v) => setState(() => _from = v),
          ),
          const SizedBox(height: 16),
        ],
        if (showTo) ...[
          DropdownButtonFormField<String>(
            initialValue: _to,
            decoration: const InputDecoration(labelText: 'To account'),
            items: items,
            onChanged: (v) => setState(() => _to = v),
          ),
          const SizedBox(height: 16),
        ],
        NumField(controller: _amount, label: 'Amount'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Date  ·  ${DateFormat('MMM d, yyyy').format(_date)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Note',
            helperText: 'Optional. Only you see this.',
          ),
        ),
      ],
    );
  }
}

// ---- Monthly P&L calendar ----

class _CalendarSection extends ConsumerStatefulWidget {
  const _CalendarSection({required this.book});

  final AccountBook book;

  @override
  ConsumerState<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends ConsumerState<_CalendarSection> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final breakdown = ref.watch(monthlyBreakdownProvider(_year));
    final thisYear = DateTime.now().year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Label('MONTHLY P&L'),
            const Spacer(),
            IconButton(
              tooltip: 'Previous year',
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() => _year -= 1),
            ),
            Text('$_year', style: KFonts.data(size: 15, weight: FontWeight.w600)),
            IconButton(
              tooltip: 'Next year',
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: _year >= thisYear
                  ? null
                  : () => setState(() => _year += 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        breakdown.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Failed to load P&L: $e',
              style: const TextStyle(color: KColors.negative)),
          data: (data) => _CalendarCard(book: widget.book, breakdown: data),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.book, required this.breakdown});

  final AccountBook book;
  final MonthlyBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    // Year-end balance: every included account's starting capital, the P&L
    // realized through this year's end (if the trading account counts toward
    // the total), and the net cash moved in or out by then.
    final yearEndBalance = book.includedStartingTotal +
        (book.pnlCountsTowardBalance ? breakdown.cumulativeThroughYear : 0) +
        book.netTxThrough(DateTime(breakdown.year, 12, 31), includedOnly: true);

    return GlossyCard(
      hoverLift: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            // Three tiles per row on wide cards, two when it gets tight.
            final perRow = constraints.maxWidth < 460 ? 2 : 3;
            final tileWidth =
                (constraints.maxWidth - (perRow - 1) * 12) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var m = 0; m < 12; m++)
                  SizedBox(
                    width: tileWidth,
                    child: _MonthTile(
                        month: _months[m], pnl: breakdown.months[m]),
                  ),
              ],
            );
          }),
          const SizedBox(height: 20),
          Container(
            height: 1,
            decoration: const BoxDecoration(gradient: KGold.hairline),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${breakdown.year} YEAR',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: KColors.memberTextSecondary,
                  )),
              const Spacer(),
              _FooterStat(
                  label: 'P&L',
                  value: _signedUsd(breakdown.yearTotal),
                  color: _pnlColor(breakdown.yearTotal)),
              const SizedBox(width: 28),
              _FooterStat(label: 'Year-End Balance', value: _usd(yearEndBalance)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.month, required this.pnl});

  final String month;
  final double pnl;

  @override
  Widget build(BuildContext context) {
    final has = pnl != 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: has
            ? _pnlColor(pnl).withValues(alpha: 0.06)
            : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1FC9A84C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            month.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: KColors.memberTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            has ? _signedUsd(pnl) : '—',
            style: KFonts.data(
              size: 14,
              weight: FontWeight.w600,
              color: has ? _pnlColor(pnl) : KColors.neutral,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: KColors.memberTextSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(value,
            style:
                KFonts.data(size: 16, weight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ---- Small shared bits ----

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: KColors.memberTextSecondary,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: KColors.memberTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(value,
            style:
                KFonts.data(size: 18, weight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );
  }
}

// ---- Add / edit dialog ----

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({super.key, required this.book, this.account});

  final AccountBook book;

  /// Null for a new account; set when editing an existing one.
  final Account? account;

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _startingBalance = TextEditingController(
      text: (widget.account?.startingBalance ?? 0).toStringAsFixed(2));
  late final _taxRate = TextEditingController(
      text: ((widget.account?.taxRate ?? 0.40) * 100).toStringAsFixed(0));
  late bool _affectsBalance = widget.account?.affectsBalance ?? true;
  late bool _affectsPnl = widget.account?.affectsPnl ?? false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _startingBalance.dispose();
    _taxRate.dispose();
    super.dispose();
  }

  /// The account that currently holds the P&L, if it isn't the one being
  /// edited — used to warn that turning this on will move it.
  Account? get _otherHolder {
    final t = widget.book.tradingAccount;
    if (t == null || t.id == widget.account?.id) return null;
    return t;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final balance = parseNum(_startingBalance);
    final ratePct = parseNum(_taxRate);
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    if (balance == null || balance < 0) {
      setState(() => _error = 'Starting balance must be zero or more.');
      return;
    }
    if (ratePct == null || ratePct < 0 || ratePct > 100) {
      setState(() => _error = 'Tax rate must be between 0 and 100.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Only one account may hold the P&L: clear any current holder before
      // this one claims it, so the single-trading-account index is satisfied.
      if (_affectsPnl) {
        final clear = supabase
            .from('accounts')
            .update({'affects_pnl': false}).eq('affects_pnl', true);
        if (widget.account != null) {
          await clear.neq('id', widget.account!.id);
        } else {
          await clear;
        }
      }
      final data = {
        'name': name,
        'starting_balance': balance,
        'tax_rate': ratePct / 100,
        'affects_balance': _affectsBalance,
        'affects_pnl': _affectsPnl,
      };
      if (widget.account == null) {
        await supabase.from('accounts').insert(data);
      } else {
        await supabase
            .from('accounts')
            .update(data)
            .eq('id', widget.account!.id);
      }
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      setState(() {
        _error = 'Save failed: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final holder = _otherHolder;
    return FormDialogShell(
      title: widget.account == null ? 'Add Account' : 'Edit Account',
      submitLabel: widget.account == null ? 'Add' : 'Save',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: NumField(
                  controller: _startingBalance, label: 'Starting Balance'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: NumField(controller: _taxRate, label: 'Tax Rate (%)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KColors.accent,
          title: const Text('Counts toward total balance',
              style: TextStyle(fontSize: 14)),
          subtitle: const Text(
            'Include this account in the aggregate current balance.',
            style: TextStyle(fontSize: 12),
          ),
          value: _affectsBalance,
          onChanged: (v) => setState(() => _affectsBalance = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KColors.accent,
          title: const Text('Receives trading P&L',
              style: TextStyle(fontSize: 14)),
          subtitle: Text(
            holder == null
                ? 'The realized P&L is added to this account. Only one '
                    'account can hold it.'
                : 'Currently held by “${holder.name}”. Turning this on moves '
                    'it here.',
            style: const TextStyle(fontSize: 12),
          ),
          value: _affectsPnl,
          onChanged: (v) => setState(() => _affectsPnl = v),
        ),
      ],
    );
  }
}

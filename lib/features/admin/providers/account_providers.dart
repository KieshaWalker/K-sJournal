import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

/// One account in K's book. [affectsBalance] decides whether its balance
/// counts toward the aggregate total; [affectsPnl] marks the single trading
/// account the global realized P&L lands in.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.startingBalance,
    required this.taxRate,
    required this.affectsBalance,
    required this.affectsPnl,
  });

  factory Account.fromRow(Map<String, dynamic> r) => Account(
        id: r['id'] as String,
        name: r['name'] as String,
        startingBalance: (r['starting_balance'] as num?)?.toDouble() ?? 0,
        taxRate: (r['tax_rate'] as num?)?.toDouble() ?? 0.40,
        affectsBalance: r['affects_balance'] as bool? ?? true,
        affectsPnl: r['affects_pnl'] as bool? ?? false,
      );

  final String id;
  final String name;
  final double startingBalance;
  final double taxRate;
  final bool affectsBalance;
  final bool affectsPnl;
}

/// A money movement: a deposit into the book, a withdrawal out of it, or a
/// transfer between two accounts. A tracking record whose figures also move
/// the balances.
class AccountTxn {
  const AccountTxn({
    required this.id,
    required this.kind,
    required this.fromAccount,
    required this.toAccount,
    required this.amount,
    required this.occurredOn,
    required this.note,
  });

  factory AccountTxn.fromRow(Map<String, dynamic> r) => AccountTxn(
        id: r['id'] as String,
        kind: r['kind'] as String,
        fromAccount: r['from_account'] as String?,
        toAccount: r['to_account'] as String?,
        amount: (r['amount'] as num?)?.toDouble() ?? 0,
        occurredOn: DateTime.parse(r['occurred_on'] as String),
        note: r['note'] as String?,
      );

  /// 'deposit' | 'withdrawal' | 'transfer'.
  final String kind;
  final String id;
  final String? fromAccount;
  final String? toAccount;
  final double amount;
  final DateTime occurredOn;
  final String? note;
}

/// The whole book: every account, the running realized total, and the cash
/// movements — with the aggregate figures the page leads with. Admin-only —
/// RLS returns no `accounts` rows to anyone else.
class AccountBook {
  const AccountBook({
    required this.accounts,
    required this.realizedPnl,
    required this.transactions,
  });

  final List<Account> accounts;

  /// Net realized P&L across every landed trade.
  final double realizedPnl;

  /// Deposits, withdrawals and transfers, newest first.
  final List<AccountTxn> transactions;

  /// The single account that holds the trading P&L, if one is designated.
  Account? get tradingAccount {
    for (final a in accounts) {
      if (a.affectsPnl) return a;
    }
    return null;
  }

  String nameOf(String? id) {
    if (id == null) return 'Outside';
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return '(deleted)';
  }

  /// Net cash that has flowed into one account: deposits and transfers in,
  /// less withdrawals and transfers out.
  double netTxFor(String accountId) {
    var sum = 0.0;
    for (final t in transactions) {
      if (t.toAccount == accountId) sum += t.amount;
      if (t.fromAccount == accountId) sum -= t.amount;
    }
    return sum;
  }

  /// Net cash flowed into the accounts that count toward the total, up to and
  /// including [end]. Transfers between two counted accounts net to zero;
  /// money leaving the counted set lowers it.
  double netTxThrough(DateTime end, {required bool includedOnly}) {
    final ids = (includedOnly ? accounts.where((a) => a.affectsBalance) : accounts)
        .map((a) => a.id)
        .toSet();
    var sum = 0.0;
    for (final t in transactions) {
      if (t.occurredOn.isAfter(end)) continue;
      if (t.toAccount != null && ids.contains(t.toAccount)) sum += t.amount;
      if (t.fromAccount != null && ids.contains(t.fromAccount)) sum -= t.amount;
    }
    return sum;
  }

  /// An account's balance: its capital, the P&L if it holds it, and the net
  /// of everything moved in or out.
  double balanceOf(Account a) =>
      a.startingBalance + (a.affectsPnl ? realizedPnl : 0) + netTxFor(a.id);

  /// Sum of starting capital across accounts that count toward the total.
  double get includedStartingTotal => accounts
      .where((a) => a.affectsBalance)
      .fold(0.0, (s, a) => s + a.startingBalance);

  /// Net cash movement across the accounts that count toward the total.
  double get includedNetTx => netTxThrough(DateTime(9999), includedOnly: true);

  /// Does the realized P&L reach the aggregate total — i.e. is the trading
  /// account one that also counts toward the balance.
  bool get pnlCountsTowardBalance => tradingAccount?.affectsBalance ?? false;

  /// Aggregate current balance across the accounts that count toward it.
  double get currentBalance =>
      includedStartingTotal +
      (pnlCountsTowardBalance ? realizedPnl : 0) +
      includedNetTx;

  /// Reserve against net realized gains, at the trading account's rate;
  /// nothing owed on a net loss.
  double get taxReserve {
    final rate = tradingAccount?.taxRate ?? 0;
    return realizedPnl > 0 ? realizedPnl * rate : 0;
  }

  double get afterTaxBalance => currentBalance - taxReserve;
}

final accountBookProvider = FutureProvider<AccountBook>((ref) async {
  final rows = await supabase
      .from('accounts')
      .select(
          'id, name, starting_balance, tax_rate, affects_balance, affects_pnl')
      .order('sort_order')
      .order('created_at');

  final landed = await supabase
      .from('trades')
      .select('realized_pnl')
      .eq('status', 'landed');

  final txns = await supabase
      .from('account_transactions')
      .select('id, kind, from_account, to_account, amount, occurred_on, note')
      .order('occurred_on', ascending: false)
      .order('created_at', ascending: false);

  var realized = 0.0;
  for (final r in landed) {
    realized += (r['realized_pnl'] as num?)?.toDouble() ?? 0;
  }

  return AccountBook(
    accounts: [for (final r in rows) Account.fromRow(r)],
    realizedPnl: realized,
    transactions: [for (final t in txns) AccountTxn.fromRow(t)],
  );
});

/// Realized P&L by month for one calendar year, sourced from landed trades'
/// exit date. [months] is 12 entries Jan→Dec; [cumulativeThroughYear] is
/// everything realized up to that year's end, used for the year-end balance.
class MonthlyBreakdown {
  const MonthlyBreakdown({
    required this.year,
    required this.months,
    required this.cumulativeThroughYear,
  });

  final int year;
  final List<double> months;
  final double cumulativeThroughYear;

  double get yearTotal => months.fold(0.0, (s, m) => s + m);
}

final monthlyBreakdownProvider =
    FutureProvider.family<MonthlyBreakdown, int>((ref, year) async {
  final rows = await supabase
      .from('trades')
      .select('realized_pnl, exit_date')
      .eq('status', 'landed');

  final months = List<double>.filled(12, 0);
  var cumulative = 0.0;
  for (final r in rows) {
    final exit = DateTime.tryParse((r['exit_date'] as String?) ?? '');
    if (exit == null) continue;
    final pnl = (r['realized_pnl'] as num?)?.toDouble() ?? 0;
    if (exit.year < year) {
      cumulative += pnl;
    } else if (exit.year == year) {
      months[exit.month - 1] += pnl;
      cumulative += pnl;
    }
  }
  return MonthlyBreakdown(
    year: year,
    months: months,
    cumulativeThroughYear: cumulative,
  );
});

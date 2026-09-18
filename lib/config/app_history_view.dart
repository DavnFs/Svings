import 'package:intl/intl.dart';

import 'package:cause_money_record/data/model/history.dart';

/// One day's slice of the transaction list, with the heading it renders under.
class HistoryDayGroup {
  /// Local midnight of the day these rows belong to.
  final DateTime day;

  /// 'Hari ini', 'Kemarin', or '19 November 2026'.
  final String label;

  final List<History> items;

  const HistoryDayGroup({
    required this.day,
    required this.label,
    required this.items,
  });
}

/// Where a transfer sits relative to the account the list is filtered to.
///
/// [neutral] is the unfiltered view: a transfer is neither a gain nor a loss
/// when both legs are on screen. Once one account is selected the transfer
/// reads from that account's side, because that is the side the user is
/// looking at.
enum TransferLeg { neutral, incoming, outgoing }

/// Presentation rules for the transactions list, kept pure so day boundaries
/// and transfer direction can be tested without rendering anything.
class AppHistoryView {
  AppHistoryView._();

  /// Groups [rows] into day sections, newest day first.
  ///
  /// Inside a day the incoming order is preserved: the ledger stores a date and
  /// no time, so there is nothing more precise to sort a day's rows by, and the
  /// query already returns them newest-first.
  static List<HistoryDayGroup> groupByDay(
    List<History> rows, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final buckets = <DateTime, List<History>>{};
    for (final row in rows) {
      final parsed = DateTime.tryParse(row.date);
      // A date we cannot parse still gets a section instead of vanishing: the
      // user recorded the row, so the row stays visible.
      final day = dayOf(parsed ?? DateTime(1970));
      buckets.putIfAbsent(day, () => []).add(row);
    }
    final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        HistoryDayGroup(
          day: day,
          label: dayLabel(day, today),
          items: buckets[day]!,
        ),
    ];
  }

  /// Local midnight of [value]: the grouping key.
  ///
  /// Local on purpose. Grouping on UTC would push a late-evening transaction
  /// into the next day for a user east of UTC and into the previous day for a
  /// user west of it, which is exactly the boundary this has to get right.
  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Heading for [day] relative to [today]: today and yesterday are named
  /// rather than dated, because those are the two the user is comparing.
  /// Everything older keeps its year, since an entry can be from any year.
  static String dayLabel(DateTime day, DateTime today) {
    if (_isSameDay(day, today)) return 'Hari ini';
    if (_isSameDay(day, DateTime(today.year, today.month, today.day - 1))) {
      return 'Kemarin';
    }
    return DateFormat('d MMMM yyyy', 'id_ID').format(day);
  }

  /// Which way a transfer moves money for the account the list is filtered to.
  ///
  /// Only transfers answer anything but [TransferLeg.neutral]: income and
  /// expense are already unambiguous, and an unfiltered transfer is a wash.
  static TransferLeg transferLeg(History row, String? filterAccountId) {
    if (row.type != 'Transfer' || filterAccountId == null) {
      return TransferLeg.neutral;
    }
    if (row.transferToAccountId == filterAccountId) return TransferLeg.incoming;
    if (row.accountId == filterAccountId) return TransferLeg.outgoing;
    // A transfer between two other accounts is not part of this account's
    // balance, so it reads neutral if it is ever on screen.
    return TransferLeg.neutral;
  }

  /// true when [row] touches [accountId] on either leg. A transfer counts from
  /// both sides: it moves that account's balance, so it belongs in its list.
  static bool touchesAccount(History row, String? accountId) {
    if (accountId == null) return true;
    return row.accountId == accountId || row.transferToAccountId == accountId;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

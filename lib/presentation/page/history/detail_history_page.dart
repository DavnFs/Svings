import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/history/c_detail_history.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

class DetailHistoryPage extends StatefulWidget {
  final String idHistory;

  const DetailHistoryPage({super.key, required this.idHistory});

  @override
  State<DetailHistoryPage> createState() => _DetailHistoryPageState();
}

class _DetailHistoryPageState extends State<DetailHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Transaction Detail')),
      body: _DetailContent(idHistory: widget.idHistory),
    );
  }
}

/// Fetches the transaction then renders [_DetailView].
class _DetailContent extends StatefulWidget {
  final String idHistory;

  const _DetailContent({required this.idHistory});

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  late final CDetailHistory cDetail;

  @override
  void initState() {
    super.initState();
    cDetail = Get.find<CDetailHistory>();
    cDetail.getData(widget.idHistory);
  }

  @override
  Widget build(BuildContext context) {
    return _DetailView(cDetail: cDetail);
  }
}

/// Reactive detail view: loading spinner, then hero + items.
class _DetailView extends StatelessWidget {
  final CDetailHistory cDetail;

  const _DetailView({required this.cDetail});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final d = cDetail.data;
      if (d == null) {
        return const StateView(
          loading: true,
          error: null,
          empty: false,
          child: SizedBox.shrink(),
        );
      }
      final isIncome = d.type == 'Pemasukan';
      final isTransfer = d.type == 'Transfer';
      final items = d.items;
      final status = isTransfer
          ? scheme.primary
          : (isIncome ? scheme.tertiary : scheme.error);
      final accounts = Get.find<CAccounts>();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _HeroCard(
            total: AppFormat.currency(d.total),
            isIncome: isIncome,
            isTransfer: isTransfer,
            status: status,
            date: AppFormat.date(d.date),
            notes: d.notes,
          ),
          // Transfers name both legs; income/expense name their account.
          if (isTransfer)
            _TransferLegs(
              from: accounts.byId(d.accountId)?.name,
              to: accounts.byId(d.transferToAccountId)?.name,
            )
          else if (d.accountId != null)
            _AccountLine(name: accounts.byId(d.accountId)?.name),
          const SizedBox(height: 24),
          Text(
            'Items Breakdown (${items.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _ItemsCard(items: items),
        ],
      );
    });
  }
}

/// Transfer legs: source -> destination. Unknown (deleted) accounts render
/// as '—' rather than crashing.
class _TransferLegs extends StatelessWidget {
  final String? from;
  final String? to;

  const _TransferLegs({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card.outlined(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.swap_horiz_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${from ?? '—'}  →  ${to ?? '—'}',
                  style: TextStyle(fontSize: 14, color: scheme.onSurface)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Owning account line for income/expense.
class _AccountLine extends StatelessWidget {
  final String? name;

  const _AccountLine({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Icon(Icons.account_balance_wallet_outlined,
            size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(name ?? '—',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// Hero summary: status icon, total, type chip, date, notes.
class _HeroCard extends StatelessWidget {
  final String total;
  final bool isIncome;
  final bool isTransfer;
  final Color status;
  final String date;
  final String? notes;

  const _HeroCard({
    required this.total,
    required this.isIncome,
    this.isTransfer = false,
    required this.status,
    required this.date,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isTransfer
                    ? Icons.swap_horiz_rounded
                    : (isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded),
                color: status,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              total,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(isTransfer
                  ? 'Transfer'
                  : (isIncome ? 'Income' : 'Expense')),
              backgroundColor: status.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: status,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (notes != null && notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      notes!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Item rows in one tonal container with inset dividers.
class _ItemsCard extends StatelessWidget {
  final List items;

  const _ItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: scheme.outlineVariant,
          indent: 56,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  AppFormat.currency(num.tryParse(item.price) ?? 0),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

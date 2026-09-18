import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/config/app_motion.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';
import 'package:cause_money_record/presentation/widget/account_icon_view.dart';
import 'package:cause_money_record/presentation/widget/account_widgets.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

/// The home dashboard — the balance carousel, the quick-action row, the weekly
/// bar chart, and the monthly donut. Extracted from the former HomePage so the
/// [MainShell] can host it as the first tab of a shared [FloatingNavBar].
class HomeBody extends StatefulWidget {
  /// Opens the unfiltered transaction list. The aggregate card uses it; an
  /// account card pushes its own filtered list instead. Wired by MainShell so
  /// Home never imports the shell — no import cycle.
  final VoidCallback? onOpenTransactions;

  /// Opens the New Entry form, pre-set to [type] and — when the carousel is on
  /// a specific account rather than the aggregate — to that account. Owned by
  /// MainShell so Home and the FAB open the same form by the same call.
  final void Function(String type, String? accountId)? onQuickAction;

  const HomeBody({super.key, this.onOpenTransactions, this.onQuickAction});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  /// Which account card the carousel is showing, or null for the aggregate.
  /// The quick actions need it to pre-select the account the user is looking at.
  String? _activeAccountId;

  @override
  Widget build(BuildContext context) {
    final cHome = Get.find<CHome>();
    final cAccounts = Get.find<CAccounts>();

    // No fetching here: MainShell._refresh owns both loads (analysis +
    // accounts) so pull-to-refresh and post-save refresh hit both.
    return Obx(() {
      if ((cHome.loading && cHome.today == 0) ||
          (cAccounts.loading && cAccounts.accounts.isEmpty)) {
        return ListView(children: const [
          SizedBox(height: 80),
          StateView(
              loading: true,
              error: null,
              empty: false,
              child: SizedBox.shrink()),
        ]);
      }
      if (cHome.error != null) {
        return ListView(children: [
          const SizedBox(height: 80),
          StateView(
            loading: false,
            error: cHome.error,
            empty: false,
            onRetry: () => cHome.getAnalysis(Get.find<CUser>().id),
            child: const SizedBox.shrink(),
          ),
        ]);
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Balances only. The account list used to sit below the hero as its
          // own "Sumber Dana" section; it is now the rest of this carousel, so
          // Home states each balance once instead of twice.
          _BalanceCarousel(
            cHome: cHome,
            cAccounts: cAccounts,
            onOpenTransactions: widget.onOpenTransactions,
            onAccountChanged: (id) {
              if (id != _activeAccountId) setState(() => _activeAccountId = id);
            },
          ),
          const SizedBox(height: 16),
          _QuickActions(
            onTap: (type) => widget.onQuickAction?.call(type, _activeAccountId),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'This Week'),
          const SizedBox(height: 8),
          _WeeklyChart(cHome: cHome),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'This Month'),
          const SizedBox(height: 8),
          _MonthlySection(cHome: cHome),
        ],
      );
    });
  }
}

/// The three things a money tracker records, one tap away: income, expense,
/// transfer. A shortcut beside the FAB, not a replacement — the FAB still opens
/// the same form with nothing chosen.
///
/// Type icons and colours are the ones the transaction list already uses
/// (south-west in, north-east out, swap for a transfer), so the row reads as
/// the same vocabulary rather than a new one.
class _QuickActions extends StatelessWidget {
  final void Function(String type) onTap;

  const _QuickActions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _QuickActionButton(
              key: const Key('quick_action_income'),
              icon: Icons.south_west_rounded,
              color: scheme.tertiary,
              label: 'Pemasukan',
              onTap: () => onTap('Pemasukan'),
            ),
            _QuickActionButton(
              key: const Key('quick_action_expense'),
              icon: Icons.north_east_rounded,
              color: scheme.error,
              label: 'Pengeluaran',
              onTap: () => onTap('Pengeluaran'),
            ),
            _QuickActionButton(
              key: const Key('quick_action_transfer'),
              icon: Icons.swap_horiz_rounded,
              color: scheme.primary,
              label: 'Transfer',
              onTap: () => onTap('Transfer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One action: icon over label, an equal third of the row.
///
/// Spacing separates the three rather than dividers: against the dark tonal
/// surface a hairline between them reads as a table cell, while the icons and
/// the ripple already say where one target ends and the next begins.
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          // A minimum, not a height: 56dp is what the cell wants at default
          // text size, and at larger accessibility sizes the row grows with the
          // label instead of overflowing the way a fixed box did.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// DESIGN.md section header: 18sp w700.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
    );
  }
}

/// Card identity, so a test can tell the two kinds apart while the carousel is
/// peeking its neighbour into view.
const _aggregateCardKey = Key('carousel_card_aggregate');
Key _accountCardKey(String id) => Key('carousel_card_$id');

/// Swipeable balance cards: the aggregate first, then one card per account.
///
/// The cards carry their own titles. A separate "Total Balance" header over the
/// carousel would be wrong the moment it is swiped to an account, and a label
/// that travels with its card is what makes a swipeable strip readable.
///
/// Height is fixed because a PageView needs bounded height inside the page's
/// scroll; the horizontal drag is claimed by the PageView and vertical drags
/// fall through to the list, which is the platform's standard arena behaviour.
class _BalanceCarousel extends StatefulWidget {
  final CHome cHome;
  final CAccounts cAccounts;
  final VoidCallback? onOpenTransactions;

  /// Fires with the account id of the card in view, or null for the aggregate.
  final ValueChanged<String?>? onAccountChanged;

  const _BalanceCarousel({
    required this.cHome,
    required this.cAccounts,
    this.onOpenTransactions,
    this.onAccountChanged,
  });

  /// Tall enough for the tallest card (aggregate: title, amount, today line and
  /// the details button) at default text size.
  ///
  /// A PageView needs a bounded height inside the page's scroll, so the card
  /// cannot simply be intrinsic — but a title, an amount, a wrapped today line
  /// and a button do not fit in 196dp once the user's text size grows either.
  /// The height therefore follows the text scale up to [_maxGrowth]; past that
  /// the cards would take over the screen, and the lines inside ellipsise.
  static const baseHeight = 196.0;
  static const _maxGrowth = 1.8;

  @override
  State<_BalanceCarousel> createState() => _BalanceCarouselState();
}

class _BalanceCarouselState extends State<_BalanceCarousel> {
  final _controller = PageController(viewportFraction: 0.93);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final accounts = widget.cAccounts.accounts;
      final count = accounts.length + 1;
      // Accounts can disappear under the carousel (deleted in Wallet); keep the
      // active page inside the strip that exists now.
      final active = _page.clamp(0, count - 1);
      final growth =
          MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, _BalanceCarousel._maxGrowth);
      return Column(children: [
        SizedBox(
          height: _BalanceCarousel.baseHeight * growth,
          child: PageView(
            controller: _controller,
            // Snap instead of spring when the platform asked for reduced motion.
            physics: AppMotion.carousel(context),
            onPageChanged: (i) {
              setState(() => _page = i);
              // Page 0 is the aggregate, so it reports "no account".
              final accounts = widget.cAccounts.accounts;
              final id =
                  i > 0 && i <= accounts.length ? accounts[i - 1].id : null;
              widget.onAccountChanged?.call(id);
            },
            children: [
              _AggregateCard(
                key: _aggregateCardKey,
                cHome: widget.cHome,
                onTap: widget.onOpenTransactions,
              ),
              for (final account in accounts)
                _AccountCard(
                  key: _accountCardKey(account.id),
                  cHome: widget.cHome,
                  cAccounts: widget.cAccounts,
                  account: account,
                ),
            ],
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 12),
          _PageDots(count: count, active: active),
        ],
      ]);
    });
  }
}

/// Page 0: every account summed, plus today's spend across all of them.
class _AggregateCard extends StatelessWidget {
  final CHome cHome;
  final VoidCallback? onTap;

  const _AggregateCard({super.key, required this.cHome, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _CardShell(
      color: scheme.primaryContainer,
      onTap: onTap,
      // The carousel's height is fixed (a PageView needs bounded height inside
      // the page's scroll), so every text line here yields to the layout: at
      // large accessibility sizes the lines shrink or ellipsise rather than
      // overflowing the card.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text('Total Balance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.9))),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: _Amount(
              valueOf: () => cHome.totalBalance,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Obx(() => Text(
                  'Spent today: ${AppFormat.currency(cHome.today)} (${cHome.todayPercent})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                      fontSize: 13),
                )),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Obx(() {
              final todayId = cHome.todayId;
              if (todayId == null) return const SizedBox.shrink();
              return FilledButton.tonalIcon(
                onPressed: () =>
                    Get.to(() => DetailHistoryPage(idHistory: todayId)),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View Details', maxLines: 1),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// One account's own card: its mark, its name, its balance, and its own
/// today-spend — the same figure as the aggregate card, scoped to this account.
class _AccountCard extends StatelessWidget {
  final CHome cHome;
  final CAccounts cAccounts;
  final Account account;

  const _AccountCard({
    super.key,
    required this.cHome,
    required this.cAccounts,
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = CAccounts.parseColor(account.color);
    return _CardShell(
      color: tint.withValues(alpha: 0.20),
      onTap: () => Get.to(() => AccountTransactionsPage(account: account)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AccountIconView(
                  icon: account.icon, colorHex: account.color, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: Text(account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Read through the Accounts map, not a value captured by the parent:
          // the card then follows the balance itself, and the Obx inside always
          // has an observable to register (see _Amount).
          Flexible(
            child: _Amount(
              valueOf: () => cAccounts.balanceOf(account.id),
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Obx(() => Text(
                  'Spent today: ${AppFormat.currency(cHome.todaySpendOf(account.id))}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                )),
          ),
        ],
      ),
    );
  }
}

/// Shared card chrome: the page inset, the rounded tonal surface and the tap
/// target, so both card kinds look and behave the same.
class _CardShell extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;
  final Widget child;

  const _CardShell({required this.color, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: color,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

/// The balance figure. Centred like the rest of the card, tabular so it does
/// not jitter as digits change, and shrink-only so a long balance stays inside
/// the card instead of overflowing it.
///
/// [valueOf] must read an observable (a controller getter or the balances map):
/// it is called inside the Obx, and that read is what registers the rebuild.
/// Passing a plain value throws GetX's "improper use" at build time.
class _Amount extends StatelessWidget {
  final double Function() valueOf;
  final Color color;

  const _Amount({required this.valueOf, required this.color});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          AppFormat.currency(valueOf()),
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    });
  }
}

/// Which card is showing. The active dot is a wide pill, so position is legible
/// without counting.
class _PageDots extends StatelessWidget {
  final int count;
  final int active;

  const _PageDots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            key: Key('carousel_dot_$i'),
            // The pill widens to mark the active card; with reduced motion it is
            // simply already the right width.
            duration: AppMotion.maybe(context, const Duration(milliseconds: 200)),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Weekly bars inside a tonal card. Aggregate-only this pass: per-account
/// chart filtering would thread an accountId through c_home.analysis +
/// SourceHistory.analysis for one dropdown — noted as follow-up, not built.
class _WeeklyChart extends StatelessWidget {
  final CHome cHome;

  const _WeeklyChart({required this.cHome});

  /// Short axis label: full integers overflow 1/7 of the card width (a 5-digit
  /// total like 19570 needs ~30dp in a ~44dp cell), and the overflow rendered
  /// as a wrapped fragment that looked like a stray "/" ("195/0"). Compact
  /// form keeps every label on one line: 19570 -> "19,6rb".
  static String _compactValue(double v) {
    if (v >= 1000000) {
      final s = (v / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return '${s}jt';
    }
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '${s}rb';
    }
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final data = cHome.week;
          final labels = cHome.weekText();
          final maxVal = data.reduce(max).clamp(1.0, double.infinity);
          final hasData = data.any((v) => v > 0);
          if (!hasData) {
            // 200, not 160: StateView's empty state is ~145dp of icon, title and
            // message, and 160 leaves it 112 after its own padding, which
            // overflows on every account with no week data yet.
            return const SizedBox(
              height: 200,
              child: StateView(
                loading: false,
                error: null,
                empty: true,
                emptyTitle: 'Belum ada data minggu ini',
                emptyMessage:
                    'Catat transaksi pertama Anda untuk melihat grafik',
                emptyIcon: Icons.bar_chart_outlined,
                child: SizedBox.shrink(),
              ),
            );
          }
          return SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final ratio = data[i] / maxVal;
                return Expanded(
                  // Tight cells: 7 columns share the card width, so each keeps
                  // only 2dp gutters — 4dp each side clipped the last bar.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (data[i] > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _compactValue(data[i]),
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 9, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        const SizedBox(height: 4),
                        // The bar takes whatever height the labels leave, as a
                        // fraction of it, instead of a fixed 120dp. That fixed
                        // number is what overflowed the 160dp cell once the
                        // labels grew with the user's text size.
                        Flexible(
                          fit: FlexFit.tight,
                          child: FractionallySizedBox(
                            heightFactor: ratio.clamp(0.03, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const SizedBox(width: double.infinity),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(labels[i],
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 10, color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

/// Monthly donut + ledger inside a tonal card.
class _MonthlySection extends StatelessWidget {
  final CHome cHome;

  const _MonthlySection({required this.cHome});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          if (cHome.monthIncome == 0 && cHome.monthOutcome == 0) {
            return const SizedBox(
              height: 200,
              child: StateView(
                loading: false,
                error: null,
                empty: true,
                emptyTitle: 'Belum ada transaksi bulan ini',
                emptyMessage:
                    'Tambah Pemasukan atau Pengeluaran untuk mulai melacak',
                emptyIcon: Icons.pie_chart_outline,
                child: SizedBox.shrink(),
              ),
            );
          }
          return Column(children: [
            Row(children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _DonutPainter(
                      income: cHome.monthIncome,
                      outcome: cHome.monthOutcome,
                      incomeColor: scheme.tertiary,
                      outcomeColor: scheme.error,
                      emptyColor: scheme.outlineVariant,
                    ),
                  ),
                  Center(
                    child: Text('${cHome.percentIncome}%',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface)),
                  ),
                ]),
              ),
              const SizedBox(width: 24),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _LegendItem(color: scheme.tertiary, label: 'Income'),
                    const SizedBox(height: 8),
                    _LegendItem(color: scheme.error, label: 'Expense'),
                    const SizedBox(height: 16),
                    Text(cHome.monthPercent,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            height: 1.4)),
                  ])),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(
                  child: Text('Difference',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(AppFormat.currency(cHome.differentMonth),
                        maxLines: 1,
                        style: TextStyle(
                            color: scheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}

/// Swatch + label for the donut legend.
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final double income;
  final double outcome;
  final Color incomeColor;
  final Color outcomeColor;
  final Color emptyColor;

  _DonutPainter(
      {required this.income,
      required this.outcome,
      required this.incomeColor,
      required this.outcomeColor,
      required this.emptyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final total = income + outcome;
    if (total == 0) {
      paint.color = emptyColor;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final incomeAngle = (income / total) * 2 * pi;
    final outcomeAngle = (outcome / total) * 2 * pi;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    paint.color = incomeColor;
    canvas.drawArc(rect, -pi / 2, incomeAngle, false, paint);
    paint.color = outcomeColor;
    canvas.drawArc(rect, -pi / 2 + incomeAngle, outcomeAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.income != income ||
      oldDelegate.outcome != outcome ||
      oldDelegate.incomeColor != incomeColor ||
      oldDelegate.outcomeColor != outcomeColor ||
      oldDelegate.emptyColor != emptyColor;
}

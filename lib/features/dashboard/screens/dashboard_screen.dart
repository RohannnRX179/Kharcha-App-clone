import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/category_visuals.dart';
import '../../../core/money/money.dart';
import '../../../core/time/app_time.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/recurring_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/models/budget.dart' as domain;
import '../../../domain/models/budget_status.dart';
import '../../../domain/models/category.dart' as domain;
import '../../../domain/models/enums.dart';
import '../../../domain/models/expense.dart' as domain;
import '../../../domain/models/expense_filter.dart';
import '../../../domain/models/profile.dart' as domain;
import '../../../domain/models/recurring_rule.dart' as domain;
import '../../../domain/models/report.dart';
import '../../../routing/routes.dart';
import '../../expenses/controllers/expense_list_preset_filter_controller.dart';
import '../controllers/selected_month_controller.dart';
import '../widgets/feedback_prompt_banner.dart';
import '../widgets/month_selector.dart';
import '../widgets/section_card.dart';
import '../widgets/update_banner.dart';

/// Household + per-member monthly totals (spec §11.4, T-6.1..T-6.5, T-8.4,
/// T-9.5). Ships cards 1-6. Card 7 (the sync/offline banner) is already
/// rendered above every tab by [AppShell]. The in-app update banner (spec
/// §11.14, T-14.6) sits above every card, per that spec section's own
/// wording ("a dismissible banner on the Dashboard").
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthControllerProvider);
    // Spec D20/T-M2.10: a household of one is a first-class case, not a
    // degraded family — comparing a solo user to themselves is noise, so
    // the per-member breakdown card is hidden entirely rather than shown
    // with nothing to compare against.
    final isSolo =
        (ref.watch(householdProfilesProvider).value?.length ?? 0) <= 1;

    return Scaffold(
      appBar: AppBar(title: MonthSelector(month: month)),
      body: RefreshIndicator(
        color: AppColors.neonMint,
        backgroundColor: AppColors.surfaceRaised,
        onRefresh: () => ref.read(syncEngineProvider).sync(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            const UpdateBanner(),
            const FeedbackPromptBanner(),
            _HouseholdSummaryCard(monthStart: month),
            const SizedBox(height: 14),
            _BudgetProgressCard(monthStart: month),
            const SizedBox(height: 14),
            const _PendingRecurringCard(),
            if (!isSolo) ...[
              const SizedBox(height: 14),
              _MemberBreakdownCard(monthStart: month),
            ],
            const SizedBox(height: 14),
            _TopCategoriesCard(monthStart: month),
            const SizedBox(height: 14),
            const _RecentActivityCard(),
          ],
        ),
      ),
    );
  }
}

/// Card 6 (spec §11.8, T-9.5): every rule with `auto_post = false` that is
/// currently due (`RecurringDao.dueOn`, same live stream the list screen
/// reads), each with Post/Skip. Absent entirely when nothing is pending,
/// same "no cards for empty state" precedent as the budget card.
class _PendingRecurringCard extends ConsumerWidget {
  const _PendingRecurringCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(householdRecurringRulesProvider);
    final rules = rulesAsync.value ?? const <domain.RecurringRule>[];
    final today = AppTime.calendarDate(DateTime.now().toUtc());
    final pending =
        rules
            .where(
              (r) => r.isActive && !r.autoPost && !r.nextDueDate.isAfter(today),
            )
            .toList()
          ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    if (pending.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Pending confirmations',
      accentColor: AppColors.neonAmber,
      onSeeAll: () => context.push(AppRoutes.recurring),
      child: Column(
        children: [
          for (final rule in pending) _PendingRecurringRow(rule: rule),
        ],
      ),
    );
  }
}

class _PendingRecurringRow extends ConsumerStatefulWidget {
  const _PendingRecurringRow({required this.rule});
  final domain.RecurringRule rule;

  @override
  ConsumerState<_PendingRecurringRow> createState() =>
      _PendingRecurringRowState();
}

class _PendingRecurringRowState extends ConsumerState<_PendingRecurringRow> {
  bool _busy = false;

  Future<void> _act(Future<void> Function(String) action) async {
    setState(() => _busy = true);
    await action(widget.rule.id);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(recurringRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.rule.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.rule.amount.format(),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            TextButton(
              onPressed: () => _act(repo.skipPending),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              child: const Text('Skip'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => _act(repo.postPending),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Post'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card 1 (spec §11.4): total spent, total income, net saved, and a %
/// change in spend vs the previous month.
class _HouseholdSummaryCard extends ConsumerWidget {
  const _HouseholdSummaryCard({required this.monthStart});
  final DateTime monthStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(reportRepositoryProvider);
    final householdId = ref.watch(currentHouseholdIdProvider) ?? '';
    final previousMonth = AppTime.monthAfter(monthStart, -1);

    return SectionCard(
      title: 'This month',
      child: StreamBuilder<int>(
        stream: repo.watchExpenseTotal(
          householdId: householdId,
          monthStart: monthStart,
        ),
        builder: (context, expenseSnap) {
          final expenseTotal = expenseSnap.data ?? 0;
          return StreamBuilder<int>(
            stream: repo.watchIncomeTotal(
              householdId: householdId,
              monthStart: monthStart,
            ),
            builder: (context, incomeSnap) {
              final incomeTotal = incomeSnap.data ?? 0;
              return StreamBuilder<int>(
                stream: repo.watchExpenseTotal(
                  householdId: householdId,
                  monthStart: previousMonth,
                ),
                builder: (context, prevSnap) {
                  final previousTotal = prevSnap.data ?? 0;
                  return _SummaryBody(
                    expenseTotal: expenseTotal,
                    incomeTotal: incomeTotal,
                    previousExpenseTotal: previousTotal,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.expenseTotal,
    required this.incomeTotal,
    required this.previousExpenseTotal,
  });

  final int expenseTotal;
  final int incomeTotal;
  final int previousExpenseTotal;

  @override
  Widget build(BuildContext context) {
    final net = Money(incomeTotal - expenseTotal);
    // No previous-month spend to compare against — omit the change row
    // rather than divide by zero (spec T-6.5).
    final double? changePct = previousExpenseTotal == 0
        ? null
        : ((expenseTotal - previousExpenseTotal) / previousExpenseTotal) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(
          label: 'Spent',
          value: Money(expenseTotal).format(),
          icon: Icons.arrow_upward_rounded,
          iconColor: AppColors.danger,
        ),
        const SizedBox(height: 6),
        _SummaryRow(
          label: 'Income',
          value: Money(incomeTotal).format(),
          icon: Icons.arrow_downward_rounded,
          iconColor: AppColors.neonMint,
          onTap: () => context.push(AppRoutes.income),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        _SummaryRow(
          label: 'Net saved',
          value: net.format(),
          valueColor: net.isNegative ? AppColors.danger : AppColors.neonMint,
          isBold: true,
        ),
        if (changePct != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (changePct >= 0 ? AppColors.danger : AppColors.neonMint)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  changePct >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 16,
                  color: changePct >= 0 ? AppColors.danger : AppColors.neonMint,
                ),
                const SizedBox(width: 6),
                Text(
                  '${changePct.abs().toStringAsFixed(0)}% vs last month',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: changePct >= 0
                        ? AppColors.danger
                        : AppColors.neonMint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.icon,
    this.iconColor,
    this.isBold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.textMuted).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Card 2 (spec §11.4/§11.7, T-8.4): each of this month's budgets, showing
/// spent, remaining, days left, and the daily allowance the remainder
/// works out to. Absent entirely when there are no budgets for the month
/// (nothing to show, and no "create one?" nag per §0 rule 4).
class _BudgetProgressCard extends ConsumerWidget {
  const _BudgetProgressCard({required this.monthStart});
  final DateTime monthStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsForMonthProvider(monthStart));
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // allKnownProfilesProvider: a budget assigned to a since-departed member
    // should still show their name. See docs/DECISIONS.md, "Profiles-
    // tombstone gap".
    final profiles = ref.watch(allKnownProfilesProvider).value ?? const [];
    final categoriesById = {for (final c in categories) c.id: c};
    final profilesById = {for (final p in profiles) p.id: p};

    final budgets = budgetsAsync.value ?? const <domain.Budget>[];
    if (budgets.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Budgets',
      accentColor: AppColors.neonPurple,
      onSeeAll: () => context.push(AppRoutes.budgets),
      child: Column(
        children: [
          for (final budget in budgets)
            _BudgetProgressRow(
              budget: budget,
              category: categoriesById[budget.categoryId],
              member: profilesById[budget.userId],
            ),
        ],
      ),
    );
  }
}

class _BudgetProgressRow extends ConsumerWidget {
  const _BudgetProgressRow({
    required this.budget,
    required this.category,
    required this.member,
  });

  final domain.Budget budget;
  final domain.Category? category;
  final domain.Profile? member;

  String get _label => switch (budget.scope) {
    BudgetScope.household => 'Household',
    BudgetScope.user => member?.displayName ?? 'Member',
    BudgetScope.category => category?.name ?? 'Category',
    BudgetScope.userCategory =>
      '${member?.displayName ?? 'Member'} · ${category?.name ?? 'Category'}',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<BudgetStatus>(
      stream: ref.watch(budgetRepositoryProvider).watchStatus(budget),
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) return const SizedBox.shrink();
        final daysLeft = AppTime.daysRemainingInMonth(budget.periodMonth);
        final dailyAllowance = daysLeft > 0
            ? Money((status.remainingPaise / daysLeft).round())
            : Money.zero;
        final colour = switch (status.health) {
          BudgetHealth.ok => AppColors.neonMint,
          BudgetHealth.warning => AppColors.neonAmber,
          BudgetHealth.exceeded => AppColors.danger,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${status.spent.format()} / ${status.effectiveBudget.format()}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _NeonProgressBar(
                value: status.pct.clamp(0, 1).toDouble(),
                color: colour,
              ),
              const SizedBox(height: 6),
              Text(
                status.health == BudgetHealth.exceeded
                    ? 'Exceeded by ${Money(status.overspendPaise).format()}'
                    : '${status.remaining.format()} left · ${dailyAllowance.format()}/day '
                          'for $daysLeft day${daysLeft == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colour),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A styled progress bar with rounded ends and subtle glow.
class _NeonProgressBar extends StatelessWidget {
  const _NeonProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card 3 (spec §11.4): horizontal bars, sorted descending, tap to filter
/// the Expense List to that member.
class _MemberBreakdownCard extends ConsumerWidget {
  const _MemberBreakdownCard({required this.monthStart});
  final DateTime monthStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(reportRepositoryProvider);
    final householdId = ref.watch(currentHouseholdIdProvider) ?? '';
    // allKnownProfilesProvider: a departed member's spend earlier this
    // month should still attribute to their name, not "Unknown". See
    // docs/DECISIONS.md, "Profiles-tombstone gap".
    final profiles = ref.watch(allKnownProfilesProvider).value ?? const [];
    final profilesById = {for (final p in profiles) p.id: p};

    return SectionCard(
      title: 'Per member',
      accentColor: AppColors.neonCyan,
      child: StreamBuilder<List<GroupedTotal>>(
        stream: repo.watchExpenseByMember(
          householdId: householdId,
          monthStart: monthStart,
        ),
        builder: (context, snapshot) {
          final totals = snapshot.data ?? const [];
          if (totals.isEmpty) {
            return const EmptySectionBody(
              message: 'No expenses logged this month yet.',
            );
          }
          final householdTotal = totals.fold(
            0,
            (sum, g) => sum + g.amountPaise,
          );
          return Column(
            children: [
              for (final group in totals)
                _MemberBar(
                  profile: profilesById[group.key],
                  amountPaise: group.amountPaise,
                  fraction: householdTotal == 0
                      ? 0
                      : group.amountPaise / householdTotal,
                  onTap: () => _filterExpensesToMember(
                    context,
                    ref,
                    group.key,
                    monthStart,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

void _filterExpensesToMember(
  BuildContext context,
  WidgetRef ref,
  String userId,
  DateTime monthStart,
) {
  final monthEnd = AppTime.monthAfter(
    monthStart,
    1,
  ).subtract(const Duration(days: 1));
  ref
      .read(expenseListPresetFilterControllerProvider.notifier)
      .set(
        ExpenseFilter(
          startDate: monthStart,
          endDate: monthEnd,
          memberIds: [userId],
        ),
      );
  context.go(AppRoutes.expenses);
}

class _MemberBar extends StatelessWidget {
  const _MemberBar({
    required this.profile,
    required this.amountPaise,
    required this.fraction,
    required this.onTap,
  });

  final domain.Profile? profile;
  final int amountPaise;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final barColor = profile == null
        ? AppColors.neonMint
        : colourFromHex(profile!.colourHex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  profile?.displayName ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Text(
                      Money(amountPaise).format(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(fraction * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            _NeonProgressBar(
              value: fraction.clamp(0, 1).toDouble(),
              color: barColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card 4 (spec §11.4): top 5 categories by spend, with a "See all" link to
/// Analytics.
class _TopCategoriesCard extends ConsumerWidget {
  const _TopCategoriesCard({required this.monthStart});
  final DateTime monthStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(reportRepositoryProvider);
    final householdId = ref.watch(currentHouseholdIdProvider) ?? '';
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoriesById = {for (final c in categories) c.id: c};

    return SectionCard(
      title: 'Top categories',
      accentColor: AppColors.neonPink,
      onSeeAll: () => context.go(AppRoutes.analytics),
      child: StreamBuilder<int>(
        stream: repo.watchExpenseTotal(
          householdId: householdId,
          monthStart: monthStart,
        ),
        builder: (context, totalSnap) {
          final householdTotal = totalSnap.data ?? 0;
          return StreamBuilder<List<GroupedTotal>>(
            stream: repo.watchTopCategories(
              householdId: householdId,
              monthStart: monthStart,
            ),
            builder: (context, snapshot) {
              final totals = snapshot.data ?? const [];
              if (totals.isEmpty) {
                return const EmptySectionBody(
                  message: 'No categorised expenses this month yet.',
                );
              }
              return Column(
                children: [
                  for (final group in totals)
                    _CategoryRow(
                      category: categoriesById[group.key],
                      amountPaise: group.amountPaise,
                      percent: householdTotal == 0
                          ? 0
                          : group.amountPaise / householdTotal * 100,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amountPaise,
    required this.percent,
  });

  final domain.Category? category;
  final int amountPaise;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final catColor = category == null
        ? Colors.grey
        : colourFromHex(category!.colourHex);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              category == null ? Icons.category : iconForKey(category!.iconKey),
              size: 18,
              color: catColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category?.name ?? 'Uncategorised',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${percent.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: catColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            Money(amountPaise).format(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Card 5 (spec §11.4): the household's last 5 expenses, most recent first.
class _RecentActivityCard extends ConsumerWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(reportRepositoryProvider);
    final householdId = ref.watch(currentHouseholdIdProvider) ?? '';
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // allKnownProfilesProvider: a departed member's recent expense should
    // still attribute to their name, not "Unknown". See
    // docs/DECISIONS.md, "Profiles-tombstone gap".
    final profiles = ref.watch(allKnownProfilesProvider).value ?? const [];
    final categoriesById = {for (final c in categories) c.id: c};
    final profilesById = {for (final p in profiles) p.id: p};

    return SectionCard(
      title: 'Recent activity',
      child: StreamBuilder<List<domain.Expense>>(
        stream: repo.watchRecentExpenses(householdId: householdId),
        builder: (context, snapshot) {
          final recent = snapshot.data ?? const [];
          if (recent.isEmpty) {
            return const EmptySectionBody(message: 'No expenses logged yet.');
          }
          return Column(
            children: [
              for (final expense in recent)
                _RecentExpenseRow(
                  expense: expense,
                  category: categoriesById[expense.categoryId],
                  payer: profilesById[expense.userId],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentExpenseRow extends StatelessWidget {
  const _RecentExpenseRow({
    required this.expense,
    required this.category,
    required this.payer,
  });

  final domain.Expense expense;
  final domain.Category? category;
  final domain.Profile? payer;

  @override
  Widget build(BuildContext context) {
    final title = expense.note.isNotEmpty
        ? expense.note
        : (category?.name ?? 'Uncategorised');
    final catColor = category == null
        ? Colors.grey
        : colourFromHex(category!.colourHex);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => context.push(AppRoutes.expenseDetailPath(expense.id)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            category == null ? Icons.category : iconForKey(category!.iconKey),
            color: catColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: payer == null
            ? null
            : Text(
                payer!.displayName,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
        trailing: Text(
          expense.amount.format(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_time.dart';
import '../controllers/selected_month_controller.dart';

/// The month stepper + year/month-grid picker shared by the Dashboard and
/// Analytics (spec §11.10: "Month/range selector shared with the
/// Dashboard") — both read and write the same [selectedMonthControllerProvider]
/// so switching tabs keeps the same selected month.
class MonthSelector extends ConsumerWidget {
  const MonthSelector({required this.month, super.key});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(selectedMonthControllerProvider.notifier);
    final isCurrentMonth = AppTime.isSameIstMonth(
      month,
      DateTime.now().toUtc(),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavButton(
          icon: Icons.chevron_left_rounded,
          onPressed: controller.previousMonth,
          tooltip: 'Previous month',
        ),
        Expanded(
          child: TextButton(
            onPressed: () async {
              final picked = await showDialog<DateTime>(
                context: context,
                builder: (context) => _MonthYearPickerDialog(initial: month),
              );
              if (picked != null) controller.setMonth(picked);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.text,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            child: Text(AppTime.monthLabel(month)),
          ),
        ),
        _NavButton(
          icon: Icons.chevron_right_rounded,
          onPressed: isCurrentMonth ? null : controller.nextMonth,
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: onPressed != null ? AppColors.surfaceBright : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        color: onPressed != null ? AppColors.text : AppColors.textSubtle,
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({required this.initial});
  final DateTime initial;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final canGoForward = _year < AppTime.nowIst().year;
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onPressed: () => setState(() => _year--),
            tooltip: 'Previous year',
          ),
          Text(
            '$_year',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onPressed: canGoForward ? () => setState(() => _year++) : null,
            tooltip: 'Next year',
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 2,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var m = 1; m <= 12; m++) _MonthCell(year: _year, month: m),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.year, required this.month});
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final value = DateTime.utc(year, month);
    final disabled = AppTime.isFutureMonth(value);
    final isCurrent = AppTime.isSameIstMonth(value, DateTime.now().toUtc());
    return Container(
      decoration: isCurrent
          ? BoxDecoration(
              color: AppColors.neonMint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.neonMint.withValues(alpha: 0.3),
              ),
            )
          : null,
      child: TextButton(
        onPressed: disabled ? null : () => Navigator.of(context).pop(value),
        style: TextButton.styleFrom(
          foregroundColor: isCurrent ? AppColors.neonMint : AppColors.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          AppTime.monthLabelShort(value).split(' ').first,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

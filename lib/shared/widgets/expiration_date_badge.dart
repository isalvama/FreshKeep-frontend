import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// e.g. `12 Nov 2026`.
String formatExpirationDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

enum ExpirationUrgency {
  /// Today or earlier.
  expired,

  /// Within the next 7 days.
  soon,
  later,
}

/// How close [date] is to [today], comparing calendar days only.
ExpirationUrgency expirationUrgency(DateTime date, DateTime today) {
  final days = DateUtils.dateOnly(
    date,
  ).difference(DateUtils.dateOnly(today)).inDays;
  if (days <= 0) return ExpirationUrgency.expired;
  if (days <= 7) return ExpirationUrgency.soon;
  return ExpirationUrgency.later;
}

/// A product's expiration date in a rounded box: red when it is today or
/// past, yellow when it is within the next 7 days.
class ExpirationDateBadge extends StatelessWidget {
  const ExpirationDateBadge({super.key, required this.date, this.today});

  final DateTime date;

  /// Defaults to now; set in tests.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (expirationUrgency(
      date,
      today ?? DateTime.now(),
    )) {
      ExpirationUrgency.expired => (AppColors.expiredLight, AppColors.error),
      ExpirationUrgency.soon => (
        AppColors.expiringSoonLight,
        AppColors.expiringSoon,
      ),
      ExpirationUrgency.later => (AppColors.outlineLight, AppColors.brownDark),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        formatExpirationDate(date),
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

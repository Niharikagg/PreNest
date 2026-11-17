// FROZEN: changes need approval from every team member
class TrendSummary {
  const TrendSummary({
    required this.count,
    this.firstValue,
    this.latestValue,
    this.change,
    this.changePercent,
    this.positionInRange,
    required this.labelKey,
    required this.canCompare,
    this.reason,
  });

  final int count;
  final double? firstValue;
  final double? latestValue;
  final double? change;
  final double? changePercent;

  // labelKey is one of first_result, change_two, moving_up_so_far,
  // moving_down_so_far, steady, not_enough, cannot_compare. positionInRange:
  // 0 = lower printed limit, 1 = upper, may fall outside 0..1. Screens turn
  // keys into words.
  final double? positionInRange;
  final String labelKey;
  final bool canCompare;
  final String? reason;
}

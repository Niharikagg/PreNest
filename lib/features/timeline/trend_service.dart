import 'package:prenest/core/contracts/trend_service.dart' as contract;
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/trend_summary.dart';
import 'package:prenest/core/models/verified_result.dart';

class TrendService implements contract.TrendService {
  @override
  Map<String, List<VerifiedResult>> group(List<VerifiedResult> results) {
    final groups = <String, List<VerifiedResult>>{};
    for (final result in results) {
      final field = result.field;
      final key =
          '${result.personId}|${field.testNameStd}|${field.unit}|${result.stage.name}';
      groups.putIfAbsent(key, () => []).add(result);
    }

    for (final readings in groups.values) {
      readings.sort(_compareByDate);
    }
    return groups;
  }

  @override
  TrendSummary summarize(List<VerifiedResult> sortedGroup) {
    if (sortedGroup.isEmpty) {
      return const TrendSummary(
        count: 0,
        labelKey: 'not_enough',
        canCompare: false,
        reason: 'No verified results are available.',
      );
    }

    final first = sortedGroup.first;
    for (final result in sortedGroup) {
      if (!_isEligible(result)) {
        return _cannotCompare(
          sortedGroup.length,
          'Only complete, confirmed or corrected results can be compared.',
        );
      }
      if (result.personId.trim() != first.personId.trim()) {
        return _cannotCompare(
          sortedGroup.length,
          'Results belong to different people.',
        );
      }
      if (result.field.testNameStd!.trim() != first.field.testNameStd!.trim()) {
        return _cannotCompare(
          sortedGroup.length,
          'Standardized test names do not match.',
        );
      }
      if (result.field.unit.trim().isEmpty ||
          result.field.unit.trim() != first.field.unit.trim()) {
        return _cannotCompare(
          sortedGroup.length,
          'Measurement units are missing or do not match.',
        );
      }
      if (result.stage != first.stage) {
        return _cannotCompare(
          sortedGroup.length,
          'Pregnancy stages do not match.',
        );
      }
    }

    final sorted = List<VerifiedResult>.from(sortedGroup)..sort(_compareByDate);
    final firstValue = sorted.first.field.value!;
    final latestValue = sorted.last.field.value!;

    if (sorted.length == 1) {
      return TrendSummary(
        count: 1,
        firstValue: firstValue,
        latestValue: latestValue,
        labelKey: 'first_result',
        canCompare: true,
        reason: 'Only one compatible verified result is available.',
      );
    }

    final change = latestValue - firstValue;
    if (!change.isFinite) {
      return _cannotCompare(
        sorted.length,
        'The numerical change cannot be represented as a finite value.',
      );
    }
    final changePercent = firstValue == 0 ? null : (change / firstValue) * 100;
    final finiteChangePercent =
        changePercent != null && changePercent.isFinite ? changePercent : null;

    final labelKey = sorted.length == 2
        ? 'change_two'
        : change > 0
            ? 'moving_up_so_far'
            : change < 0
                ? 'moving_down_so_far'
                : 'steady';

    return TrendSummary(
      count: sorted.length,
      firstValue: firstValue,
      latestValue: latestValue,
      change: change,
      changePercent: finiteChangePercent,
      labelKey: labelKey,
      canCompare: true,
      reason: 'Numerical change is calculated chronologically. '
          'It is not a medical conclusion.',
    );
  }

  bool _isEligible(VerifiedResult result) {
    final field = result.field;
    return (field.status == FieldStatus.confirmed ||
            field.status == FieldStatus.corrected) &&
        field.testNameStd != null &&
        field.testNameStd!.trim().isNotEmpty &&
        field.value != null &&
        field.value!.isFinite &&
        field.date != null;
  }

  int _compareByDate(VerifiedResult a, VerifiedResult b) {
    final firstDate = a.field.date;
    final secondDate = b.field.date;
    if (firstDate == null) {
      return secondDate == null ? 0 : -1;
    }
    if (secondDate == null) {
      return 1;
    }
    return firstDate.compareTo(secondDate);
  }

  TrendSummary _cannotCompare(int count, String reason) {
    return TrendSummary(
      count: count,
      labelKey: 'cannot_compare',
      canCompare: false,
      reason: reason,
    );
  }
}

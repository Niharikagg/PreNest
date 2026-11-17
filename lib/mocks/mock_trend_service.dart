import 'package:prenest/core/contracts/trend_service.dart';
import 'package:prenest/core/models/trend_summary.dart';
import 'package:prenest/core/models/verified_result.dart';

class MockTrendService implements TrendService {
  @override
  Map<String, List<VerifiedResult>> group(List<VerifiedResult> results) {
    final groups = <String, List<VerifiedResult>>{};
    for (final result in results) {
      final field = result.field;
      final key =
          '${result.personId}|${field.testNameStd}|${field.unit}|${result.stage.name}';
      groups.putIfAbsent(key, () => []).add(result);
    }
    return groups;
  }

  @override
  TrendSummary summarize(List<VerifiedResult> sortedGroup) {
    final firstValue =
        sortedGroup.isEmpty ? null : sortedGroup.first.field.value;
    final latestValue =
        sortedGroup.isEmpty ? null : sortedGroup.last.field.value;
    return TrendSummary(
      count: sortedGroup.length,
      firstValue: firstValue,
      latestValue: latestValue,
      labelKey: sortedGroup.length < 2 ? 'first_result' : 'not_enough',
      canCompare: true,
    );
  }
}

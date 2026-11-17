import 'package:flutter_test/flutter_test.dart';
import 'package:prenest/core/contracts/trend_service.dart' as contract;
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/person.dart';
import 'package:prenest/core/models/trend_summary.dart';
import 'package:prenest/core/models/verified_result.dart';

import '../../lib/features/timeline/trend_service.dart' as implementation;

VerifiedResult reading({
  String personId = 'P1',
  String testName = 'Test A',
  String unit = 'mg',
  Stage stage = Stage.trimester1,
  FieldStatus status = FieldStatus.confirmed,
  double? value = 10,
  int day = 1,
  bool includeDate = true,
}) {
  return VerifiedResult(
    reportId: 'report-$day',
    personId: personId,
    stage: stage,
    field: ExtractedField(
      id: 'field-$day',
      testNameRaw: testName,
      testNameStd: testName,
      value: value,
      unit: unit,
      date: includeDate ? DateTime.utc(2026, 1, day) : null,
      confidence: 0.9,
      status: status,
    ),
  );
}

void main() {
  group('TrendService contract implementation', () {
    final service = implementation.TrendService();

    test('implements the shared grouping and summary contracts', () {
      final contract.TrendService contractService = service;
      final groups = contractService.group([
        reading(value: 20, day: 2),
        reading(value: 10, day: 1),
      ]);

      expect(groups, hasLength(1));
      expect(groups.values.single.first.field.value, 10);
      expect(groups.values.single.last.field.value, 20);
      expect(
          contractService.summarize(groups.values.single), isA<TrendSummary>());
    });

    test('returns not_enough for empty input and first_result for one reading',
        () {
      final empty = service.summarize([]);
      final single = service.summarize([reading(value: 8)]);

      expect(empty.labelKey, 'not_enough');
      expect(empty.canCompare, isFalse);
      expect(single.labelKey, 'first_result');
      expect(single.firstValue, 8);
      expect(single.change, isNull);
    });

    test('calculates two-result numerical change and percentage', () {
      final summary = service.summarize([
        reading(value: 10, day: 1),
        reading(value: 15, day: 2),
      ]);

      expect(summary.labelKey, 'change_two');
      expect(summary.change, 5);
      expect(summary.changePercent, 50);
      expect(summary.canCompare, isTrue);
    });

    test('uses the shared neutral labels for increasing and decreasing values',
        () {
      final increasing = service.summarize([
        reading(value: 10, day: 1),
        reading(value: 12, day: 2),
        reading(value: 15, day: 3),
      ]);
      final decreasing = service.summarize([
        reading(value: 15, day: 1),
        reading(value: 12, day: 2),
        reading(value: 10, day: 3),
      ]);

      expect(increasing.labelKey, 'moving_up_so_far');
      expect(decreasing.labelKey, 'moving_down_so_far');
    });

    test('reports steady net change for equal or mixed zero-net readings', () {
      final equal = service.summarize([
        reading(value: 10, day: 1),
        reading(value: 10, day: 2),
        reading(value: 10, day: 3),
      ]);
      final mixed = service.summarize([
        reading(value: 10, day: 1),
        reading(value: 15, day: 2),
        reading(value: 10, day: 3),
      ]);

      expect(equal.labelKey, 'steady');
      expect(mixed.labelKey, 'steady');
      expect(mixed.change, 0);
    });

    test('does not calculate percentage from a zero starting value', () {
      final summary = service.summarize([
        reading(value: 0, day: 1),
        reading(value: 5, day: 2),
      ]);

      expect(summary.change, 5);
      expect(summary.changePercent, isNull);
    });

    test('refuses mismatched people, tests, units, and stages', () {
      final incompatibleGroups = [
        [reading(), reading(personId: 'P2', day: 2)],
        [reading(), reading(testName: 'Test B', day: 2)],
        [reading(), reading(unit: 'g/dL', day: 2)],
        [reading(), reading(stage: Stage.trimester2, day: 2)],
      ];

      for (final group in incompatibleGroups) {
        final summary = service.summarize(group);

        expect(summary.labelKey, 'cannot_compare');
        expect(summary.canCompare, isFalse);
        expect(summary.change, isNull);
        expect(summary.reason, isNotNull);
      }
    });

    test('refuses ineligible and incomplete results', () {
      final ineligible = service.summarize([
        reading(),
        reading(status: FieldStatus.needsReview, day: 2),
      ]);
      final missingValue = service.summarize([
        reading(),
        reading(value: null, day: 2),
      ]);
      final missingDate = service.summarize([
        reading(),
        reading(includeDate: false, day: 2),
      ]);

      expect(ineligible.labelKey, 'cannot_compare');
      expect(missingValue.labelKey, 'cannot_compare');
      expect(missingDate.labelKey, 'cannot_compare');
    });
  });
}

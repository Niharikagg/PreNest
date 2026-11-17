import 'package:flutter_test/flutter_test.dart';
import 'package:prenest/core/contracts/validity_engine.dart' as contract;
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/person.dart';
import 'package:prenest/core/models/verified_result.dart';

import '../../lib/features/validity/validity_engine.dart' as implementation;

VerifiedResult verifiedResult({
  String personId = 'P1',
  String testName = 'Test A',
  String unit = 'mg',
  Stage stage = Stage.trimester1,
  FieldStatus status = FieldStatus.confirmed,
  double? value = 10,
  bool includeDate = true,
}) {
  return VerifiedResult(
    reportId: 'report-1',
    personId: personId,
    stage: stage,
    field: ExtractedField(
      id: 'field-1',
      testNameRaw: testName,
      testNameStd: testName,
      value: value,
      unit: unit,
      date: includeDate ? DateTime.utc(2026, 1, 1) : null,
      confidence: 0.9,
      status: status,
    ),
  );
}

void main() {
  group('ValidityEngine contract implementation', () {
    final engine = implementation.ValidityEngine();

    test('implements the shared contract and accepts eligible matches', () {
      final contract.ValidityEngine contractEngine = engine;
      final verdict = contractEngine.check(
        verifiedResult(),
        verifiedResult(),
      );

      expect(verdict.canCompare, isTrue);
      expect(verdict.reason, isNull);
    });

    test('rejects results belonging to different people', () {
      final verdict = engine.check(
        verifiedResult(),
        verifiedResult(personId: 'P2'),
      );

      expect(verdict.canCompare, isFalse);
      expect(verdict.reason, contains('different people'));
    });

    test('rejects different standardized test names', () {
      final verdict = engine.check(
        verifiedResult(),
        verifiedResult(testName: 'Test B'),
      );

      expect(verdict.canCompare, isFalse);
      expect(verdict.reason, contains('test names'));
    });

    test('rejects different or missing units', () {
      final different = engine.check(
        verifiedResult(),
        verifiedResult(unit: 'g/dL'),
      );
      final missing = engine.check(
        verifiedResult(unit: ''),
        verifiedResult(unit: ''),
      );

      expect(different.canCompare, isFalse);
      expect(missing.canCompare, isFalse);
      expect(missing.reason, contains('units'));
    });

    test('rejects results from different stages', () {
      final verdict = engine.check(
        verifiedResult(),
        verifiedResult(stage: Stage.trimester2),
      );

      expect(verdict.canCompare, isFalse);
      expect(verdict.reason, contains('stages'));
    });

    test('rejects unverified and incomplete results', () {
      final unverified = engine.check(
        verifiedResult(),
        verifiedResult(status: FieldStatus.needsReview),
      );
      final missingValue = engine.check(
        verifiedResult(),
        verifiedResult(value: null),
      );
      final missingDate = engine.check(
        verifiedResult(),
        verifiedResult(includeDate: false),
      );
      final missingStandardizedName = engine.check(
        verifiedResult(),
        verifiedResult(testName: ''),
      );

      expect(unverified.canCompare, isFalse);
      expect(missingValue.canCompare, isFalse);
      expect(missingDate.canCompare, isFalse);
      expect(missingStandardizedName.canCompare, isFalse);
    });
  });
}

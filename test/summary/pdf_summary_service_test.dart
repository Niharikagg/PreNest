import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/person.dart';
import 'package:prenest/core/models/trend_summary.dart';
import 'package:prenest/core/models/verified_result.dart';

import '../../lib/features/summary/pdf_summary_service.dart';

class FakePdfEncoder implements PdfSummaryEncoder {
  @override
  Future<List<int>> encode(PdfSummaryDocument document) async => [1, 2, 3];
}

VerifiedResult result({
  String personId = 'P1',
  FieldStatus status = FieldStatus.confirmed,
  String? testName = 'Test A',
  double? value = 12,
  String unit = 'mg',
  bool includeDate = true,
}) {
  return VerifiedResult(
    reportId: 'report-1',
    personId: personId,
    stage: Stage.trimester1,
    field: ExtractedField(
      id: 'field-1',
      testNameRaw: testName ?? '',
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
  late Directory temporaryDirectory;
  final service = PdfSummaryService();

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('prenest_pdf_');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('PdfSummaryService', () {
    test('includes only eligible results for the requested person', () {
      final document = service.prepare(
        personIdentifier: 'P1',
        approvedDisplayName: 'Patient One',
        generatedAt: DateTime.utc(2026, 1, 2),
        results: [
          result(),
          result(status: FieldStatus.auto, testName: 'OCR Test', value: 99),
          result(personId: 'P2', status: FieldStatus.corrected),
        ],
        trends: [
          PdfSummaryTrend(
            personId: 'P1',
            testName: 'Test A',
            summary: const TrendSummary(
              count: 2,
              firstValue: 10,
              latestValue: 12,
              change: 2,
              changePercent: 20,
              labelKey: 'change_two',
              canCompare: true,
              reason: 'Numerical summary only.',
            ),
          ),
        ],
      );

      expect(document.heading, 'PRENEST');
      expect(document.personLabel, 'Patient One');
      expect(document.verifiedResults, hasLength(1));
      expect(document.verifiedResults.single.testName, 'Test A');
      expect(document.trends.single.label, 'Change between two results');
      expect(document.emptyDataMessage, isNull);
      expect(document.disclaimer, contains('not a diagnosis'));
    });

    test('marks missing fields and handles an empty verified set', () {
      final document = service.prepare(
        personIdentifier: 'P1',
        results: [
          result(testName: null, value: null, unit: '', includeDate: false),
          result(status: FieldStatus.needsReview),
        ],
      );

      expect(document.verifiedResults, hasLength(1));
      expect(
        document.verifiedResults.single.missingFields,
        containsAll(['test name', 'value', 'unit', 'date']),
      );

      final emptyDocument = service.prepare(
        personIdentifier: 'P1',
        results: [],
      );
      expect(
        emptyDocument.emptyDataMessage,
        'No verified results are available.',
      );

      final missingPersonDocument = service.prepare(
        personIdentifier: ' ',
        results: [result(personId: '')],
      );
      expect(missingPersonDocument.verifiedResults, isEmpty);
    });

    test('omits numeric data from incompatible trends', () {
      final document = service.prepare(
        personIdentifier: 'P1',
        results: [result()],
        trends: [
          PdfSummaryTrend(
            personId: 'P1',
            testName: 'Test A',
            summary: const TrendSummary(
              count: 2,
              firstValue: 10,
              latestValue: 12,
              change: 2,
              labelKey: 'cannot_compare',
              canCompare: false,
              reason: 'Incompatible results.',
            ),
          ),
        ],
      );

      expect(document.trends.single.label, 'Trend unavailable');
      expect(document.trends.single.firstValue, isNull);
      expect(document.trends.single.change, isNull);
    });

    test('writes encoded bytes to the caller-provided local file', () async {
      final document = service.prepare(
        personIdentifier: 'P1',
        results: [],
      );
      final output = File('${temporaryDirectory.path}\\summary.pdf');

      final saved = await service.saveLocally(
        document: document,
        destination: output,
        encoder: FakePdfEncoder(),
      );

      expect(await saved.readAsBytes(), [1, 2, 3]);
    });
  });
}

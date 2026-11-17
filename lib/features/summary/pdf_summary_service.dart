import 'dart:io';

import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/trend_summary.dart';
import 'package:prenest/core/models/verified_result.dart';

class PdfSummaryTrend {
  final String personId;
  final String testName;
  final TrendSummary summary;

  const PdfSummaryTrend({
    required this.personId,
    required this.testName,
    required this.summary,
  });
}

class PdfSummaryResultLine {
  final String testName;
  final double? value;
  final String unit;
  final DateTime? resultDate;
  final String pregnancyStage;
  final List<String> missingFields;

  PdfSummaryResultLine({
    required this.testName,
    required this.value,
    required this.unit,
    required this.resultDate,
    required this.pregnancyStage,
    required List<String> missingFields,
  }) : missingFields = List.unmodifiable(missingFields);
}

class PdfSummaryTrendLine {
  final String testName;
  final String label;
  final double? firstValue;
  final double? latestValue;
  final double? change;
  final double? changePercent;

  const PdfSummaryTrendLine({
    required this.testName,
    required this.label,
    required this.firstValue,
    required this.latestValue,
    required this.change,
    required this.changePercent,
  });
}

class PdfSummaryDocument {
  final String heading;
  final DateTime generatedAt;
  final String personLabel;
  final List<PdfSummaryResultLine> verifiedResults;
  final List<PdfSummaryTrendLine> trends;
  final String? emptyDataMessage;
  final String disclaimer;

  PdfSummaryDocument({
    required this.heading,
    required this.generatedAt,
    required this.personLabel,
    required List<PdfSummaryResultLine> verifiedResults,
    required List<PdfSummaryTrendLine> trends,
    required this.emptyDataMessage,
    required this.disclaimer,
  })  : verifiedResults = List.unmodifiable(verifiedResults),
        trends = List.unmodifiable(trends);
}

abstract interface class PdfSummaryEncoder {
  Future<List<int>> encode(PdfSummaryDocument document);
}

class PdfSummaryService {
  static const String disclaimer =
      'This summary is for discussion with a healthcare professional. '
      'It is not a diagnosis or a substitute for professional medical advice.';

  PdfSummaryDocument prepare({
    required String personIdentifier,
    String? approvedDisplayName,
    required List<VerifiedResult> results,
    List<PdfSummaryTrend> trends = const [],
    DateTime? generatedAt,
  }) {
    final normalizedPersonId = personIdentifier.trim();
    final verifiedResults = results
        .where(
          (result) =>
              normalizedPersonId.isNotEmpty &&
              result.personId.trim() == normalizedPersonId &&
              (result.field.status == FieldStatus.confirmed ||
                  result.field.status == FieldStatus.corrected),
        )
        .map(_toResultLine)
        .toList();
    final verifiedTrends = trends
        .where(
          (trend) =>
              normalizedPersonId.isNotEmpty &&
              trend.personId.trim() == normalizedPersonId,
        )
        .map(_toTrendLine)
        .toList();

    final displayName = approvedDisplayName?.trim();
    final personLabel = displayName != null && displayName.isNotEmpty
        ? displayName
        : normalizedPersonId.isEmpty
            ? 'Not provided'
            : normalizedPersonId;

    return PdfSummaryDocument(
      heading: 'PRENEST',
      generatedAt: (generatedAt ?? DateTime.now()).toLocal(),
      personLabel: personLabel,
      verifiedResults: verifiedResults,
      trends: verifiedTrends,
      emptyDataMessage:
          verifiedResults.isEmpty ? 'No verified results are available.' : null,
      disclaimer: disclaimer,
    );
  }

  Future<File> saveLocally({
    required PdfSummaryDocument document,
    required File destination,
    required PdfSummaryEncoder encoder,
  }) async {
    final bytes = await encoder.encode(document);
    await destination.parent.create(recursive: true);
    return destination.writeAsBytes(bytes, flush: true);
  }

  PdfSummaryResultLine _toResultLine(VerifiedResult result) {
    final missingFields = <String>[];
    final field = result.field;
    final testName = field.testNameStd?.trim();
    final unit = field.unit.trim();
    final value = field.value;
    if (testName == null || testName.isEmpty) {
      missingFields.add('test name');
    }
    if (value == null || !value.isFinite) {
      missingFields.add('value');
    }
    if (unit.isEmpty) {
      missingFields.add('unit');
    }
    if (field.date == null) {
      missingFields.add('date');
    }
    return PdfSummaryResultLine(
      testName:
          testName == null || testName.isEmpty ? 'Missing test name' : testName,
      value: value != null && value.isFinite ? value : null,
      unit: unit.isEmpty ? 'Missing unit' : unit,
      resultDate: field.date,
      pregnancyStage: result.stage.name,
      missingFields: missingFields,
    );
  }

  PdfSummaryTrendLine _toTrendLine(PdfSummaryTrend trend) {
    final summary = trend.summary;
    final label = !summary.canCompare
        ? 'Trend unavailable'
        : switch (summary.labelKey) {
            'change_two' => 'Change between two results',
            'moving_up_so_far' => 'Increasing pattern so far',
            'moving_down_so_far' => 'Decreasing pattern so far',
            'steady' => 'Steady net change',
            'not_enough' => 'Not enough results',
            'cannot_compare' => 'Trend unavailable',
            'first_result' => 'First result',
            _ => 'Trend summary',
          };
    final canCompare = summary.canCompare;
    return PdfSummaryTrendLine(
      testName: trend.testName.trim().isEmpty
          ? 'Missing test name'
          : trend.testName.trim(),
      label: label,
      firstValue: canCompare ? summary.firstValue : null,
      latestValue: canCompare ? summary.latestValue : null,
      change: canCompare ? summary.change : null,
      changePercent: canCompare && summary.changePercent?.isFinite == true
          ? summary.changePercent
          : null,
    );
  }
}

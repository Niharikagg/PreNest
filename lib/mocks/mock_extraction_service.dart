import 'dart:io';

import 'package:prenest/core/contracts/extraction_service.dart';
import 'package:prenest/core/models/extracted_field.dart';

class MockExtractionService implements ExtractionService {
  @override
  Future<List<ExtractedField>> extract(File image) async {
    final date = DateTime(2026, 10, 12);
    return [
      ExtractedField(
        id: 'haemoglobin',
        testNameRaw: 'Haemoglobin',
        testNameStd: 'haemoglobin',
        value: 11.2,
        unit: 'g/dL',
        date: date,
        rangeLow: 11.0,
        rangeHigh: 14.0,
        confidence: 0.96,
      ),
      ExtractedField(
        id: 'glucose_fasting',
        testNameRaw: 'Glucose fasting',
        testNameStd: 'glucose_fasting',
        value: 92,
        unit: 'mg/dL',
        date: date,
        rangeLow: 70,
        rangeHigh: 100,
        confidence: 0.41,
        status: FieldStatus.needsReview,
      ),
      ExtractedField(
        id: 'tsh',
        testNameRaw: 'TSH',
        testNameStd: 'tsh',
        value: 2.1,
        unit: 'mIU/L',
        date: date,
        rangeLow: 0.4,
        rangeHigh: 4.0,
        confidence: 0.93,
      ),
      ExtractedField(
        id: 'hba1c',
        testNameRaw: 'HbA1c',
        testNameStd: 'hba1c',
        value: 5.8,
        unit: '%',
        date: date,
        rangeLow: 4.0,
        rangeHigh: 5.6,
        confidence: 0.88,
      ),
    ];
  }
}

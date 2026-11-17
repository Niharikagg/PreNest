// FROZEN: changes need approval from every team member
import 'dart:ui';

enum FieldStatus { auto, needsReview, confirmed, corrected }

const Object _unset = Object();

class ExtractedField {
  const ExtractedField({
    required this.id,
    required this.testNameRaw,
    this.testNameStd,
    this.value,
    this.unit = '',
    this.date,
    this.rangeLow,
    this.rangeHigh,
    required this.confidence,
    this.bbox,
    this.status = FieldStatus.auto,
  });

  final String id;
  final String testNameRaw;
  final String? testNameStd;
  final double? value;
  final String unit;
  final DateTime? date;
  final double? rangeLow;
  final double? rangeHigh;
  final double confidence;
  final Rect? bbox;
  final FieldStatus status;

  ExtractedField copyWith({
    Object? testNameStd = _unset,
    Object? value = _unset,
    String? unit,
    Object? date = _unset,
    Object? rangeLow = _unset,
    Object? rangeHigh = _unset,
    FieldStatus? status,
  }) {
    return ExtractedField(
      id: id,
      testNameRaw: testNameRaw,
      testNameStd: identical(testNameStd, _unset)
          ? this.testNameStd
          : testNameStd as String?,
      value: identical(value, _unset) ? this.value : value as double?,
      unit: unit ?? this.unit,
      date: identical(date, _unset) ? this.date : date as DateTime?,
      rangeLow:
          identical(rangeLow, _unset) ? this.rangeLow : rangeLow as double?,
      rangeHigh:
          identical(rangeHigh, _unset) ? this.rangeHigh : rangeHigh as double?,
      confidence: confidence,
      bbox: bbox,
      status: status ?? this.status,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/config/lab_test_configuration.dart';

void main() {
  group('LabTestConfiguration', () {
    test('synthetic demonstration config has no clinical range values', () {
      final configuration = LabTestConfiguration.syntheticDemo;

      expect(configuration.isSynthetic, isTrue);
      expect(configuration.referenceRanges.single.lowerBound, isNull);
      expect(configuration.referenceRanges.single.upperBound, isNull);
      expect(
        configuration.referenceRanges.single.reviewStatus,
        ReferenceReviewStatus.synthetic,
      );
      expect(() => configuration.validate(), returnsNormally);
    });

    test('rejects reversed bounds', () {
      final range = ReferenceRange(
        lowerBound: 5,
        upperBound: 2,
        unit: 'mg',
        applicableContext: 'Test context',
        sourceName: 'Test source',
        reviewStatus: ReferenceReviewStatus.inReview,
      );

      expect(range.validate, throwsFormatException);
    });

    test('requires both bounds together', () {
      final range = ReferenceRange(
        lowerBound: 1,
        upperBound: null,
        unit: 'mg',
        applicableContext: 'Test context',
        sourceName: 'Test source',
        reviewStatus: ReferenceReviewStatus.unreviewed,
      );

      expect(range.validate, throwsFormatException);
    });

    test('approved ranges require traceable source information', () {
      final range = ReferenceRange(
        lowerBound: 1,
        upperBound: 2,
        unit: 'mg',
        applicableContext: 'Test context',
        sourceName: 'Test source',
        reviewStatus: ReferenceReviewStatus.approved,
      );

      expect(range.validate, throwsFormatException);
    });
  });
}

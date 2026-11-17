enum ReferenceReviewStatus {
  unreviewed,
  inReview,
  approved,
  synthetic,
}

class ReferenceRange {
  final double? lowerBound;
  final double? upperBound;
  final String unit;
  final String applicableContext;
  final String sourceName;
  final String? sourceUrl;
  final ReferenceReviewStatus reviewStatus;

  const ReferenceRange({
    required this.lowerBound,
    required this.upperBound,
    required this.unit,
    required this.applicableContext,
    required this.sourceName,
    this.sourceUrl,
    required this.reviewStatus,
  });

  void validate() {
    if (unit.trim().isEmpty ||
        applicableContext.trim().isEmpty ||
        sourceName.trim().isEmpty) {
      throw const FormatException(
        'Reference ranges require a unit, context, and source.',
      );
    }
    if ((lowerBound == null) != (upperBound == null)) {
      throw const FormatException(
        'A reference range must provide both bounds or neither.',
      );
    }
    if (lowerBound != null &&
        (!lowerBound!.isFinite ||
            !upperBound!.isFinite ||
            lowerBound! > upperBound!)) {
      throw const FormatException('Reference range bounds are invalid.');
    }
    if (reviewStatus == ReferenceReviewStatus.approved &&
        (lowerBound == null ||
            sourceUrl == null ||
            sourceUrl!.trim().isEmpty)) {
      throw const FormatException(
        'Approved reference ranges need bounds and a source URL.',
      );
    }
    if (reviewStatus == ReferenceReviewStatus.synthetic &&
        (lowerBound != null || upperBound != null)) {
      throw const FormatException(
        'Synthetic placeholders must not contain clinical range values.',
      );
    }
  }
}

class LabTestConfiguration {
  final String standardizedId;
  final String displayName;
  final List<String> units;
  final List<ReferenceRange> referenceRanges;
  final bool isSynthetic;

  const LabTestConfiguration({
    required this.standardizedId,
    required this.displayName,
    required this.units,
    required this.referenceRanges,
    this.isSynthetic = false,
  });

  void validate() {
    if (standardizedId.trim().isEmpty || displayName.trim().isEmpty) {
      throw const FormatException(
        'A standardized identifier and display name are required.',
      );
    }
    if (units.isEmpty || units.any((unit) => unit.trim().isEmpty)) {
      throw const FormatException('At least one valid unit is required.');
    }
    for (final range in referenceRanges) {
      range.validate();
      if (!units.contains(range.unit)) {
        throw FormatException(
          'Reference range unit "${range.unit}" is not configured for '
          '$standardizedId.',
        );
      }
      if (range.reviewStatus == ReferenceReviewStatus.synthetic &&
          !isSynthetic) {
        throw const FormatException(
          'Synthetic ranges must belong to a synthetic configuration.',
        );
      }
    }
  }

  static const LabTestConfiguration syntheticDemo = LabTestConfiguration(
    standardizedId: 'demo.synthetic.placeholder',
    displayName: 'Synthetic demonstration test',
    units: ['demo units'],
    referenceRanges: [
      ReferenceRange(
        lowerBound: null,
        upperBound: null,
        unit: 'demo units',
        applicableContext: 'Demonstration only; not applicable to care.',
        sourceName: 'Synthetic placeholder; no clinical range supplied.',
        reviewStatus: ReferenceReviewStatus.synthetic,
      ),
    ],
    isSynthetic: true,
  );
}

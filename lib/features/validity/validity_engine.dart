import 'package:prenest/core/contracts/validity_engine.dart' as contract;
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/verified_result.dart';

class ValidityEngine implements contract.ValidityEngine {
  @override
  contract.ComparisonVerdict check(VerifiedResult a, VerifiedResult b) {
    final firstField = a.field;
    final secondField = b.field;
    if (!_isEligible(firstField) || !_isEligible(secondField)) {
      return const contract.ComparisonVerdict.refuse(
        'Only complete, confirmed or corrected results can be compared.',
      );
    }

    if (a.personId.trim().isEmpty || b.personId.trim().isEmpty) {
      return const contract.ComparisonVerdict.refuse(
        'Person identifiers must not be empty.',
      );
    }
    if (a.personId.trim() != b.personId.trim()) {
      return const contract.ComparisonVerdict.refuse(
        'Results belong to different people.',
      );
    }
    if (firstField.testNameStd!.trim().isEmpty ||
        secondField.testNameStd!.trim().isEmpty) {
      return const contract.ComparisonVerdict.refuse(
        'Standardized test names must not be empty.',
      );
    }
    if (firstField.testNameStd!.trim() != secondField.testNameStd!.trim()) {
      return const contract.ComparisonVerdict.refuse(
        'Standardized test names do not match.',
      );
    }
    if (firstField.unit.trim().isEmpty || secondField.unit.trim().isEmpty) {
      return const contract.ComparisonVerdict.refuse(
        'Measurement units must not be empty.',
      );
    }
    if (firstField.unit.trim() != secondField.unit.trim()) {
      return const contract.ComparisonVerdict.refuse(
        'Measurement units do not match.',
      );
    }
    if (a.stage != b.stage) {
      return const contract.ComparisonVerdict.refuse(
        'Pregnancy stages do not match.',
      );
    }
    return const contract.ComparisonVerdict.ok();
  }

  bool _isEligible(ExtractedField field) {
    return (field.status == FieldStatus.confirmed ||
            field.status == FieldStatus.corrected) &&
        field.value != null &&
        field.value!.isFinite &&
        field.date != null &&
        field.testNameStd != null;
  }
}

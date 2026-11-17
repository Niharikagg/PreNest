import 'package:prenest/core/contracts/record_repository.dart';
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/verified_result.dart';

class MockRecordRepository implements RecordRepository {
  final List<VerifiedResult> _results = [];

  @override
  Future<void> saveVerified(List<VerifiedResult> results) async {
    for (final result in results) {
      final field = result.field;
      if ((field.status != FieldStatus.confirmed &&
              field.status != FieldStatus.corrected) ||
          field.value == null ||
          field.date == null ||
          field.testNameStd == null) {
        throw ArgumentError('Only complete, verified results can be saved.');
      }
    }
    _results.addAll(results);
  }

  @override
  Future<List<VerifiedResult>> getByPerson(String personId) async {
    final results = _results
        .where((result) => result.personId == personId)
        .toList()
      ..sort((a, b) => a.field.date!.compareTo(b.field.date!));
    return results;
  }
}

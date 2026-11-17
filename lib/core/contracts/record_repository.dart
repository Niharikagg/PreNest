// FROZEN: changes need approval from every team member
import 'package:prenest/core/models/verified_result.dart';

abstract class RecordRepository {
  // Reject results unless the field is confirmed/corrected and its value, date,
  // and testNameStd are non-null.
  Future<void> saveVerified(List<VerifiedResult> results);

  // Returns results oldest first.
  Future<List<VerifiedResult>> getByPerson(String personId);
}

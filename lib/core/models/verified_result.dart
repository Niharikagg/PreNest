// FROZEN: changes need approval from every team member
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/person.dart';

class VerifiedResult {
  const VerifiedResult({
    required this.reportId,
    required this.personId,
    required this.field,
    required this.stage,
    this.labName,
  });

  final String reportId;
  final String personId;
  final ExtractedField field;
  final Stage stage;
  final String? labName;
}

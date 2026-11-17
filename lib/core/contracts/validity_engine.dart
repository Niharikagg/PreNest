// FROZEN: changes need approval from every team member
import 'package:prenest/core/models/verified_result.dart';

class ComparisonVerdict {
  const ComparisonVerdict._({required this.canCompare, this.reason});

  const ComparisonVerdict.ok() : this._(canCompare: true);

  const ComparisonVerdict.refuse(String reason)
      : this._(canCompare: false, reason: reason);

  final bool canCompare;
  final String? reason;
}

abstract class ValidityEngine {
  ComparisonVerdict check(VerifiedResult a, VerifiedResult b);
}

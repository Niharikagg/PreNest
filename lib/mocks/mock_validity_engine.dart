import 'package:prenest/core/contracts/validity_engine.dart';
import 'package:prenest/core/models/verified_result.dart';

class MockValidityEngine implements ValidityEngine {
  @override
  ComparisonVerdict check(VerifiedResult a, VerifiedResult b) {
    return const ComparisonVerdict.ok();
  }
}

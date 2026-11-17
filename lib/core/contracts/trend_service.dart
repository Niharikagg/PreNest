// FROZEN: changes need approval from every team member
import 'package:prenest/core/models/trend_summary.dart';
import 'package:prenest/core/models/verified_result.dart';

abstract class TrendService {
  Map<String, List<VerifiedResult>> group(List<VerifiedResult> results);

  TrendSummary summarize(List<VerifiedResult> sortedGroup);
}

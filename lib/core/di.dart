import 'package:prenest/core/contracts/extraction_service.dart';
import 'package:prenest/core/contracts/record_repository.dart';
import 'package:prenest/core/contracts/security_service.dart';
import 'package:prenest/core/contracts/trend_service.dart';
import 'package:prenest/core/contracts/validity_engine.dart';
import 'package:prenest/mocks/mock_extraction_service.dart';
import 'package:prenest/mocks/mock_record_repository.dart';
import 'package:prenest/mocks/mock_security_service.dart';
import 'package:prenest/mocks/mock_trend_service.dart';
import 'package:prenest/mocks/mock_validity_engine.dart';

class Services {
  // Owner: Person B.
  static final ExtractionService extraction = MockExtractionService();

  // Owner: Person C.
  static final RecordRepository records = MockRecordRepository();

  // Owner: Person C.
  static final ValidityEngine validity = MockValidityEngine();

  // Owner: Person C.
  static final TrendService trend = MockTrendService();

  // Owner: Person D.
  static final SecurityService security = MockSecurityService();
}

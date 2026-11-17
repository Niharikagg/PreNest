// FROZEN: changes need approval from every team member
import 'dart:io';

import 'package:prenest/core/models/extracted_field.dart';

abstract class ExtractionService {
  // Never throws on a bad read (blank page returns an empty list); never sets
  // status confirmed or corrected.
  Future<List<ExtractedField>> extract(File image);
}

import 'dart:ui';

import 'package:prenest/core/contracts/record_repository.dart';
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/person.dart';
import 'package:prenest/core/models/verified_result.dart';

import 'database_schema.dart';

abstract interface class SqlExecutor {
  Future<int> getVersion();

  Future<void> setVersion(int version);

  Future<T> transaction<T>(Future<T> Function(SqlExecutor executor) action);

  Future<void> execute(String sql);

  Future<int> insert(String table, Map<String, Object?> values);

  Future<List<Map<String, Object?>>> query(
    String sql, {
    List<Object?> arguments = const [],
  });

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArguments,
  });

  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArguments,
  });
}

class VerifiedResultDatabase implements RecordRepository {
  final SqlExecutor _executor;
  bool _initialized = false;

  VerifiedResultDatabase(this._executor);

  Future<void> initialize() async {
    final currentVersion = await _executor.getVersion();
    if (currentVersion > DatabaseSchema.databaseVersion) {
      throw StateError(
        'Database version $currentVersion is newer than supported version '
        '${DatabaseSchema.databaseVersion}.',
      );
    }
    if (currentVersion == DatabaseSchema.databaseVersion) {
      _initialized = true;
      return;
    }

    await _executor.transaction((transaction) async {
      if (currentVersion == 0) {
        for (final statement in DatabaseSchema.createStatements) {
          await transaction.execute(statement);
        }
      } else {
        for (var version = currentVersion;
            version < DatabaseSchema.databaseVersion;
            version++) {
          final statements = DatabaseSchema.migrations[version];
          if (statements == null) {
            throw StateError(
                'No database migration exists from version $version.');
          }
          for (final statement in statements) {
            await transaction.execute(statement);
          }
        }
      }
      await transaction.setVersion(DatabaseSchema.databaseVersion);
    });
    _initialized = true;
  }

  @override
  Future<void> saveVerified(List<VerifiedResult> results) async {
    _ensureInitialized();
    for (final result in results) {
      _validate(result);
    }
    if (results.isEmpty) {
      return;
    }

    await _executor.transaction((transaction) async {
      for (final result in results) {
        await _insert(transaction, result);
      }
    });
  }

  @override
  Future<List<VerifiedResult>> getByPerson(String personId) async {
    _ensureInitialized();
    if (personId.trim().isEmpty) {
      throw ArgumentError.value(personId, 'personId', 'Must not be empty.');
    }
    final rows = await _executor.query(
      'SELECT * FROM ${DatabaseSchema.tableVerifiedResults} '
      'WHERE person_id = ? ORDER BY result_date ASC, id ASC',
      arguments: [personId.trim()],
    );
    return rows.map(_fromDatabaseRow).toList();
  }

  Future<VerifiedResult?> getById(int id) async {
    _ensureInitialized();
    final rows = await _executor.query(
      'SELECT * FROM ${DatabaseSchema.tableVerifiedResults} WHERE id = ? LIMIT 1',
      arguments: [id],
    );
    return rows.isEmpty ? null : _fromDatabaseRow(rows.first);
  }

  Future<int> insert(VerifiedResult result) async {
    _ensureInitialized();
    _validate(result);
    return _insert(_executor, result);
  }

  Future<bool> updateById(int id, VerifiedResult result) async {
    _ensureInitialized();
    _validate(result);
    final updated = await _executor.update(
      DatabaseSchema.tableVerifiedResults,
      _toDatabaseValues(result),
      where: 'id = ?',
      whereArguments: [id],
    );
    return updated != 0;
  }

  Future<bool> deleteById(int id) async {
    _ensureInitialized();
    final deleted = await _executor.delete(
      DatabaseSchema.tableVerifiedResults,
      where: 'id = ?',
      whereArguments: [id],
    );
    return deleted != 0;
  }

  Future<int> _insert(SqlExecutor executor, VerifiedResult result) {
    return executor.insert(
      DatabaseSchema.tableVerifiedResults,
      _toDatabaseValues(result),
    );
  }

  Map<String, Object?> _toDatabaseValues(VerifiedResult result) {
    final field = result.field;
    final bounds = field.bbox;
    return {
      'report_id': result.reportId,
      'person_id': result.personId.trim(),
      'field_id': field.id,
      'test_name_raw': field.testNameRaw,
      'standardized_test_name': field.testNameStd!.trim(),
      'value': field.value!,
      'unit': field.unit.trim(),
      'result_date': field.date!.toUtc().toIso8601String(),
      'pregnancy_stage': result.stage.name,
      'confidence': field.confidence,
      'range_low': field.rangeLow,
      'range_high': field.rangeHigh,
      'bbox_left': bounds?.left,
      'bbox_top': bounds?.top,
      'bbox_right': bounds?.right,
      'bbox_bottom': bounds?.bottom,
      'lab_name': result.labName,
      'status': field.status.name,
    };
  }

  VerifiedResult _fromDatabaseRow(Map<String, Object?> row) {
    int requiredInt(String key) {
      final value = row[key];
      if (value is! int) {
        throw FormatException('Database field "$key" must be an integer.');
      }
      return value;
    }

    requiredInt('id');

    String requiredString(String key) {
      final value = row[key];
      if (value is! String) {
        throw FormatException('Database field "$key" must be a string.');
      }
      return value;
    }

    double requiredDouble(String key) {
      final value = row[key];
      if (value is! num || !value.toDouble().isFinite) {
        throw FormatException('Database field "$key" must be finite.');
      }
      return value.toDouble();
    }

    double? optionalDouble(String key) {
      final value = row[key];
      if (value == null) {
        return null;
      }
      if (value is! num || !value.toDouble().isFinite) {
        throw FormatException('Database field "$key" must be finite.');
      }
      return value.toDouble();
    }

    final dateValue = row['result_date'];
    if (dateValue is! String) {
      throw const FormatException('Database result date must be a string.');
    }
    final statusName = requiredString('status');
    final fieldStatus = FieldStatus.values.firstWhere(
      (status) => status.name == statusName,
      orElse: () =>
          throw FormatException('Unknown field status "$statusName".'),
    );
    final stageName = requiredString('pregnancy_stage');
    final stage = Stage.values.firstWhere(
      (value) => value.name == stageName,
      orElse: () =>
          throw FormatException('Unknown pregnancy stage "$stageName".'),
    );

    final bboxValues = [
      optionalDouble('bbox_left'),
      optionalDouble('bbox_top'),
      optionalDouble('bbox_right'),
      optionalDouble('bbox_bottom'),
    ];
    final hasAnyBboxValue = bboxValues.any((value) => value != null);
    final hasAllBboxValues = bboxValues.every((value) => value != null);
    if (hasAnyBboxValue != hasAllBboxValues) {
      throw const FormatException('Database bounding box is incomplete.');
    }
    final bbox = hasAllBboxValues
        ? Rect.fromLTRB(
            bboxValues[0]!,
            bboxValues[1]!,
            bboxValues[2]!,
            bboxValues[3]!,
          )
        : null;

    final labName = row['lab_name'];
    if (labName != null && labName is! String) {
      throw const FormatException('Database lab name must be a string.');
    }

    return VerifiedResult(
      reportId: requiredString('report_id'),
      personId: requiredString('person_id'),
      stage: stage,
      labName: labName as String?,
      field: ExtractedField(
        id: requiredString('field_id'),
        testNameRaw: requiredString('test_name_raw'),
        testNameStd: requiredString('standardized_test_name'),
        value: requiredDouble('value'),
        unit: requiredString('unit'),
        date: DateTime.parse(dateValue),
        rangeLow: optionalDouble('range_low'),
        rangeHigh: optionalDouble('range_high'),
        confidence: requiredDouble('confidence'),
        bbox: bbox,
        status: fieldStatus,
      ),
    );
  }

  void _validate(VerifiedResult result) {
    final field = result.field;
    if (result.reportId.trim().isEmpty ||
        result.personId.trim().isEmpty ||
        field.id.trim().isEmpty) {
      throw ArgumentError(
          'Report, person, and field identifiers are required.');
    }
    if (field.status != FieldStatus.confirmed &&
        field.status != FieldStatus.corrected) {
      throw ArgumentError('Only confirmed or corrected results can be saved.');
    }
    if (field.value == null ||
        !field.value!.isFinite ||
        field.date == null ||
        field.testNameStd == null ||
        field.testNameStd!.trim().isEmpty) {
      throw ArgumentError(
        'Verified results require a finite value, date, and standardized test name.',
      );
    }
    if (!field.confidence.isFinite ||
        (field.rangeLow != null && !field.rangeLow!.isFinite) ||
        (field.rangeHigh != null && !field.rangeHigh!.isFinite)) {
      throw ArgumentError('Result confidence and ranges must be finite.');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Verified result database has not been initialized.');
    }
  }
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:prenest/core/contracts/record_repository.dart';
import 'package:prenest/core/models/extracted_field.dart';
import 'package:prenest/core/models/person.dart';
import 'package:prenest/core/models/verified_result.dart';

import '../../lib/core/db/database_schema.dart';
import '../../lib/core/db/verified_result_database.dart';

class FakeSqlExecutor implements SqlExecutor {
  int version;
  final List<String> statements = [];
  final Map<int, Map<String, Object?>> rows = {};
  int _nextId = 1;

  FakeSqlExecutor({this.version = 0});

  @override
  Future<int> getVersion() async => version;

  @override
  Future<void> setVersion(int version) async {
    this.version = version;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(SqlExecutor executor) action) {
    return action(this);
  }

  @override
  Future<void> execute(String sql) async {
    statements.add(sql);
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values) async {
    final id = _nextId++;
    rows[id] = {'id': id, ...values};
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, {
    List<Object?> arguments = const [],
  }) async {
    if (sql.contains('WHERE id = ?')) {
      final row = rows[arguments.single as int];
      return row == null ? [] : [Map<String, Object?>.from(row)];
    }
    if (sql.contains('WHERE person_id = ?')) {
      final results = rows.values
          .where((row) => row['person_id'] == arguments.single)
          .toList()
        ..sort(
          (a, b) => (a['result_date']! as String)
              .compareTo(b['result_date']! as String),
        );
      return results.map(Map<String, Object?>.from).toList();
    }
    return rows.values.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArguments,
  }) async {
    final id = whereArguments.single as int;
    if (!rows.containsKey(id)) {
      return 0;
    }
    rows[id] = {'id': id, ...values};
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArguments,
  }) async {
    return rows.remove(whereArguments.single as int) == null ? 0 : 1;
  }
}

VerifiedResult verifiedResult({
  String personId = 'P1',
  String reportId = 'report-1',
  String fieldId = 'field-1',
  String testName = 'Test A',
  String unit = 'mg',
  double? value = 12.5,
  DateTime? date,
  bool includeDate = true,
  FieldStatus status = FieldStatus.confirmed,
  Stage stage = Stage.trimester1,
  String? labName = 'Lab',
}) {
  return VerifiedResult(
    reportId: reportId,
    personId: personId,
    stage: stage,
    labName: labName,
    field: ExtractedField(
      id: fieldId,
      testNameRaw: testName,
      testNameStd: testName,
      value: value,
      unit: unit,
      date: includeDate ? date ?? DateTime.utc(2026, 1, 1) : null,
      rangeLow: 1,
      rangeHigh: 20,
      confidence: 0.9,
      bbox: const Rect.fromLTRB(1, 2, 3, 4),
      status: status,
    ),
  );
}

void main() {
  group('VerifiedResultDatabase', () {
    test('creates the schema and records the current version', () async {
      final executor = FakeSqlExecutor();

      await VerifiedResultDatabase(executor).initialize();

      expect(executor.version, DatabaseSchema.databaseVersion);
      expect(executor.statements, DatabaseSchema.createStatements);
    });

    test('applies migrations from versions one and two', () async {
      final executor = FakeSqlExecutor(version: 1);

      await VerifiedResultDatabase(executor).initialize();

      expect(executor.version, DatabaseSchema.databaseVersion);
      expect(executor.statements, [
        ...DatabaseSchema.migrations[1]!,
        ...DatabaseSchema.migrations[2]!,
      ]);
    });

    test('rejects a database newer than this app supports', () async {
      final executor =
          FakeSqlExecutor(version: DatabaseSchema.databaseVersion + 1);

      await expectLater(
        VerifiedResultDatabase(executor).initialize(),
        throwsStateError,
      );
    });

    test('implements repository save and oldest-first retrieval', () async {
      final executor = FakeSqlExecutor();
      final database = VerifiedResultDatabase(executor);
      final RecordRepository repository = database;
      await database.initialize();

      await repository.saveVerified([
        verifiedResult(date: DateTime.utc(2026, 2, 1)),
        verifiedResult(
          reportId: 'report-2',
          fieldId: 'field-2',
          date: DateTime.utc(2026, 1, 1),
        ),
        verifiedResult(personId: 'P2'),
      ]);

      final results = await repository.getByPerson('P1');
      expect(results, hasLength(2));
      expect(results.first.field.date, DateTime.utc(2026, 1, 1));
      expect(results.last.field.date, DateTime.utc(2026, 2, 1));
      expect(results.last.field.bbox, const Rect.fromLTRB(1, 2, 3, 4));
      expect(results.last.labName, 'Lab');
      expect((await repository.getByPerson('P2')), hasLength(1));
    });

    test('supports id-based retrieval, update and delete', () async {
      final executor = FakeSqlExecutor();
      final database = VerifiedResultDatabase(executor);
      await database.initialize();
      final id = await database.insert(verifiedResult());

      expect((await database.getById(id))?.field.value, 12.5);
      expect(
        await database.updateById(
          id,
          verifiedResult(value: 13, status: FieldStatus.corrected),
        ),
        isTrue,
      );
      expect((await database.getById(id))?.field.status, FieldStatus.corrected);
      expect(await database.deleteById(id), isTrue);
      expect(await database.getById(id), isNull);
    });

    test('rejects records that do not meet the shared contract', () async {
      final executor = FakeSqlExecutor();
      final database = VerifiedResultDatabase(executor);
      await database.initialize();

      await expectLater(
        database.saveVerified([
          verifiedResult(),
          verifiedResult(status: FieldStatus.needsReview),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        database.saveVerified([verifiedResult(value: null)]),
        throwsArgumentError,
      );
      await expectLater(
        database.saveVerified([verifiedResult(includeDate: false)]),
        throwsArgumentError,
      );
      await expectLater(
        database.saveVerified([verifiedResult(testName: '')]),
        throwsArgumentError,
      );
      expect(executor.rows, isEmpty);
    });

    test('requires initialization before repository operations', () async {
      final database = VerifiedResultDatabase(FakeSqlExecutor());
      await expectLater(
        database.getByPerson('P1'),
        throwsStateError,
      );
    });
  });
}

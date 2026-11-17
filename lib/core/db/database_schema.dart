class DatabaseSchema {
  static const String tableVerifiedResults = 'verified_results';

  static const int databaseVersion = 3;

  static const String createVerifiedResultsTable = '''
    CREATE TABLE IF NOT EXISTS verified_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      report_id TEXT NOT NULL DEFAULT '',
      person_id TEXT NOT NULL CHECK (length(trim(person_id)) > 0),
      field_id TEXT NOT NULL DEFAULT '',
      test_name_raw TEXT NOT NULL DEFAULT '',
      standardized_test_name TEXT NOT NULL
        CHECK (length(trim(standardized_test_name)) > 0),
      value REAL NOT NULL,
      unit TEXT NOT NULL,
      result_date TEXT NOT NULL CHECK (length(trim(result_date)) > 0),
      pregnancy_stage TEXT NOT NULL
        CHECK (length(trim(pregnancy_stage)) > 0),
      confidence REAL NOT NULL DEFAULT 0,
      range_low REAL,
      range_high REAL,
      bbox_left REAL,
      bbox_top REAL,
      bbox_right REAL,
      bbox_bottom REAL,
      lab_name TEXT,
      status TEXT NOT NULL
        CHECK (status IN ('confirmed', 'corrected'))
    );
  ''';

  static const String createPersonTestDateIndex = '''
    CREATE INDEX IF NOT EXISTS idx_verified_results_person_test_date
    ON verified_results (person_id, standardized_test_name, result_date);
  ''';

  static const List<String> createStatements = [
    createVerifiedResultsTable,
    createPersonTestDateIndex,
  ];

  static const Map<int, List<String>> migrations = {
    1: [createPersonTestDateIndex],
    2: [
      "ALTER TABLE verified_results ADD COLUMN report_id TEXT NOT NULL DEFAULT '';",
      "ALTER TABLE verified_results ADD COLUMN field_id TEXT NOT NULL DEFAULT '';",
      "ALTER TABLE verified_results ADD COLUMN test_name_raw TEXT NOT NULL DEFAULT '';",
      'ALTER TABLE verified_results ADD COLUMN confidence REAL NOT NULL DEFAULT 0;',
      'ALTER TABLE verified_results ADD COLUMN range_low REAL;',
      'ALTER TABLE verified_results ADD COLUMN range_high REAL;',
      'ALTER TABLE verified_results ADD COLUMN bbox_left REAL;',
      'ALTER TABLE verified_results ADD COLUMN bbox_top REAL;',
      'ALTER TABLE verified_results ADD COLUMN bbox_right REAL;',
      'ALTER TABLE verified_results ADD COLUMN bbox_bottom REAL;',
      'ALTER TABLE verified_results ADD COLUMN lab_name TEXT;',
      'UPDATE verified_results SET test_name_raw = standardized_test_name '
          "WHERE test_name_raw = '';",
    ],
  };
}

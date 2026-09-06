import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'kitsune.sqlite');
    return openDatabase(
      path,
      version: 4,
      onCreate: (database, version) async {
        await database.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);''');
        await database.execute('''
CREATE TABLE medications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  generic_name TEXT,
  brand_name TEXT,
  medication_type TEXT,
  formulation TEXT,
  dose TEXT,
  dose_units TEXT,
  route TEXT,
  frequency TEXT,
  schedule TEXT,
  location TEXT,
  prescription_info TEXT,
  prescriber TEXT,
  pharmacy TEXT,
  start_date TEXT,
  end_date TEXT,
  status TEXT,
  quantity REAL,
  remaining_quantity REAL,
  typical_dose REAL,
  refill_interval TEXT,
  notes TEXT
);''');
        await database.execute('''
CREATE TABLE dose_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medication_id INTEGER,
  scheduled_at TEXT,
  actual_at TEXT,
  status TEXT,
  notes TEXT,
  deleted INTEGER DEFAULT 0
);''');
        await database.execute('''
CREATE TABLE field_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  field_id TEXT NOT NULL,
  value TEXT,
  recorded_at TEXT,
  notes TEXT,
  source TEXT
);''');
        await database.execute('''
CREATE TABLE labs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  test_name TEXT,
  value TEXT,
  unit TEXT,
  reference_range TEXT,
  date TEXT,
  provider TEXT,
  facility TEXT,
  fasting_status TEXT,
  medication_timing TEXT,
  peak_trough TEXT,
  notes TEXT,
  attachment_path TEXT
);''');
        await database.execute('''
CREATE TABLE photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  path TEXT,
  date TEXT,
  category TEXT,
  caption TEXT,
  notes TEXT,
  is_baseline INTEGER,
  timeline_position INTEGER
);''');
        await database.execute('''
CREATE TABLE wellbeing (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT,
  mood INTEGER,
  energy INTEGER,
  sleep INTEGER,
  stress INTEGER,
  pain INTEGER,
  motivation INTEGER,
  dysphoria INTEGER,
  confidence INTEGER,
  overall INTEGER,
  symptoms TEXT,
  notes TEXT
);''');
        await database.execute('''
CREATE TABLE journal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT,
  body TEXT
);''');
        await database.execute('''
CREATE TABLE appointments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  date TEXT,
  notes TEXT,
  kind TEXT
);''');
        await database.execute('''
CREATE TABLE reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  category TEXT,
  datetime TEXT,
  recurring TEXT,
  enabled INTEGER
);''');
        await database.execute('''
CREATE TABLE custom_fields (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  category TEXT,
  input_type TEXT,
  unit TEXT,
  minimum REAL,
  maximum REAL,
  frequency TEXT,
  reminder INTEGER,
  chart_visible INTEGER,
  timeline_visible INTEGER
);''');
        await database.execute('''
CREATE TABLE custom_values (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  field_id INTEGER,
  value TEXT,
  recorded_at TEXT
);''');
        await database.execute('''
CREATE TABLE symptoms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  severity INTEGER,
  date TEXT,
  notes TEXT
);''');
        await database.execute('''
CREATE TABLE support_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  activation TEXT,
  preferred_response TEXT,
  consent TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  visibility TEXT NOT NULL DEFAULT 'private',
  require_unlock INTEGER NOT NULL DEFAULT 1,
  show_timeline INTEGER NOT NULL DEFAULT 0,
  searchable INTEGER NOT NULL DEFAULT 0,
  ai_allowed INTEGER NOT NULL DEFAULT 0,
  export_allowed INTEGER NOT NULL DEFAULT 0
);''');
        await database.execute('''
CREATE TABLE medication_schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medication_id INTEGER NOT NULL,
  recurrence TEXT NOT NULL,
  interval_days INTEGER NOT NULL DEFAULT 1,
  weekdays TEXT,
  time_of_day TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT,
  timezone TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  notifications_enabled INTEGER NOT NULL DEFAULT 0
);''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
CREATE TABLE support_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  activation TEXT,
  preferred_response TEXT,
  consent TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);''');
        }
        if (oldVersion < 3) {
          await database.execute("ALTER TABLE support_notes ADD COLUMN visibility TEXT NOT NULL DEFAULT 'private'");
          await database.execute('ALTER TABLE support_notes ADD COLUMN require_unlock INTEGER NOT NULL DEFAULT 1');
          await database.execute('ALTER TABLE support_notes ADD COLUMN show_timeline INTEGER NOT NULL DEFAULT 0');
          await database.execute('ALTER TABLE support_notes ADD COLUMN searchable INTEGER NOT NULL DEFAULT 0');
          await database.execute('ALTER TABLE support_notes ADD COLUMN ai_allowed INTEGER NOT NULL DEFAULT 0');
          await database.execute('ALTER TABLE support_notes ADD COLUMN export_allowed INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 4) {
          await database.execute('''
CREATE TABLE medication_schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medication_id INTEGER NOT NULL,
  recurrence TEXT NOT NULL,
  interval_days INTEGER NOT NULL DEFAULT 1,
  weekdays TEXT,
  time_of_day TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT,
  timezone TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  notifications_enabled INTEGER NOT NULL DEFAULT 0
);''');
        }
      },
    );
  }

  Future<String?> setting(String key) async {
    final rows = await (await db).query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await (await db).insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> all(String table, {String? where, List<Object?>? args, String? orderBy}) {
    return db.then((d) => d.query(table, where: where, whereArgs: args, orderBy: orderBy));
  }

  Future<int> insert(String table, Map<String, Object?> values) async => (await db).insert(table, values);

  Future<int> update(String table, Map<String, Object?> values, int id) async =>
      (await db).update(table, values, where: 'id = ?', whereArgs: [id]);

  Future<int> delete(String table, int id) async => (await db).delete(table, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteWhere(String table, String where, List<Object?> whereArgs) async =>
      (await db).delete(table, where: where, whereArgs: whereArgs);

  Future<Map<String, dynamic>> dumpAll() async {
    final d = await db;
    final tables = [
      'settings',
      'medications',
      'dose_logs',
      'field_entries',
      'labs',
      'photos',
      'wellbeing',
      'journal',
      'appointments',
      'reminders',
      'custom_fields',
      'custom_values',
      'symptoms',
      'support_notes',
      'medication_schedules',
    ];
    final out = <String, dynamic>{};
    for (final t in tables) {
      out[t] = await d.query(t);
    }
    return out;
  }

  Future<void> restoreAll(Map<String, dynamic> data) async {
    final d = await db;
    await d.transaction((txn) async {
      for (final table in data.keys) {
        await txn.delete(table);
        final rows = (data[table] as List).cast<dynamic>();
        for (final row in rows) {
          await txn.insert(table, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }

  Future<void> deleteEverything() async {
    final d = await db;
    for (final t in [
      'medications',
      'dose_logs',
      'field_entries',
      'labs',
      'photos',
      'wellbeing',
      'journal',
      'appointments',
      'reminders',
      'custom_fields',
      'custom_values',
      'symptoms',
      'support_notes',
      'medication_schedules',
    ]) {
      await d.delete(t);
    }
  }

  Future<Directory> photosDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(dir.path, 'photos'));
    if (!await photos.exists()) await photos.create(recursive: true);
    return photos;
  }

  String csvEscape(Object? v) => '"${'$v'.replaceAll('"', '""')}"';

  Future<String> exportCsv() async {
    final buf = StringBuffer();
    final data = await dumpAll();
    data.forEach((table, rows) {
      buf.writeln('# $table');
      final list = (rows as List).cast<Map>();
      if (list.isEmpty) {
        buf.writeln();
        return;
      }
      final keys = list.first.keys.toList();
      buf.writeln(keys.map(csvEscape).join(','));
      for (final row in list) {
        buf.writeln(keys.map((k) => csvEscape(row[k])).join(','));
      }
      buf.writeln();
    });
    return buf.toString();
  }

  String prettyJson(Map<String, dynamic> data) => const JsonEncoder.withIndent('  ').convert(data);
}

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/diagnosis_result.dart';
import '../models/sensor_reading.dart';

/// Local on-device storage for the History Tracking screen: past
/// diagnoses and sensor snapshots. Nothing here leaves the phone --
/// there's no account system, so history is per-device.
class HistoryDatabase {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'plant_doctor_history.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE diagnoses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT NOT NULL,
            diseaseName TEXT NOT NULL,
            confidence REAL NOT NULL,
            symptomDescription TEXT NOT NULL,
            correctiveMeasures TEXT NOT NULL,
            imagePath TEXT,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sensor_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            temperature REAL,
            humidity REAL,
            soilMoisture INTEGER NOT NULL,
            pumpOn INTEGER NOT NULL,
            mode TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> saveDiagnosis(DiagnosisResult result) async {
    final db = await database;
    return db.insert('diagnoses', result.toMap()..remove('id'));
  }

  Future<List<DiagnosisResult>> getDiagnoses({int limit = 100}) async {
    final db = await database;
    final rows = await db.query('diagnoses', orderBy: 'timestamp DESC', limit: limit);
    return rows.map(DiagnosisResult.fromMap).toList();
  }

  Future<void> saveSensorSnapshot(SensorReading reading) async {
    final db = await database;
    await db.insert('sensor_snapshots', reading.toMap());
  }

  Future<List<SensorReading>> getSensorSnapshots({int limit = 100}) async {
    final db = await database;
    final rows = await db.query('sensor_snapshots', orderBy: 'timestamp DESC', limit: limit);
    return rows.map(SensorReading.fromMap).toList();
  }
}

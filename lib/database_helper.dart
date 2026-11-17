import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'models/laporan.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }

    final lokasi = kIsWeb
        ? 'smart_city.db'
        : p.join(await getDatabasesPath(), 'smart_city.db');

    _db = await openDatabase(
      lokasi,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE laporan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            judul TEXT NOT NULL,
            kategori TEXT NOT NULL,
            lokasi TEXT NOT NULL,
            urgensi INTEGER NOT NULL,
            tanggal TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Baru'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE laporan ADD COLUMN urgensi '
            'INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            "ALTER TABLE laporan ADD COLUMN status "
            "TEXT NOT NULL DEFAULT 'Baru'",
          );
        }
      },
    );

    return _db!;
  }

  Future<int> tambah(Laporan data) async {
    final db = await database;
    return db.insert('laporan', data.toMap());
  }

  Future<List<Laporan>> ambil({
    String cari = '',
    String status = 'Semua',
  }) async {
    final db = await database;
    final kondisi = <String>[];
    final args = <Object?>[];

    if (cari.trim().isNotEmpty) {
      kondisi.add('(judul LIKE ? OR lokasi LIKE ?)');
      args.addAll(['%${cari.trim()}%', '%${cari.trim()}%']);
    }

    if (status != 'Semua') {
      kondisi.add('status = ?');
      args.add(status);
    }

    final hasil = await db.query(
      'laporan',
      where: kondisi.isEmpty ? null : kondisi.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: '''
        CASE WHEN status = 'Selesai' THEN 1 ELSE 0 END ASC,
        urgensi DESC,
        tanggal ASC,
        id ASC
      ''',
    );

    return hasil.map(Laporan.fromMap).toList();
  }

  Future<Map<String, int>> statistik() async {
    final db = await database;

    Future<int> hitung(String sql, [List<Object?>? args]) async {
      final hasil = await db.rawQuery(sql, args);
      return Sqflite.firstIntValue(hasil) ?? 0;
    }

    return {
      'total': await hitung('SELECT COUNT(*) FROM laporan'),
      'aktif': await hitung(
        'SELECT COUNT(*) FROM laporan WHERE status IN (?, ?)',
        ['Baru', 'Diproses'],
      ),
      'selesai': await hitung('SELECT COUNT(*) FROM laporan WHERE status = ?', [
        'Selesai',
      ]),
    };
  }

  Future<int> ubah(Laporan data) async {
    final db = await database;
    return db.update(
      'laporan',
      data.toMap(),
      where: 'id = ?',
      whereArgs: [data.id],
    );
  }

  Future<int> ubahStatus(int id, String status) async {
    final db = await database;
    return db.update(
      'laporan',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> hapus(int id) async {
    final db = await database;
    return db.delete('laporan', where: 'id = ?', whereArgs: [id]);
  }
}

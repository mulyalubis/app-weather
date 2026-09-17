import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'user_login.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            is_login INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
        CREATE TABLE favorite_city (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          city_name TEXT
        )
      ''');
      },
    );
  }

  static Future<void> addFavoriteCity(String city) async {
    final db = await database;

    final exists = await db.query(
      'favorite_city',
      where: 'city_name = ?',
      whereArgs: [city],
    );

    if (exists.isEmpty) {
      await db.insert('favorite_city', {'city_name': city});
    }
  }

  static Future<List<String>> getFavoriteCities() async {
    final db = await database;
    final result = await db.query('favorite_city');

    return result.map((e) => e['city_name'] as String).toList();
  }

  static Future<void> deleteFavoriteCity(String city) async {
    final db = await database;

    await db.delete('favorite_city', where: 'city_name = ?', whereArgs: [city]);
  }
}

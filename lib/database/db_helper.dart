import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    return _database!;
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

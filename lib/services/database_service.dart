import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quiz_rpg/models/player.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database?> get database async {
    if (kIsWeb) {
      // 웹에서는 sqflite를 사용할 수 없으므로 null 반환
      debugPrint("웹 환경에서는 SQLite 데이터베이스를 사용할 수 없습니다.");
      return null;
    }

    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) return null;
    
    try {
      String path = join(await getDatabasesPath(), 'quiz_rpg.db');
      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDatabase,
      );
    } catch (e) {
      debugPrint("데이터베이스 초기화 오류: $e");
      return null;
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // 플레이어 테이블
    await db.execute('''
      CREATE TABLE player(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level INTEGER NOT NULL,
        experience INTEGER NOT NULL,
        requiredExperience INTEGER NOT NULL,
        itemInventory TEXT,
        wrongQuestions TEXT
      )
    ''');

    // 퀴즈 히스토리 테이블
    await db.execute('''
      CREATE TABLE quiz_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playerId INTEGER,
        quizId INTEGER,
        wasCorrect INTEGER,
        timestamp TEXT,
        FOREIGN KEY(playerId) REFERENCES player(id)
      )
    ''');
  }

  Future<int> insertPlayer(Player player) async {
    final db = await database;
    if (db == null) {
      // 웹에서 실행 중인 경우 메모리에만 저장
      debugPrint("웹 환경에서는 플레이어 데이터가 메모리에만 저장됩니다.");
      return 1;
    }
    
    return await db.insert(
      'player',
      {
        'name': player.name,
        'level': player.level,
        'experience': player.experience,
        'requiredExperience': player.requiredExperience,
        'itemInventory': player.itemInventory.join(','),
        'wrongQuestions': player.wrongQuestions.join(','),
      },
    );
  }

  Future<Player?> getPlayer(int id) async {
    final db = await database;
    if (db == null) {
      // 웹에서는 기본 플레이어 반환
      debugPrint("웹 환경에서는 기본 플레이어를 생성합니다.");
      return Player(
        id: 1,
        name: "웹 플레이어",
        level: 1,
        experience: 0,
        requiredExperience: 100,
        itemInventory: [1, 2, 3],
        wrongQuestions: [],
      );
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'player',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    Map<String, dynamic> playerMap = maps.first;
    
    // 문자열 리스트 변환
    List<int> itemInventory = playerMap['itemInventory'] != null && playerMap['itemInventory'].isNotEmpty
        ? playerMap['itemInventory'].split(',').map<int>((e) => int.parse(e)).toList()
        : [];
    
    List<int> wrongQuestions = playerMap['wrongQuestions'] != null && playerMap['wrongQuestions'].isNotEmpty
        ? playerMap['wrongQuestions'].split(',').map<int>((e) => int.parse(e)).toList()
        : [];

    return Player(
      id: playerMap['id'],
      name: playerMap['name'],
      level: playerMap['level'],
      experience: playerMap['experience'],
      requiredExperience: playerMap['requiredExperience'],
      itemInventory: itemInventory,
      wrongQuestions: wrongQuestions,
    );
  }

  Future<int> updatePlayer(Player player) async {
    final db = await database;
    if (db == null) {
      // 웹에서는 업데이트를 시뮬레이션
      debugPrint("웹 환경에서는 플레이어 업데이트가 메모리에만 적용됩니다.");
      return 1;
    }
    
    return await db.update(
      'player',
      {
        'name': player.name,
        'level': player.level,
        'experience': player.experience,
        'requiredExperience': player.requiredExperience,
        'itemInventory': player.itemInventory.join(','),
        'wrongQuestions': player.wrongQuestions.join(','),
      },
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  Future<int> deletePlayer(int id) async {
    final db = await database;
    if (db == null) {
      // 웹에서는 삭제를 시뮬레이션
      debugPrint("웹 환경에서는 플레이어 삭제가 메모리에만 적용됩니다.");
      return 1;
    }
    
    return await db.delete(
      'player',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<int>> getWrongQuestions(int playerId) async {
    Player? player = await getPlayer(playerId);
    return player?.wrongQuestions ?? [];
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await database;
    if (db == null) {
      // 웹에서는 기본 플레이어 목록 반환
      debugPrint("웹 환경에서는 기본 플레이어 목록을 생성합니다.");
      return [
        Player(
          id: 1,
          name: "웹 플레이어",
          level: 1,
          experience: 0,
          requiredExperience: 100,
          itemInventory: [1, 2, 3],
          wrongQuestions: [],
        )
      ];
    }
    
    final List<Map<String, dynamic>> maps = await db.query('player');
    
    return List.generate(maps.length, (i) {
      Map<String, dynamic> playerMap = maps[i];
      
      List<int> itemInventory = playerMap['itemInventory'] != null && playerMap['itemInventory'].isNotEmpty
          ? playerMap['itemInventory'].split(',').map<int>((e) => int.parse(e)).toList()
          : [];
      
      List<int> wrongQuestions = playerMap['wrongQuestions'] != null && playerMap['wrongQuestions'].isNotEmpty
          ? playerMap['wrongQuestions'].split(',').map<int>((e) => int.parse(e)).toList()
          : [];

      return Player(
        id: playerMap['id'],
        name: playerMap['name'],
        level: playerMap['level'],
        experience: playerMap['experience'],
        requiredExperience: playerMap['requiredExperience'],
        itemInventory: itemInventory,
        wrongQuestions: wrongQuestions,
      );
    });
  }

  Future<void> addQuizHistory(int playerId, int quizId, bool wasCorrect) async {
    final db = await database;
    if (db == null) {
      // 웹에서는 히스토리 저장을 시뮬레이션
      debugPrint("웹 환경에서는 퀴즈 히스토리가 저장되지 않습니다.");
      return;
    }
    
    await db.insert('quiz_history', {
      'playerId': playerId,
      'quizId': quizId,
      'wasCorrect': wasCorrect ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
} 
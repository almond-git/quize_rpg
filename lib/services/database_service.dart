import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quiz_rpg/models/player.dart';
import 'package:quiz_rpg/services/quiz_service.dart';

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

    // 완료된 카테고리 테이블
    await db.execute('''
      CREATE TABLE completed_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playerId INTEGER,
        category TEXT,
        completedAt TEXT,
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
    List<int> itemInventory = playerMap['itemInventory'] != null &&
            playerMap['itemInventory'].isNotEmpty
        ? playerMap['itemInventory']
            .split(',')
            .map<int>((e) => int.parse(e))
            .toList()
        : [];

    List<int> wrongQuestions = playerMap['wrongQuestions'] != null &&
            playerMap['wrongQuestions'].isNotEmpty
        ? playerMap['wrongQuestions']
            .split(',')
            .map<int>((e) => int.parse(e))
            .toList()
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

  Future<List<int>> getCorrectQuestions(int playerId) async {
    final db = await database;
    if (db == null) {
      // 웹에서는 빈 목록 반환
      debugPrint("웹 환경에서는 맞힌 문제 기록이 없습니다.");
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'quiz_history',
      where: 'playerId = ? AND wasCorrect = 1',
      whereArgs: [playerId],
    );

    return maps.map((map) => map['quizId'] as int).toList();
  }

  Future<bool> hasCompletedAllQuestionsInCategory(
      int playerId, String category) async {
    final db = await database;
    if (db == null) {
      debugPrint("웹 환경에서는 카테고리 완료 체크를 수행할 수 없습니다.");
      return false;
    }

    final List<int> correctQuestions = await getCorrectQuestions(playerId);
    if (correctQuestions.isEmpty) return false;

    // 현재 카테고리의 모든 퀴즈 ID 가져오기
    try {
      final quizService = QuizService();
      await quizService.loadQuizzes();

      final List<int> categoryQuizIds =
          await quizService.getQuizIdsByCategory(category);
      if (categoryQuizIds.isEmpty) return false;

      // 모든 문제를 맞힌 경우 true 반환
      return categoryQuizIds.every((id) => correctQuestions.contains(id));
    } catch (e) {
      debugPrint('카테고리 완료 체크 오류: $e');
      return false;
    }
  }

  Future<bool> hasCompletedAllQuestionsInSubcategory(
      int playerId, String subcategory) async {
    final db = await database;
    if (db == null) {
      debugPrint("웹 환경에서는 하위 카테고리 완료 체크를 수행할 수 없습니다.");
      return false;
    }

    final List<int> correctQuestions = await getCorrectQuestions(playerId);
    if (correctQuestions.isEmpty) return false;

    // 현재 하위 카테고리의 모든 퀴즈 ID 가져오기
    try {
      final quizService = QuizService();
      await quizService.loadQuizzes();

      final List<int> subcategoryQuizIds =
          await quizService.getQuizIdsBySubcategory(subcategory);
      if (subcategoryQuizIds.isEmpty) return false;

      // 모든 문제를 맞힌 경우 true 반환
      return subcategoryQuizIds.every((id) => correctQuestions.contains(id));
    } catch (e) {
      debugPrint('하위 카테고리 완료 체크 오류: $e');
      return false;
    }
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

      List<int> itemInventory = playerMap['itemInventory'] != null &&
              playerMap['itemInventory'].isNotEmpty
          ? playerMap['itemInventory']
              .split(',')
              .map<int>((e) => int.parse(e))
              .toList()
          : [];

      List<int> wrongQuestions = playerMap['wrongQuestions'] != null &&
              playerMap['wrongQuestions'].isNotEmpty
          ? playerMap['wrongQuestions']
              .split(',')
              .map<int>((e) => int.parse(e))
              .toList()
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

  // 완료된 카테고리 정보 저장
  Future<void> markCategoryAsCompleted(int playerId, String category) async {
    final db = await database;
    if (db == null) {
      debugPrint("웹 환경에서는 카테고리 완료 정보를 저장할 수 없습니다.");
      return;
    }

    try {
      // 이미 완료 정보가 있는지 확인
      final List<Map<String, Object?>> existing = await db.query(
        'completed_categories',
        where: 'playerId = ? AND category = ?',
        whereArgs: [playerId, category],
      );

      if (existing.isEmpty) {
        // 완료 정보 저장
        await db.insert('completed_categories', {
          'playerId': playerId,
          'category': category,
          'completedAt': DateTime.now().toIso8601String(),
        });
        debugPrint('카테고리 완료 정보 저장: $category');
      }
    } catch (e) {
      debugPrint('카테고리 완료 정보 저장 오류: $e');
    }
  }

  // 완료된 카테고리 목록 가져오기
  Future<List<String>> getCompletedCategories(int playerId) async {
    final db = await database;
    if (db == null) {
      debugPrint("웹 환경에서는 완료된 카테고리 정보를 가져올 수 없습니다.");
      return [];
    }

    try {
      final List<Map<String, Object?>> result = await db.query(
        'completed_categories',
        where: 'playerId = ?',
        whereArgs: [playerId],
      );

      return result.map((row) => row['category'] as String).toList();
    } catch (e) {
      debugPrint('완료된 카테고리 정보 조회 오류: $e');
      return [];
    }
  }
}

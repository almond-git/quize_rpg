import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quiz_rpg/models/player.dart';
import 'package:quiz_rpg/services/quiz_service.dart';

class PreferenceService {
  static final PreferenceService _instance = PreferenceService._internal();
  SharedPreferences? _prefs;

  // 키 상수
  static const String keyPlayers = 'players';
  static const String keyQuizHistory = 'quiz_history';
  static const String keyCompletedCategories = 'completed_categories';

  factory PreferenceService() {
    return _instance;
  }

  PreferenceService._internal();

  // 초기화
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 플레이어 관련 메서드
  Future<List<Player>> getPlayers() async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return getPlayers();
    }

    final String? playersJson = prefs.getString(keyPlayers);
    if (playersJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(playersJson);
      return decoded.map((json) => Player.fromJson(json)).toList();
    } catch (e) {
      debugPrint('플레이어 목록 파싱 오류: $e');
      return [];
    }
  }

  Future<Player?> getPlayerById(int id) async {
    final players = await getPlayers();
    try {
      return players.firstWhere((player) => player.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> addPlayer(Player player) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return addPlayer(player);
    }

    final players = await getPlayers();

    // 새 ID 할당
    int maxId = 0;
    for (var p in players) {
      if (p.id > maxId) maxId = p.id;
    }

    final newPlayer = Player(
      id: maxId + 1,
      name: player.name,
      level: player.level,
      experience: player.experience,
      requiredExperience: player.requiredExperience,
      itemInventory: player.itemInventory,
      wrongQuestions: player.wrongQuestions,
    );

    players.add(newPlayer);
    await _savePlayers(players);

    return newPlayer.id;
  }

  Future<void> updatePlayer(Player player) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return updatePlayer(player);
    }

    final players = await getPlayers();
    final index = players.indexWhere((p) => p.id == player.id);

    if (index >= 0) {
      players[index] = player;
      await _savePlayers(players);
    }
  }

  Future<void> _savePlayers(List<Player> players) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return _savePlayers(players);
    }

    final encoded = jsonEncode(players.map((p) => p.toJson()).toList());
    await prefs.setString(keyPlayers, encoded);
  }

  // 퀴즈 히스토리 관련 메서드
  Future<List<Map<String, dynamic>>> getQuizHistory(int playerId) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return getQuizHistory(playerId);
    }

    final String key = '$keyQuizHistory-$playerId';
    final String? historyJson = prefs.getString(key);

    if (historyJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('퀴즈 히스토리 파싱 오류: $e');
      return [];
    }
  }

  Future<void> addQuizHistory(int playerId, int quizId, bool wasCorrect) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return addQuizHistory(playerId, quizId, wasCorrect);
    }

    final history = await getQuizHistory(playerId);

    history.add({
      'quizId': quizId,
      'wasCorrect': wasCorrect,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final String key = '$keyQuizHistory-$playerId';
    await prefs.setString(key, jsonEncode(history));

    // 틀린 문제 관리
    if (!wasCorrect) {
      await addWrongQuestion(playerId, quizId);
    } else {
      await removeWrongQuestion(playerId, quizId);
    }
  }

  // 맞힌 문제 목록 가져오기
  Future<List<int>> getCorrectQuestions(int playerId) async {
    final history = await getQuizHistory(playerId);
    final Set<int> correctIds = {};

    for (var record in history) {
      final int quizId = record['quizId'];
      final bool wasCorrect = record['wasCorrect'];

      if (wasCorrect) {
        correctIds.add(quizId);
      }
    }

    return correctIds.toList();
  }

  // 틀린 문제 관리
  Future<List<int>> getWrongQuestions(int playerId) async {
    final player = await getPlayerById(playerId);
    return player?.wrongQuestions ?? [];
  }

  Future<void> addWrongQuestion(int playerId, int quizId) async {
    final player = await getPlayerById(playerId);
    if (player == null) return;

    if (!player.wrongQuestions.contains(quizId)) {
      player.wrongQuestions.add(quizId);
      await updatePlayer(player);
    }
  }

  Future<void> removeWrongQuestion(int playerId, int quizId) async {
    final player = await getPlayerById(playerId);
    if (player == null) return;

    player.wrongQuestions.remove(quizId);
    await updatePlayer(player);
  }

  // 카테고리 완료 정보 관리
  Future<List<String>> getCompletedCategories(int playerId) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return getCompletedCategories(playerId);
    }

    final String key = '$keyCompletedCategories-$playerId';
    final String? categoriesJson = prefs.getString(key);

    if (categoriesJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(categoriesJson);
      return decoded.cast<String>();
    } catch (e) {
      debugPrint('완료된 카테고리 파싱 오류: $e');
      return [];
    }
  }

  Future<void> markCategoryAsCompleted(int playerId, String category) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return markCategoryAsCompleted(playerId, category);
    }

    final categories = await getCompletedCategories(playerId);

    if (!categories.contains(category)) {
      categories.add(category);

      final String key = '$keyCompletedCategories-$playerId';
      await prefs.setString(key, jsonEncode(categories));
    }
  }

  // 카테고리 완료 목록에서 제거
  Future<void> removeCategoryFromCompleted(
      int playerId, String category) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return removeCategoryFromCompleted(playerId, category);
    }

    final categories = await getCompletedCategories(playerId);

    if (categories.contains(category)) {
      categories.remove(category);

      final String key = '$keyCompletedCategories-$playerId';
      await prefs.setString(key, jsonEncode(categories));
      debugPrint('카테고리가 완료 목록에서 제거됨: $category, 플레이어 ID: $playerId');
    }
  }

  // 플레이어 삭제 메서드
  Future<int> deletePlayer(int id) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return deletePlayer(id);
    }

    final players = await getPlayers();
    final initialCount = players.length;

    players.removeWhere((player) => player.id == id);

    if (initialCount != players.length) {
      await _savePlayers(players);

      // 관련 데이터 삭제
      final historyKey = '$keyQuizHistory-$id';
      final categoriesKey = '$keyCompletedCategories-$id';

      await prefs.remove(historyKey);
      await prefs.remove(categoriesKey);

      return 1; // 삭제된 플레이어 수
    }

    return 0; // 삭제된 플레이어 없음
  }

  // 카테고리 완료 체크
  Future<bool> hasCompletedAllQuestionsInSubcategory(
      int playerId, String subcategory) async {
    // 1. 카테고리가 이미 완료 목록에 있는지 확인
    final completedCategories = await getCompletedCategories(playerId);
    final bool isMarkedAsCompleted = completedCategories.contains(subcategory);
    debugPrint('카테고리 완료 체크 시작: $subcategory, 완료 목록 포함: $isMarkedAsCompleted');

    // 2. 맞힌 문제 확인
    final correctQuestions = await getCorrectQuestions(playerId);
    debugPrint(
        '플레이어의 맞힌 문제 수: ${correctQuestions.length}, 목록: $correctQuestions');
    if (correctQuestions.isEmpty) return false;

    // QuizService 사용
    final quizService = QuizService();
    await quizService.loadQuizzes();

    // 현재 하위 카테고리의 모든 퀴즈 ID 가져오기
    final List<int> subcategoryQuizIds =
        await quizService.getQuizIdsBySubcategory(subcategory);
    debugPrint('카테고리의 전체 문제 ID: $subcategoryQuizIds');
    if (subcategoryQuizIds.isEmpty) return false;

    // 모든 문제를 맞혔는지 확인
    final bool hasAnsweredAllQuestions =
        subcategoryQuizIds.every((id) => correctQuestions.contains(id));

    // 각 문제별 정답 여부 로그
    for (var id in subcategoryQuizIds) {
      final bool isAnswered = correctQuestions.contains(id);
      debugPrint('문제 ID $id: ${isAnswered ? "맞힘" : "아직 맞히지 않음"}');
    }

    debugPrint(
        '카테고리 $subcategory 완료 체크 결과: 모든 문제 정답=$hasAnsweredAllQuestions, 완료 목록에 있음=$isMarkedAsCompleted');

    // 모든 문제를 맞히고 완료 목록에 있는 경우에만 완료로 처리
    if (isMarkedAsCompleted) {
      return hasAnsweredAllQuestions;
    } else {
      // 완료 목록에 없으면 새로 도전하는 것이므로 모든 문제를 맞혀야 함
      return false;
    }
  }

  // 카테고리 재도전을 위한 히스토리 초기화
  Future<void> resetCategoryHistory(int playerId, String category) async {
    final prefs = _prefs;
    if (prefs == null) {
      await init();
      return resetCategoryHistory(playerId, category);
    }

    // 1. 히스토리 가져오기
    final history = await getQuizHistory(playerId);
    if (history.isEmpty) return;

    // 2. 현재 카테고리의 퀴즈 ID 목록 가져오기
    final quizService = QuizService();
    await quizService.loadQuizzes();
    final categoryQuizIds = await quizService.getQuizIdsBySubcategory(category);

    // 3. 해당 카테고리의 정답 기록만 제거한 새 히스토리 생성
    final updatedHistory = history.where((record) {
      final int quizId = record['quizId'];
      final bool isCategoryQuiz = categoryQuizIds.contains(quizId);
      final bool wasCorrect = record['wasCorrect'];

      // 이 카테고리의 정답 기록은 제외
      return !(isCategoryQuiz && wasCorrect);
    }).toList();

    // 4. 업데이트된 히스토리 저장
    final String key = '$keyQuizHistory-$playerId';
    await prefs.setString(key, jsonEncode(updatedHistory));

    debugPrint(
        '카테고리 히스토리 초기화됨: $category, 제거된 기록 수: ${history.length - updatedHistory.length}');

    // 5. 정답 목록 업데이트를 로그로 확인
    final updatedCorrectQuestions = await getCorrectQuestions(playerId);
    debugPrint('완료된 카테고리 업데이트: $updatedCorrectQuestions');
  }
}

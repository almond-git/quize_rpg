import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quiz_rpg/models/quiz.dart';
import 'package:quiz_rpg/services/database_service.dart';
import 'package:quiz_rpg/providers/quiz_file_provider.dart';

class QuizService {
  static final QuizService _instance = QuizService._internal();
  final DatabaseService _databaseService = DatabaseService();
  List<Quiz> _quizzes = [];
  final Random _random = Random();
  QuizFileProvider? _quizFileProvider;

  factory QuizService() {
    return _instance;
  }

  QuizService._internal();

  // 퀴즈 파일 프로바이더 설정
  void setQuizFileProvider(QuizFileProvider provider) {
    _quizFileProvider = provider;
  }

  // 모든 퀴즈 불러오기
  Future<void> loadQuizzes() async {
    // 이미 로드된 경우 다시 로드하지 않음 (강제 리로드 옵션 추가)
    if (_quizzes.isNotEmpty && _quizFileProvider == null) return;
    
    try {
      _quizzes = [];
      
      // 퀴즈 파일 프로바이더가 설정되어 있는 경우
      if (_quizFileProvider != null) {
        List<String> contents = _quizFileProvider!.getActiveQuizContents();
        
        if (contents.isNotEmpty) {
          for (String content in contents) {
            try {
              final List<dynamic> quizList = json.decode(content);
              final quizzes = quizList.map((json) => Quiz.fromJson(json)).toList();
              _quizzes.addAll(quizzes);
            } catch (e) {
              debugPrint('퀴즈 파일 파싱 오류: $e');
            }
          }
        }
      }
      
      // 퀴즈 파일 없거나 파싱 실패 시 기본 퀴즈 로드
      if (_quizzes.isEmpty) {
        try {
          // assets 폴더에서 JSON 파일 로드
          final String jsonData = await rootBundle.loadString('assets/data/quizzes.json');
          final List<dynamic> quizList = json.decode(jsonData);
          _quizzes = quizList.map((json) => Quiz.fromJson(json)).toList();
        } catch (e) {
          debugPrint('기본 퀴즈 데이터 로드 오류: $e');
          // 퀴즈 로드 실패 시 기본 더미 데이터 생성
          _generateDummyQuizzes();
        }
      }
      
      // 퀴즈 ID 중복 처리
      _resolveQuizIdConflicts();
      
    } catch (e) {
      debugPrint('퀴즈 데이터 로드 오류: $e');
      // 오류 발생 시 더미 데이터 생성
      _generateDummyQuizzes();
    }
  }
  
  // 퀴즈 ID 중복 해결 (여러 파일에서 로드 시 발생 가능)
  void _resolveQuizIdConflicts() {
    Map<int, int> idMap = {}; // 원래 ID -> 새 ID 매핑
    List<Quiz> uniqueQuizzes = [];
    int maxId = 0;
    
    for (var quiz in _quizzes) {
      if (idMap.containsKey(quiz.id)) {
        // ID 중복인 경우 새 ID 할당
        if (!idMap.containsValue(quiz.id)) {
          // 새 ID 생성
          maxId = maxId + 1;
          idMap[quiz.id] = maxId;
          
          // 새 ID로 퀴즈 복제
          final newQuiz = Quiz(
            id: maxId,
            question: quiz.question,
            options: quiz.options,
            correctOptionIndex: quiz.correctOptionIndex,
            difficulty: quiz.difficulty,
            category: quiz.category,
            experienceReward: quiz.experienceReward,
            experiencePenalty: quiz.experiencePenalty,
          );
          uniqueQuizzes.add(newQuiz);
        }
      } else {
        // 중복이 아닌 경우 그대로 추가
        idMap[quiz.id] = quiz.id;
        uniqueQuizzes.add(quiz);
        maxId = maxId < quiz.id ? quiz.id : maxId;
      }
    }
    
    _quizzes = uniqueQuizzes;
  }

  // 테스트용 더미 퀴즈 생성
  void _generateDummyQuizzes() {
    _quizzes = [
      Quiz(
        id: 1,
        question: '대한민국의 수도는?',
        options: ['서울', '부산', '인천', '대구'],
        correctOptionIndex: 0,
        difficulty: 1,
        category: '일반상식',
        experienceReward: 10,
        experiencePenalty: 5,
      ),
      Quiz(
        id: 2,
        question: '1 + 1 = ?',
        options: ['1', '2', '3', '4'],
        correctOptionIndex: 1,
        difficulty: 1,
        category: '수학',
        experienceReward: 10,
        experiencePenalty: 5,
      ),
      Quiz(
        id: 3,
        question: '물의 화학식은?',
        options: ['CO2', 'H2O', 'O2', 'N2'],
        correctOptionIndex: 1,
        difficulty: 2,
        category: '과학',
        experienceReward: 20,
        experiencePenalty: 10,
      ),
      Quiz(
        id: 4,
        question: '세계에서 가장 넓은 대륙은?',
        options: ['아시아', '아프리카', '유럽', '남아메리카'],
        correctOptionIndex: 0,
        difficulty: 2,
        category: '지리',
        experienceReward: 20,
        experiencePenalty: 10,
      ),
      Quiz(
        id: 5,
        question: '다음 중 프로그래밍 언어가 아닌 것은?',
        options: ['Java', 'Python', 'Banana', 'JavaScript'],
        correctOptionIndex: 2,
        difficulty: 3,
        category: '프로그래밍',
        experienceReward: 30,
        experiencePenalty: 15,
      ),
    ];
  }

  // 퀴즈 다시 로드하기 (설정 변경 후 호출)
  Future<void> reloadQuizzes() async {
    _quizzes = [];
    await loadQuizzes();
  }

  // 랜덤 퀴즈 가져오기
  Future<Quiz> getRandomQuiz({
    List<int>? excludeIds, 
    String? category,
    int? difficulty,
    int playerId = 0,
  }) async {
    await loadQuizzes();
    
    List<Quiz> filteredQuizzes = List.from(_quizzes);
    
    // 제외할 ID 필터링
    if (excludeIds != null && excludeIds.isNotEmpty) {
      filteredQuizzes = filteredQuizzes.where((q) => !excludeIds.contains(q.id)).toList();
    }
    
    // 카테고리 필터링
    if (category != null) {
      filteredQuizzes = filteredQuizzes.where((q) => q.category == category).toList();
    }
    
    // 난이도 필터링
    if (difficulty != null) {
      filteredQuizzes = filteredQuizzes.where((q) => q.difficulty == difficulty).toList();
    }
    
    if (filteredQuizzes.isEmpty) {
      // 필터링 결과가 없으면 전체 퀴즈에서 선택
      filteredQuizzes = List.from(_quizzes);
    }
    
    // 플레이어의 틀린 문제 목록 가져오기
    List<int> wrongQuestionIds = [];
    if (playerId > 0 && !kIsWeb) {
      try {
        wrongQuestionIds = await _databaseService.getWrongQuestions(playerId);
      } catch (e) {
        debugPrint('틀린 문제 목록 가져오기 오류: $e');
      }
    }
    
    // 가중치 부여: 틀린 문제는 선택될 확률을 높임
    List<Quiz> quizzesWithWeights = [];
    for (Quiz quiz in filteredQuizzes) {
      // 틀린 문제는 3배 더 추가 (가중치 3)
      if (wrongQuestionIds.contains(quiz.id)) {
        quizzesWithWeights.add(quiz);
        quizzesWithWeights.add(quiz);
        quizzesWithWeights.add(quiz);
      } else {
        quizzesWithWeights.add(quiz);
      }
    }
    
    return quizzesWithWeights[_random.nextInt(quizzesWithWeights.length)];
  }
  
  // 특정 ID의 퀴즈 가져오기
  Future<Quiz?> getQuizById(int id) async {
    await loadQuizzes();
    try {
      return _quizzes.firstWhere((quiz) => quiz.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // 카테고리 목록 가져오기
  Future<List<String>> getCategories() async {
    await loadQuizzes();
    Set<String> categories = _quizzes.map((quiz) => quiz.category).toSet();
    return categories.toList();
  }
  
  // 퀴즈 개수 가져오기
  Future<int> getQuizCount() async {
    await loadQuizzes();
    return _quizzes.length;
  }
} 
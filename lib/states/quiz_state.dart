import 'package:flutter/material.dart';
import 'package:quiz_rpg/models/quiz.dart';
import 'package:quiz_rpg/services/preference_service.dart';
import 'package:quiz_rpg/services/quiz_service.dart';
import 'package:quiz_rpg/services/sound_service.dart';
import 'dart:math';

// 퀴즈 화면 인터페이스 - 순환 참조 문제 해결
abstract class QuizContext {
  QuizService get quizService;
  PreferenceService get preferenceService;
  int getPlayerId();
}

// 퀴즈 상태 추상 클래스
abstract class QuizState {
  final QuizContext context;

  QuizState(this.context);

  // 퀴즈 로드 메서드
  Future<Quiz?> loadQuiz({
    required List<int> correctQuestions,
    required int playerId,
    int? difficulty,
  });

  // 카테고리 완료 체크 메서드
  Future<bool> checkCategoryCompletion(int playerId);

  // 카테고리 완료 메시지 표시 메서드
  Future<void> showCompletionMessage(BuildContext context);

  // 완료 후 처리 메서드
  Future<void> handleCompletion(BuildContext context);

  // 상태 이름 반환 (디버깅용)
  String get stateName;
}

// 랜덤 퀴즈 상태
class RandomQuizState extends QuizState {
  RandomQuizState(super.context);

  @override
  Future<Quiz?> loadQuiz({
    required List<int> correctQuestions,
    required int playerId,
    int? difficulty,
  }) async {
    // 랜덤 퀴즈는 카테고리 없이 로드
    return await context.quizService.getRandomQuiz(
      excludeIds: null, // 랜덤 퀴즈는 맞힌 문제도 다시 출제 가능
      difficulty: difficulty,
      playerId: playerId,
    );
  }

  @override
  Future<bool> checkCategoryCompletion(int playerId) async {
    // 랜덤 퀴즈는 카테고리 완료 개념이 없음
    return false;
  }

  @override
  Future<void> showCompletionMessage(BuildContext context) async {
    // 랜덤 퀴즈는 완료 메시지 없음
    return;
  }

  @override
  Future<void> handleCompletion(BuildContext context) async {
    // 랜덤 퀴즈는 완료 처리 없음
    return;
  }

  @override
  String get stateName => '랜덤 퀴즈';
}

// 카테고리 퀴즈 기본 상태 (공통 기능 포함)
abstract class CategoryQuizStateBase extends QuizState {
  final String category;

  CategoryQuizStateBase(super.context, this.category);

  @override
  Future<bool> checkCategoryCompletion(int playerId) async {
    // 해당 카테고리의 모든 문제를 맞췄는지 확인
    return await context.preferenceService
        .hasCompletedAllQuestionsInSubcategory(playerId, category);
  }
}

// 초기 카테고리 퀴즈 상태 (미완료 상태)
class InitialCategoryQuizState extends CategoryQuizStateBase {
  InitialCategoryQuizState(super.context, super.category);

  @override
  Future<Quiz?> loadQuiz({
    required List<int> correctQuestions,
    required int playerId,
    int? difficulty,
  }) async {
    debugPrint('초기 상태에서 문제 로드: $category');
    debugPrint('이미 맞힌 문제 ID: $correctQuestions');

    // 카테고리의 모든 문제 ID 가져오기
    final allQuizIds =
        await context.quizService.getQuizIdsBySubcategory(category);
    debugPrint('카테고리의 모든 문제 ID 수: ${allQuizIds.length}');

    // 아직 맞히지 않은 문제만 필터링
    final remainingQuizIds =
        allQuizIds.where((id) => !correctQuestions.contains(id)).toList();
    debugPrint('남은 문제 수: ${remainingQuizIds.length}');

    // 모든 문제를 다 맞혔는지 확인 (완료 목록에 없는 경우만 체크)
    if (remainingQuizIds.isEmpty) {
      // 완료 목록에 이미 있는지 확인
      final completedCategories =
          await context.preferenceService.getCompletedCategories(playerId);
      final bool isAlreadyCompleted = completedCategories.contains(category);

      // 이미 완료된 카테고리라면 다시 시작 가능 (플레이어가 이전에 완료 후 재도전 선택)
      if (isAlreadyCompleted) {
        debugPrint('이미 완료된 카테고리이지만 재도전 중입니다. 모든 문제를 맞혔습니다.');
        // 여기서는 null을 반환하여 완료 처리를 발생시킵니다
        return null;
      }

      // 아직 완료 목록에 없는 경우 (처음으로 모든 문제를 맞힌 경우)
      debugPrint('카테고리의 모든 문제를 처음으로 맞혔습니다. 완료 상태로 전환됩니다.');
      return null; // null 반환하여 완료 처리 발생
    }

    // remainingQuizIds에서 직접 하나를 랜덤하게 선택
    final random = Random();
    final randomIndex = random.nextInt(remainingQuizIds.length);
    final selectedQuizId = remainingQuizIds[randomIndex];
    debugPrint('선택된 문제 ID: $selectedQuizId');

    // 선택된 ID로 퀴즈 로드
    return await context.quizService.getQuizById(selectedQuizId);
  }

  @override
  Future<void> showCompletionMessage(BuildContext context) async {
    // 비동기 작업 전에 모든 객체 참조 캡처
    final navigator = Navigator.of(context);

    debugPrint('카테고리 $category 완료 축하 메시지 표시 시작');

    // 게임 승리 효과음을 먼저 재생합니다 (다른 작업보다 우선)
    try {
      debugPrint('게임 승리 효과음 재생 시도 - SoundType.gameWin');
      // 효과음 서비스가 있는지 확인
      if (soundService != null) {
        await soundService.playSound(SoundType.gameWin);
        debugPrint('게임 승리 효과음 재생 요청 완료');
      } else {
        debugPrint('soundService가 null입니다.');
      }
    } catch (e) {
      debugPrint('게임 승리 효과음 재생 오류: $e');
    }

    // 약간의 지연 추가
    await Future.delayed(const Duration(milliseconds: 300));

    // 카테고리 완료 정보 저장 - 이미 handleCompletion에서 저장했지만 확실히 하기 위해 중복 저장
    final playerId = this.context.getPlayerId();
    if (playerId > 0) {
      try {
        debugPrint(
            '카테고리 완료 정보 저장 시도 (showCompletionMessage) - 플레이어: $playerId, 카테고리: $category');
        await this
            .context
            .preferenceService
            .markCategoryAsCompleted(playerId, category);

        // 저장 확인
        final completedCategories = await this
            .context
            .preferenceService
            .getCompletedCategories(playerId);
        debugPrint('카테고리 완료 정보 저장됨 (showCompletionMessage): $category');
        debugPrint('현재 완료된 카테고리 목록: $completedCategories');
      } catch (e) {
        debugPrint('카테고리 완료 정보 저장 오류: $e');
      }
    }

    if (!navigator.mounted) {
      debugPrint('navigator가 더 이상 mounted 상태가 아니라서 다이얼로그를 표시할 수 없습니다');
      return;
    }

    try {
      debugPrint('카테고리 $category 완료 축하 다이얼로그 표시 시도');

      // 다이얼로그 컨텍스트를 미리 캡처하여 사용
      final dialogContext = navigator.context;

      // 다이얼로그를 미리 생성
      final dialog = AlertDialog(
        title: const Text('축하합니다!'),
        content: Text('$category 카테고리의 모든 문제를 완료했습니다!'),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('축하 다이얼로그 닫기 버튼 클릭');
              // dialogContext 대신 빌더에서 제공하는 컨텍스트를 사용
              Navigator.pop(dialogContext); // 다이얼로그 닫기
              if (navigator.mounted) {
                navigator.pop(); // 퀴즈 화면에서 나가기
              }
            },
            child: const Text('확인'),
          ),
        ],
      );

      // 다이얼로그 표시
      await showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (_) {
          debugPrint('축하 다이얼로그 빌더 실행');
          return dialog;
        },
      );
      debugPrint('카테고리 $category 완료 축하 다이얼로그 표시 완료');
    } catch (e) {
      debugPrint('다이얼로그 표시 중 오류 발생: $e');
    }
  }

  @override
  Future<void> handleCompletion(BuildContext context) async {
    // 비동기 작업 전에 필요한 참조 캡처
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final playerId = this.context.getPlayerId();
    if (playerId <= 0) {
      debugPrint('유효한 플레이어 ID가 없음: $playerId');
      return;
    }

    final isCompleted = await checkCategoryCompletion(playerId);
    debugPrint('카테고리 $category 완료 여부 확인 결과: $isCompleted');

    // 다른 확인 방법으로 모든 문제를 맞혔는지 직접 체크
    final allQuizIds =
        await this.context.quizService.getQuizIdsBySubcategory(category);
    final correctQuestions =
        await this.context.preferenceService.getCorrectQuestions(playerId);

    debugPrint('카테고리 $category 문제 ID 목록: $allQuizIds');
    debugPrint('플레이어 $playerId가 맞힌 문제 ID 목록: $correctQuestions');

    // 카테고리의 모든 문제를 맞혔는지 확인
    bool allQuestionsCorrect = true;
    for (int id in allQuizIds) {
      if (!correctQuestions.contains(id)) {
        allQuestionsCorrect = false;
        debugPrint('맞히지 않은 문제 ID: $id');
        break;
      }
    }

    debugPrint(
        '카테고리 $category 모든 문제(${allQuizIds.length}개) 맞춤 여부: $allQuestionsCorrect');

    // 모든 문제를 맞혔을 때(더 이상 풀 문제가 없는 경우) 강제로 완료 처리
    if (allQuestionsCorrect) {
      debugPrint('카테고리 $category의 모든 문제를 맞혔으므로 완료 처리합니다.');

      // 카테고리 완료 정보 저장
      await this
          .context
          .preferenceService
          .markCategoryAsCompleted(playerId, category);
      debugPrint('카테고리 완료 정보 저장됨: $category, 플레이어 ID: $playerId');

      // 축하 메시지 표시는 여기서 직접 호출하지 않고 _loadNextQuiz에서 처리
      return;
    }

    // 더 이상 풀 문제가 없지만 완료하지 않은 경우 (일부 틀린 문제 있음)
    messenger.showSnackBar(
      SnackBar(content: Text('$category에서 더 이상 풀 문제가 없습니다.')),
    );

    // 3초 후 퀴즈 화면에서 나가기
    Future.delayed(
      const Duration(seconds: 3),
      () {
        if (navigator.mounted) {
          navigator.pop();
        }
      },
    );
  }

  // 완료된 상태로 전환
  QuizState transitionToCompleted() {
    debugPrint('$category: 초기 상태 → 완료 상태로 전환');
    return CompletedCategoryQuizState(context, category);
  }

  @override
  String get stateName => '$category 초기 퀴즈';
}

// 완료된 카테고리 퀴즈 상태
class CompletedCategoryQuizState extends CategoryQuizStateBase {
  // 이 세션에서 맞춘 문제 ID 목록 (메모리 내 트래킹)
  final List<int> _answeredQuestionsInSession = [];

  CompletedCategoryQuizState(super.context, super.category);

  @override
  Future<Quiz?> loadQuiz({
    required List<int> correctQuestions,
    required int playerId,
    int? difficulty,
  }) async {
    // 세션에서 맞힌 문제 목록을 디버그로 출력
    debugPrint('완료 상태에서 문제 로드: $category');
    debugPrint('이번 세션에서 맞힌 문제 ID: $_answeredQuestionsInSession');

    // 카테고리의 모든 문제 ID 가져오기
    final allQuizIds =
        await context.quizService.getQuizIdsBySubcategory(category);
    debugPrint('카테고리의 모든 문제 ID 수: ${allQuizIds.length}');

    // 아직 이 세션에서 맞히지 않은 문제만 필터링
    final remainingQuizIds = allQuizIds
        .where((id) => !_answeredQuestionsInSession.contains(id))
        .toList();
    debugPrint('남은 문제 수: ${remainingQuizIds.length}');

    // 남은 문제가 없으면 세션 초기화하고 다시 시작
    if (remainingQuizIds.isEmpty) {
      debugPrint('모든 문제를 다시 완료했습니다. 세션 초기화');
      _answeredQuestionsInSession.clear();

      // 세션이 초기화된 후 다시 문제 선택
      final refreshedIds = allQuizIds;
      final random = Random();
      final randomIndex = random.nextInt(refreshedIds.length);
      final selectedQuizId = refreshedIds[randomIndex];
      debugPrint('세션 초기화 후 선택된 문제 ID: $selectedQuizId');

      return await context.quizService.getQuizById(selectedQuizId);
    }

    // remainingQuizIds에서 직접 하나를 랜덤하게 선택
    final random = Random();
    final randomIndex = random.nextInt(remainingQuizIds.length);
    final selectedQuizId = remainingQuizIds[randomIndex];
    debugPrint('선택된 문제 ID: $selectedQuizId');

    // 선택된 ID로 퀴즈 로드
    return await context.quizService.getQuizById(selectedQuizId);
  }

  // 정답을 추적하기 위한 메서드
  void trackCorrectAnswer(int quizId) {
    debugPrint('맞힌 문제 추적: 문제 ID $quizId');
    if (!_answeredQuestionsInSession.contains(quizId)) {
      _answeredQuestionsInSession.add(quizId);
      debugPrint('세션 정답 추적 목록에 추가됨: $_answeredQuestionsInSession');
    }
  }

  @override
  Future<void> showCompletionMessage(BuildContext context) async {
    // 비동기 작업 전에 필요한 참조 캡처
    final messenger = ScaffoldMessenger.of(context);

    // 효과음 재생
    try {
      soundService.playSound(SoundType.gameWin);
    } catch (e) {
      debugPrint('완료 효과음 재생 실패: $e');
    }

    // 간단히 메시지만 표시하고 화면은 닫지 않음
    messenger.showSnackBar(
      SnackBar(
        content: Text('축하합니다! $category의 모든 문제를 다시 완료했습니다!'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Future<bool> checkCategoryCompletion(int playerId) async {
    // 완료된 카테고리에서는 세션에서 맞힌 문제를 기준으로 완료 여부를 판단
    // 카테고리의 모든 문제 ID 가져오기
    debugPrint(
        '완료된 카테고리 완료 체크: $category, 세션에서 맞힌 문제 수: ${_answeredQuestionsInSession.length}');
    final allQuizIds =
        await context.quizService.getQuizIdsBySubcategory(category);

    // 카테고리의 모든 문제를 다 맞혔는지 확인
    final isCompleted = _answeredQuestionsInSession.length >= allQuizIds.length;
    debugPrint('카테고리 모든 문제 수: ${allQuizIds.length}, 완료 여부: $isCompleted');

    return isCompleted;
  }

  @override
  Future<void> handleCompletion(BuildContext context) async {
    // 비동기 작업 전에 필요한 참조 캡처
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final playerId = this.context.getPlayerId();
    final isCompleted = await checkCategoryCompletion(playerId);

    // 더 이상 풀 문제가 없지만 완료하지 않은 경우
    if (!isCompleted) {
      // 더 이상 풀 문제가 없지만 완료하지 않은 경우 (일부 틀린 문제 있음)
      messenger.showSnackBar(
        SnackBar(content: Text('$category에서 더 이상 풀 문제가 없습니다.')),
      );

      // 3초 후 퀴즈 화면에서 나가기
      Future.delayed(
        const Duration(seconds: 3),
        () {
          if (navigator.mounted) {
            navigator.pop();
          }
        },
      );
      return;
    }

    // 축하 메시지 표시 및 완료 처리
    if (navigator.mounted) {
      // 상태 전환 전 카테고리 완료 메시지 표시
      await showCompletionMessage(navigator.context);
    }
  }

  // 초기 상태로 다시 전환
  QuizState resetToInitial() {
    debugPrint('$category: 완료 상태 → 초기 상태로 재설정');
    return InitialCategoryQuizState(context, category);
  }

  // 완료됨 확인 다이얼로그 표시
  Future<bool> showCompletedConfirmDialog(BuildContext context) async {
    // 비동기 작업 전에 필요한 참조 캡처
    final navigatorContext = Navigator.of(context).context;

    final result = await showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('카테고리 완료됨'),
          content: Text('$category 카테고리는 이미 완료되었습니다. 처음부터 모든 문제를 다시 풀게 됩니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // 계속 풀기 선택
              },
              child: const Text('확인'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // 나가기 선택
              },
              child: const Text('나가기'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  String get stateName => '$category 완료된 퀴즈';
}

// 퀴즈 상태 팩토리 - 적절한 초기 상태 생성
class QuizStateFactory {
  static Future<QuizState> createQuizState(
      QuizContext context, String? category) async {
    if (category == null) {
      return RandomQuizState(context);
    }

    // 카테고리가 이미 완료되었는지 확인
    final playerId = context.getPlayerId();
    if (playerId <= 0) {
      return InitialCategoryQuizState(context, category);
    }

    final completedCategories =
        await context.preferenceService.getCompletedCategories(playerId);
    final bool isAlreadyCompleted = completedCategories.contains(category);

    if (isAlreadyCompleted) {
      debugPrint('완료된 카테고리: $category, 완료 상태로 초기화');
      return CompletedCategoryQuizState(context, category);
    } else {
      debugPrint('미완료 카테고리: $category, 초기 상태로 초기화');
      return InitialCategoryQuizState(context, category);
    }
  }
}

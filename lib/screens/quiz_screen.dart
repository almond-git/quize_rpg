import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/models/item.dart';
import 'package:quiz_rpg/models/quiz.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/services/quiz_service.dart';
import 'package:quiz_rpg/services/sound_service.dart';
import 'package:quiz_rpg/services/preference_service.dart';
import 'package:quiz_rpg/states/quiz_state.dart';
import 'package:quiz_rpg/widgets/level_animation.dart';
import 'package:quiz_rpg/widgets/option_button.dart';
import 'package:quiz_rpg/widgets/player_status_card.dart';
import 'package:quiz_rpg/widgets/quiz_result_dialog.dart';
import 'package:quiz_rpg/widgets/item_use_button.dart';

class QuizScreen extends StatefulWidget {
  final String? category;
  final int? difficulty;

  const QuizScreen({
    super.key,
    this.category,
    this.difficulty,
  });

  @override
  State<QuizScreen> createState() => QuizScreenState();
}

class QuizScreenState extends State<QuizScreen> implements QuizContext {
  @override
  final QuizService quizService = QuizService();

  @override
  final PreferenceService preferenceService = PreferenceService();

  Quiz? _currentQuiz;
  bool _isLoading = true;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  List<int> _hintsUsed = [];
  bool _retryEnabled = false;
  int _timeLeft = 30; // 기본 시간 30초
  Timer? _timer;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  List<int> _correctQuestions = []; // 맞힌 문제 ID 목록
  late QuizState _quizState; // 퀴즈 상태 객체

  @override
  void initState() {
    super.initState();
    // 비동기 함수 직접 호출이 불가능하므로 분리해서 실행
    _initializeQuiz();
  }

  // 퀴즈 초기화 작업
  Future<void> _initializeQuiz() async {
    // 먼저 퀴즈 상태 초기화
    await _initQuizState();
    // 그 다음 맞힌 문제 목록 로드
    await _loadCorrectQuestions();
  }

  // 퀴즈 상태 초기화
  Future<void> _initQuizState() async {
    if (widget.category != null) {
      // 팩토리를 사용하여 적절한 초기 상태 객체 생성
      _quizState =
          await QuizStateFactory.createQuizState(this, widget.category);
    } else {
      _quizState = RandomQuizState(this);
    }
    debugPrint('퀴즈 상태 초기화: ${_quizState.stateName}');
  }

  // 현재 플레이어 ID 가져오기 (QuizState에서 사용)
  @override
  int getPlayerId() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    return playerProvider.player?.id ?? 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 맞힌 문제 목록 로드
  Future<void> _loadCorrectQuestions() async {
    final playerId = getPlayerId();

    if (playerId > 0) {
      _correctQuestions = await preferenceService.getCorrectQuestions(playerId);

      // 완료된 카테고리인 경우 확인 다이얼로그 표시
      if (_quizState is CompletedCategoryQuizState) {
        final completedState = _quizState as CompletedCategoryQuizState;

        // 첫 화면 렌더링 후 다이얼로그 표시
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          // 타이머를 중지
          _timer?.cancel();

          // 카테고리 완료 확인 다이얼로그 표시
          final willContinue =
              await completedState.showCompletedConfirmDialog(context);

          if (!willContinue) {
            // 나가기를 선택한 경우
            if (mounted) {
              Navigator.pop(context); // 퀴즈 화면 종료
            }
            return;
          }

          // 계속하기를 선택한 경우, 카테고리를 미완료 상태로 변경
          if (playerId > 0 && widget.category != null) {
            // 완료된 카테고리 목록에서 제거
            await preferenceService.removeCategoryFromCompleted(
                playerId, widget.category!);
            debugPrint('카테고리 미완료 상태로 변경: ${widget.category}');

            // 히스토리에서 해당 카테고리의 정답 기록 초기화
            await preferenceService.resetCategoryHistory(
                playerId, widget.category!);

            // 맞힌 문제 목록 다시 로드 (히스토리 초기화 반영)
            _correctQuestions =
                await preferenceService.getCorrectQuestions(playerId);
            debugPrint('초기화 후 맞힌 문제 목록: $_correctQuestions');

            // 퀴즈 상태를 초기 상태로 전환
            _quizState = completedState.resetToInitial();
            debugPrint('초기 상태로 재설정: ${_quizState.stateName}');
          }

          // 타이머 재시작
          if (mounted) {
            _resetTimer();
          }
        });
      }
    }

    // 맞힌 문제 목록 로드 후 퀴즈 로드
    _loadNextQuiz();
  }

  Future<void> _loadNextQuiz() async {
    setState(() {
      _isLoading = true;
      _selectedOptionIndex = null;
      _hasAnswered = false;
      _hintsUsed = [];
      _retryEnabled = false;
    });

    final playerId = getPlayerId();

    try {
      // 상태 객체를 통해 퀴즈 로드
      _currentQuiz = await _quizState.loadQuiz(
        correctQuestions: _correctQuestions,
        playerId: playerId,
        difficulty: widget.difficulty,
      );

      // 퀴즈 선택지 랜덤하게 섞기
      if (_currentQuiz != null) {
        _shuffleQuizOptions();
      }

      // 더 이상 풀 문제가 없는 경우
      if (_currentQuiz == null) {
        if (!mounted) return;

        // 타이머가 실행 중이면 취소
        _timer?.cancel();

        // 초기 상태에서 카테고리를 완료한 경우, 완료 상태로 전환
        if (_quizState is InitialCategoryQuizState) {
          final initialState = _quizState as InitialCategoryQuizState;

          // 완료 목록에 이미 있는지 확인
          final completedCategories =
              await preferenceService.getCompletedCategories(playerId);
          final bool isAlreadyCompleted =
              completedCategories.contains(widget.category);

          debugPrint(
              '카테고리 완료 처리: ${widget.category}, 이미 완료됨: $isAlreadyCompleted');

          if (isAlreadyCompleted) {
            // 이미 완료되었던 카테고리를 다시 모두 맞힌 경우
            debugPrint('이미 완료된 카테고리를 재도전하여 모든 문제를 맞혔습니다.');

            // 간단한 축하 메시지만 표시
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.category} 카테고리의 모든 문제를 다시 맞혔습니다!'),
                duration: const Duration(seconds: 3),
              ),
            );

            // 홈 화면으로 돌아가기
            if (mounted) {
              Navigator.pop(context);
            }
            return;
          } else {
            // 처음으로 카테고리를 완료한 경우 - 축하 다이얼로그 표시
            debugPrint('처음으로 카테고리 완료: handleCompletion 호출');
            await initialState.handleCompletion(context);

            debugPrint('카테고리 완료 처리 후 축하 다이얼로그 직접 호출');
            // 축하 메시지가 표시되지 않았다면 직접 카테고리 완료 대화상자 표시
            await _showCategoryCompletionDialog();

            // 완료 상태로 전환
            _quizState = initialState.transitionToCompleted();
            debugPrint('완료 상태로 전환됨: ${_quizState.stateName}');
            return;
          }
        }
        // 완료 상태에서 모든 문제를 다시 맞춘 경우
        else if (_quizState is CompletedCategoryQuizState) {
          final completedState = _quizState as CompletedCategoryQuizState;
          await completedState.handleCompletion(context);
          await _loadNextQuizAfterCategoryCompleted();
        }
        return;
      }
      
      if (!mounted) return;
      
      // 타이머 초기화 및 시작
      _resetTimer();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('퀴즈 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 30;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
        
        // 10초 남았을 때 경고음 재생
        if (_timeLeft == 10) {
          // ignore: unawaited_futures
          soundService.playSound(SoundType.timeLow);
        }
      } else {
        _timer!.cancel();
        if (!_hasAnswered) {
          _checkAnswer(-1); // 시간 초과로 오답 처리
        }
      }
    });
  }

  void _selectOption(int index) {
    if (_hasAnswered) return;
    
    setState(() {
      _selectedOptionIndex = index;
    });
    
    _checkAnswer(index);
  }

  Future<void> _checkAnswer(int selectedIndex) async {
    if (_hasAnswered || _currentQuiz == null) return;
    
    _timer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final bool isCorrect =
        selectedIndex >= 0 && _currentQuiz!.checkAnswer(selectedIndex);
    
    // 정답/오답 효과음 재생
    if (isCorrect) {
      // ignore: unawaited_futures
      soundService.playSound(SoundType.quizCorrect);
    } else {
      // ignore: unawaited_futures
      soundService.playSound(SoundType.quizWrong);
    }
    
    setState(() {
      _hasAnswered = true;
      _selectedOptionIndex = selectedIndex;
      
      if (isCorrect) {
        _correctAnswers++;
        // 맞힌 문제 목록에 추가
        if (!_correctQuestions.contains(_currentQuiz!.id)) {
          _correctQuestions.add(_currentQuiz!.id);
          debugPrint(
              '맞힌 문제 목록에 추가: ${_currentQuiz!.id}, 현재 목록: $_correctQuestions');
        }

        // 완료 상태에서는 정답 추적
        if (_quizState is CompletedCategoryQuizState) {
          debugPrint('CompletedCategoryQuizState에서 정답 추적: ${_currentQuiz!.id}');
          (_quizState as CompletedCategoryQuizState)
              .trackCorrectAnswer(_currentQuiz!.id);
        }
      } else {
        _wrongAnswers++;
      }
    });

    if (isCorrect) {
      // 맞은 경우: 경험치 획득, 틀린 문제 목록에서 제거, 퀴즈 히스토리 추가
      final int oldLevel = playerProvider.player?.level ?? 1;
      await playerProvider.gainExperience(_currentQuiz!.experienceReward);
      await playerProvider.removeWrongQuestion(_currentQuiz!.id);

      // 퀴즈 히스토리에 정답 기록 추가
      final playerId = playerProvider.player?.id ?? 0;
      await preferenceService.addQuizHistory(playerId, _currentQuiz!.id, true);
      
      if (!mounted) return;
      
      // 레벨업 체크 및 효과음 재생
      final int newLevel = playerProvider.player?.level ?? 1;
      if (newLevel > oldLevel) {
        // ignore: unawaited_futures
        soundService.playSound(SoundType.levelUp);
      }
      
      // 결과 다이얼로그 표시
      _showResultDialog(
        isCorrect: true,
        experienceChange: _currentQuiz!.experienceReward,
        message: '정답입니다! 경험치를 획득했습니다.',
      );
    } else {
      // 틀린 경우: 경험치 감소, 틀린 문제 목록에 추가, 퀴즈 히스토리 추가
      final int oldLevel = playerProvider.player?.level ?? 1;
      await playerProvider.loseExperience(_currentQuiz!.experiencePenalty);
      await playerProvider.addWrongQuestion(_currentQuiz!.id);

      // 퀴즈 히스토리에 오답 기록 추가
      final playerId = playerProvider.player?.id ?? 0;
      await preferenceService.addQuizHistory(playerId, _currentQuiz!.id, false);
      
      if (!mounted) return;
      
      // 레벨 다운 체크 및 효과음 재생
      final int newLevel = playerProvider.player?.level ?? 1;
      if (newLevel < oldLevel) {
        // ignore: unawaited_futures
        soundService.playSound(SoundType.levelDown);
      }
      
      // 결과 다이얼로그 표시
      _showResultDialog(
        isCorrect: false,
        experienceChange: -_currentQuiz!.experiencePenalty,
        message: '오답입니다. 경험치가 감소했습니다.',
      );
    }
  }

  Future<void> _showResultDialog(
      {required bool isCorrect,
    required int experienceChange,
      required String message}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuizResultDialog(
        isCorrect: isCorrect,
        experienceChange: experienceChange,
        message: message,
        onRetry: _retryEnabled
            ? () {
          setState(() {
            _hasAnswered = false;
            _selectedOptionIndex = null;
            _resetTimer();
            _retryEnabled = false;
          });
          Navigator.of(context).pop();
              }
            : null,
        onNext: () {
          Navigator.of(context).pop();
          _loadNextQuiz();
        },
      ),
    );
  }

  // ... 나머지 아이템 사용 메서드들은
  // 원래 코드와 동일하게 유지 ...

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category != null ? widget.category! : '랜덤 퀴즈'),
        actions: [
          // 점수 표시
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.check, color: Colors.green),
                Text('$_correctAnswers'),
                SizedBox(width: 8),
                Icon(Icons.close, color: Colors.red),
                Text('$_wrongAnswers'),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentQuiz == null
              ? const Center(child: Text('퀴즈를 불러올 수 없습니다.'))
              : Stack(
                  children: [
                    SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 타이머 표시
                              LinearProgressIndicator(
                                value: _timeLeft / 30, // 최대 시간 기준으로 비율 계산
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _timeLeft > 10
                                      ? Colors.green
                                      : _timeLeft > 5
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '남은 시간: $_timeLeft초',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _timeLeft > 10
                                      ? Colors.green
                                      : _timeLeft > 5
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 플레이어 상태 카드
                              PlayerStatusCard(
                                player:
                                    Provider.of<PlayerProvider>(context).player,
                                showDetailedStats: false,
                              ),

                              const SizedBox(height: 20),

                              // 문제 카드
                              Card(
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        _currentQuiz!.question,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_currentQuiz!.imagePath != null) ...[
                                        const SizedBox(height: 16),
                                        Image.asset(
                                          _currentQuiz!.imagePath!,
                                          height: 150,
                                          fit: BoxFit.contain,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // 선택지 버튼
                              ...List.generate(
                                _currentQuiz!.options.length,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: OptionButton(
                                    text: _currentQuiz!.options[index],
                                    isSelected: _selectedOptionIndex == index,
                                    isCorrect: _hasAnswered &&
                                        index ==
                                            _currentQuiz!.correctOptionIndex,
                                    isWrong: _hasAnswered &&
                                        _selectedOptionIndex == index &&
                                        index !=
                                            _currentQuiz!.correctOptionIndex,
                                    isHidden: _hintsUsed.contains(index),
                                    onTap: () => _selectOption(index),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              // 아이템 사용 버튼 행
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ItemUseButton(
                                      iconData: Icons.lightbulb,
                                      label: '힌트',
                                      onPressed: _useHintItem,
                                      itemType: ItemType.hintCard,
                                    ),
                                    const SizedBox(width: 8),
                                    ItemUseButton(
                                      iconData: Icons.access_time,
                                      label: '시간 연장',
                                      onPressed: _useTimeExtensionItem,
                                      itemType: ItemType.timeExtension,
                                    ),
                                    const SizedBox(width: 8),
                                    ItemUseButton(
                                      iconData: Icons.refresh,
                                      label: '재도전',
                                      onPressed: _useRetryItem,
                                      itemType: ItemType.retryChance,
                                    ),
                                    const SizedBox(width: 8),
                                    ItemUseButton(
                                      iconData: Icons.trending_up,
                                      label: '경험치 부스터',
                                      onPressed: _useExpBoosterItem,
                                      itemType: ItemType.expBooster,
                                    ),
                                    const SizedBox(width: 8),
                                    ItemUseButton(
                                      iconData: Icons.shield,
                                      label: '방어막',
                                      onPressed: _useShieldItem,
                                      itemType: ItemType.shield,
                                    ),
                                  ],
                                ),
                              ),

                              // 하단 여백 추가
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 레벨업/다운 애니메이션
                    if (playerProvider.isLevelingUp)
                      const LevelAnimation(isLevelUp: true),

                    if (playerProvider.isLevelingDown)
                      const LevelAnimation(isLevelUp: false),
                  ],
                ),
    );
  }

  // 아래는 아이템 사용 메서드들
  Future<void> _useHintItem() async {
    if (_hasAnswered || _currentQuiz == null) return;
    
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final bool hasItem = await playerProvider.useItem(1); // 힌트 카드 아이템 ID
    
    if (!mounted) return;
    
    if (hasItem) {
      // 힌트 아이템 효과음 재생
      // ignore: unawaited_futures
      soundService.playSound(SoundType.itemUse);
      
      // 정답이 아닌 옵션 중 하나를 랜덤하게 제거
      final List<int> wrongOptions = [];
      for (int i = 0; i < _currentQuiz!.options.length; i++) {
        if (i != _currentQuiz!.correctOptionIndex && !_hintsUsed.contains(i)) {
          wrongOptions.add(i);
        }
      }
      
      if (wrongOptions.isNotEmpty) {
        final int randomIndex = Random().nextInt(wrongOptions.length);
        setState(() {
          _hintsUsed.add(wrongOptions[randomIndex]);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('힌트 카드 아이템이 없습니다.')),
      );
    }
  }

  void _useRetryItem() {
    if (_hasAnswered) {
      setState(() {
        _retryEnabled = true;
      });
    }
  }

  Future<void> _useTimeExtensionItem() async {
    if (_hasAnswered || _currentQuiz == null) return;
    
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final bool hasItem = await playerProvider.useItem(2); // 시간 연장 아이템 ID
    
    if (!mounted) return;
    
    if (hasItem) {
      // 시간 연장 아이템 효과음 재생
      // ignore: unawaited_futures
      soundService.playSound(SoundType.itemUse);
      
      // 시간 20초 추가
      setState(() {
        _timeLeft += 20;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간 연장 아이템이 없습니다.')),
      );
    }
  }

  Future<void> _useExpBoosterItem() async {
    if (_hasAnswered || _currentQuiz == null) return;
    
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final bool hasItem = await playerProvider.useItem(3); // 경험치 부스터 아이템 ID
    
    if (!mounted) return;
    
    if (hasItem) {
      // 경험치 부스터 아이템 효과음 재생
      // ignore: unawaited_futures
      soundService.playSound(SoundType.itemUse);
      
      setState(() {
        _currentQuiz = Quiz(
          id: _currentQuiz!.id,
          question: _currentQuiz!.question,
          options: _currentQuiz!.options,
          correctOptionIndex: _currentQuiz!.correctOptionIndex,
          difficulty: _currentQuiz!.difficulty,
          category: _currentQuiz!.category,
          parentCategory: _currentQuiz!.parentCategory,
          experienceReward:
              (_currentQuiz!.experienceReward * 1.5).round(), // 경험치 50% 증가
          experiencePenalty: _currentQuiz!.experiencePenalty,
          imagePath: _currentQuiz!.imagePath,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경험치 부스터가 적용되었습니다! (보상 50% 증가)')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경험치 부스터 아이템이 없습니다.')),
      );
    }
  }

  Future<void> _useShieldItem() async {
    if (_hasAnswered || _currentQuiz == null) return;
    
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final bool hasItem = await playerProvider.useItem(4); // 방어막 아이템 ID
    
    if (!mounted) return;
    
    if (hasItem) {
      // 방어막 아이템 효과음 재생
      // ignore: unawaited_futures
      soundService.playSound(SoundType.itemUse);
      
      setState(() {
        _currentQuiz = Quiz(
          id: _currentQuiz!.id,
          question: _currentQuiz!.question,
          options: _currentQuiz!.options,
          correctOptionIndex: _currentQuiz!.correctOptionIndex,
          difficulty: _currentQuiz!.difficulty,
          category: _currentQuiz!.category,
          parentCategory: _currentQuiz!.parentCategory,
          experienceReward: _currentQuiz!.experienceReward,
          experiencePenalty: 0, // 패널티 제거
          imagePath: _currentQuiz!.imagePath,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방어막이 적용되었습니다! (패널티 제거)')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방어막 아이템이 없습니다.')),
      );
    }
  }

  // 카테고리 완료 대화상자 표시
  Future<void> _showCategoryCompletionDialog() async {
    // 타이머를 취소합니다
    _timer?.cancel();

    debugPrint('카테고리 완료 대화상자 표시 시작 - 카테고리: ${widget.category}');

    // 카테고리 완료 정보 저장
    final playerId = getPlayerId();
    if (playerId > 0 && widget.category != null) {
      debugPrint(
          '카테고리 완료 정보 저장 시도 - 플레이어 ID: $playerId, 카테고리: ${widget.category}');
      await preferenceService.markCategoryAsCompleted(
          playerId, widget.category!);
      debugPrint('카테고리 완료 정보 저장 성공: ${widget.category}, 플레이어 ID: $playerId');

      // 저장 후 완료된 카테고리 목록 확인
      final completedCategories =
          await preferenceService.getCompletedCategories(playerId);
      debugPrint('완료된 카테고리 목록: $completedCategories');
    }

    // 게임 승리 효과음 재생
    try {
      debugPrint('게임 승리 효과음 재생 시도 - SoundType.gameWin');
      await soundService.playSound(SoundType.gameWin);
      debugPrint('게임 승리 효과음 재생 요청 완료');
    } catch (e) {
      debugPrint('게임 승리 효과음 재생 오류: $e');
    }

    // 약간의 지연 추가하여 효과음이 재생될 시간 확보
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) {
      debugPrint('_showCategoryCompletionDialog: context가 더 이상 mounted 상태가 아님');
      return;
    }

    debugPrint('카테고리 완료 축하 다이얼로그 표시 시도');

    // 다이얼로그 컨텍스트를 미리 캡처하여 사용
    final dialogContext = context;

    try {
      await showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (BuildContext context) {
          debugPrint('축하 다이얼로그 빌더 실행');
          return AlertDialog(
            title: const Text('축하합니다!'),
            content: Text('${widget.category} 카테고리의 모든 문제를 완료했습니다!'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  debugPrint('카테고리 완료 축하 다이얼로그 닫기 버튼 클릭');
                  Navigator.of(context).pop(); // 다이얼로그 닫기

                  // 퀴즈 화면으로 돌아가서 홈 화면으로 돌아갈 수 있도록 함
                  if (Navigator.of(dialogContext).canPop()) {
                    debugPrint('퀴즈 화면 닫기 - 홈 화면으로 돌아가기');
                    Navigator.of(dialogContext).pop(); // 퀴즈 화면 닫기 (홈 화면으로 돌아가기)
                  }
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
      debugPrint('카테고리 완료 축하 다이얼로그 표시 완료');
    } catch (e) {
      debugPrint('다이얼로그 표시 중 오류 발생: $e');
    }
  }

  // 이미 완료한 카테고리의 문제를 다시 로드하는 메서드
  Future<void> _loadNextQuizAfterCategoryCompleted() async {
    setState(() {
      _isLoading = true;
      _selectedOptionIndex = null;
      _hasAnswered = false;
      _hintsUsed = [];
      _retryEnabled = false;
    });

    final playerId = getPlayerId();

    try {
      // 완료된 카테고리의 문제 로드 (CompletedCategoryQuizState 사용)
      _currentQuiz = await _quizState.loadQuiz(
        correctQuestions: _correctQuestions,
        playerId: playerId,
        difficulty: widget.difficulty,
      );

      if (_currentQuiz == null || !mounted) {
        return;
      }

      // 퀴즈 선택지 랜덤하게 섞기
      _shuffleQuizOptions();

      // 타이머 초기화 및 시작
      _resetTimer();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('완료된 카테고리 퀴즈 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 퀴즈 옵션을 랜덤하게 섞는 메서드
  void _shuffleQuizOptions() {
    if (_currentQuiz == null) return;

    // 원본 옵션 목록과 정답 인덱스 저장
    final List<String> originalOptions = List.from(_currentQuiz!.options);
    final int originalCorrectIndex = _currentQuiz!.correctOptionIndex;
    final String correctAnswer = originalOptions[originalCorrectIndex];

    // 옵션을 섞을 인덱스 리스트 생성
    List<int> indices = List.generate(originalOptions.length, (i) => i);

    // 인덱스 리스트를 무작위로 섞기
    indices.shuffle();

    // 섞인 인덱스 순서대로 새 옵션 목록 생성
    List<String> shuffledOptions =
        indices.map((i) => originalOptions[i]).toList();

    // 섞인 후 정답의 새 인덱스 찾기
    int newCorrectIndex = shuffledOptions.indexOf(correctAnswer);

    // 퀴즈 객체 업데이트
    _currentQuiz = Quiz(
      id: _currentQuiz!.id,
      question: _currentQuiz!.question,
      options: shuffledOptions,
      correctOptionIndex: newCorrectIndex,
      difficulty: _currentQuiz!.difficulty,
      category: _currentQuiz!.category,
      parentCategory: _currentQuiz!.parentCategory,
      experienceReward: _currentQuiz!.experienceReward,
      experiencePenalty: _currentQuiz!.experiencePenalty,
      imagePath: _currentQuiz!.imagePath,
    );
  }
}

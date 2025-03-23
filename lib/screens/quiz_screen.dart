import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/models/item.dart';
import 'package:quiz_rpg/models/quiz.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/services/quiz_service.dart';
import 'package:quiz_rpg/services/sound_service.dart';
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
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final QuizService _quizService = QuizService();
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

  @override
  void initState() {
    super.initState();
    _loadNextQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadNextQuiz() async {
    setState(() {
      _isLoading = true;
      _selectedOptionIndex = null;
      _hasAnswered = false;
      _hintsUsed = [];
      _retryEnabled = false;
    });

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    try {
      _currentQuiz = await _quizService.getRandomQuiz(
        category: widget.category,
        difficulty: widget.difficulty,
        playerId: playerProvider.player?.id ?? 0,
      );
      
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
    final bool isCorrect = selectedIndex >= 0 && _currentQuiz!.checkAnswer(selectedIndex);
    
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
      } else {
        _wrongAnswers++;
      }
    });

    if (isCorrect) {
      // 맞은 경우: 경험치 획득, 틀린 문제 목록에서 제거
      final int oldLevel = playerProvider.player?.level ?? 1;
      await playerProvider.gainExperience(_currentQuiz!.experienceReward);
      await playerProvider.removeWrongQuestion(_currentQuiz!.id);
      
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
      // 틀린 경우: 경험치 감소, 틀린 문제 목록에 추가
      final int oldLevel = playerProvider.player?.level ?? 1;
      await playerProvider.loseExperience(_currentQuiz!.experiencePenalty);
      await playerProvider.addWrongQuestion(_currentQuiz!.id);
      
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

  Future<void> _showResultDialog({
    required bool isCorrect, 
    required int experienceChange,
    required String message
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuizResultDialog(
        isCorrect: isCorrect,
        experienceChange: experienceChange,
        message: message,
        onRetry: _retryEnabled ? () {
          setState(() {
            _hasAnswered = false;
            _selectedOptionIndex = null;
            _resetTimer();
            _retryEnabled = false;
          });
          Navigator.of(context).pop();
        } : null,
        onNext: () {
          Navigator.of(context).pop();
          _loadNextQuiz();
        },
      ),
    );
  }

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
          experienceReward: (_currentQuiz!.experienceReward * 1.5).round(), // 경험치 50% 증가
          experiencePenalty: _currentQuiz!.experiencePenalty,
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
          experienceReward: _currentQuiz!.experienceReward,
          experiencePenalty: 0, // 패널티 제거
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

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈'),
        actions: [
          // 플레이어 상태는 항상 표시하므로 토글 버튼 제거
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 플레이어 상태 카드 (항상 표시)
                      PlayerStatusCard(
                        player: playerProvider.player,
                        showDetailedStats: false,
                      ),
                      const SizedBox(height: 16),
                      
                      // 타이머와 카테고리
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '카테고리: ${_currentQuiz!.category}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          Text(
                            '남은 시간: $_timeLeft초',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _timeLeft < 10 ? Colors.red : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 문제 난이도
                      Row(
                        children: [
                          Text('난이도: '),
                          ...List.generate(_currentQuiz!.difficulty, (index) => 
                            Icon(Icons.star, color: Colors.amber, size: 16)
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 문제 텍스트
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _currentQuiz!.question,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                            isCorrect: _hasAnswered && index == _currentQuiz!.correctOptionIndex,
                            isWrong: _hasAnswered && _selectedOptionIndex == index && index != _currentQuiz!.correctOptionIndex,
                            isHidden: _hintsUsed.contains(index),
                            onTap: () => _selectOption(index),
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
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
                    ],
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
} 
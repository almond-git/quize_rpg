import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/models/player.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/services/sound_service.dart';

class QuizResultDialog extends StatelessWidget {
  final bool isCorrect;
  final int experienceChange;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onNext;

  const QuizResultDialog({
    super.key,
    required this.isCorrect,
    required this.experienceChange,
    required this.message,
    this.onRetry,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final Player? player = playerProvider.player;
    
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: isCorrect 
                  ? Colors.green.withAlpha(102)
                  : Colors.red.withAlpha(102),
                blurRadius: 10.0,
                offset: const Offset(0.0, 10.0),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 결과 아이콘
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 64.0,
                ),
                const SizedBox(height: 16.0),
                
                // 결과 제목
                Text(
                  isCorrect ? '정답입니다!' : '오답입니다!',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 8.0),
                
                // 메시지
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16.0),
                
                // 경험치 변화
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '경험치: ',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      experienceChange >= 0 
                        ? '+$experienceChange' 
                        : '$experienceChange',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: experienceChange >= 0 
                          ? Colors.green 
                          : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                
                // 플레이어 레벨 정보
                if (player != null) ...[
                  Divider(
                    color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                  const SizedBox(height: 8.0),
                  // 레벨 정보
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Lv. ${player.level}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  // 경험치 진행 상태
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${player.experience}/${player.requiredExperience} XP',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  // 경험치 바
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: player.experience / player.requiredExperience,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCorrect ? Colors.green : Colors.blue,
                      ),
                    ),
                  ),
                  // 다음 레벨까지 남은 경험치
                  Text(
                    '다음 레벨까지 ${player.requiredExperience - player.experience} XP',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                
                const SizedBox(height: 16.0),
                
                // 버튼 행
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onRetry != null) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          // ignore: unawaited_futures
                          soundService.playSound(SoundType.buttonClick);
                          onRetry?.call();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 풀기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                    ],
                    ElevatedButton.icon(
                      onPressed: () {
                        // ignore: unawaited_futures
                        soundService.playSound(SoundType.buttonClick);
                        onNext();
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('다음 문제'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 
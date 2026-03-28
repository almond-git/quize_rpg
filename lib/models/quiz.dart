import 'package:json_annotation/json_annotation.dart';

part 'quiz.g.dart';

@JsonSerializable()
class Quiz {
  final int id;
  final String question;
  final List<String> options; // 객관식 선택지
  final int correctOptionIndex; // 정답 인덱스
  final int difficulty; // 난이도 (1-5)
  final String category; // 카테고리
  final String? parentCategory; // 상위 카테고리
  final int experienceReward; // 맞출 때 얻는 경험치
  final int experiencePenalty; // 틀릴 때 잃는 경험치
  final String? imagePath; // 이미지 경로

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.difficulty,
    required this.category,
    this.parentCategory,
    required this.experienceReward,
    required this.experiencePenalty,
    this.imagePath,
  });

  // 정답 체크
  bool checkAnswer(int selectedIndex) {
    return selectedIndex == correctOptionIndex;
  }

  // JSON 직렬화
  factory Quiz.fromJson(Map<String, dynamic> json) => _$QuizFromJson(json);
  Map<String, dynamic> toJson() => _$QuizToJson(this);
}

@JsonSerializable()
class QuizHistory {
  final int quizId;
  final bool wasCorrect;
  final DateTime timestamp;

  QuizHistory({
    required this.quizId,
    required this.wasCorrect,
    required this.timestamp,
  });

  // JSON 직렬화
  factory QuizHistory.fromJson(Map<String, dynamic> json) =>
      _$QuizHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$QuizHistoryToJson(this);
}

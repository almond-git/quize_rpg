// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quiz _$QuizFromJson(Map<String, dynamic> json) => Quiz(
      id: (json['id'] as num).toInt(),
      question: json['question'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      correctOptionIndex: (json['correctOptionIndex'] as num).toInt(),
      difficulty: (json['difficulty'] as num).toInt(),
      category: json['category'] as String,
      experienceReward: (json['experienceReward'] as num).toInt(),
      experiencePenalty: (json['experiencePenalty'] as num).toInt(),
    );

Map<String, dynamic> _$QuizToJson(Quiz instance) => <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'options': instance.options,
      'correctOptionIndex': instance.correctOptionIndex,
      'difficulty': instance.difficulty,
      'category': instance.category,
      'experienceReward': instance.experienceReward,
      'experiencePenalty': instance.experiencePenalty,
    };

QuizHistory _$QuizHistoryFromJson(Map<String, dynamic> json) => QuizHistory(
      quizId: (json['quizId'] as num).toInt(),
      wasCorrect: json['wasCorrect'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$QuizHistoryToJson(QuizHistory instance) =>
    <String, dynamic>{
      'quizId': instance.quizId,
      'wasCorrect': instance.wasCorrect,
      'timestamp': instance.timestamp.toIso8601String(),
    };

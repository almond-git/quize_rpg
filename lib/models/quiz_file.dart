import 'dart:convert';

class QuizFile {
  final int id;
  final String name;
  final String content;
  final bool isActive;

  QuizFile({
    required this.id,
    required this.name,
    required this.content,
    this.isActive = true,
  });

  // 퀴즈 개수 계산
  int get quizCount {
    try {
      final json = jsonDecode(content);
      if (json is List) {
        return json.length;
      }
    } catch (_) {}
    return 0;
  }

  // 복사 메소드
  QuizFile copyWith({
    int? id,
    String? name,
    String? content,
    bool? isActive,
  }) {
    return QuizFile(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
    );
  }

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'isActive': isActive,
    };
  }

  // JSON에서 인스턴스 생성
  factory QuizFile.fromJson(Map<String, dynamic> json) {
    return QuizFile(
      id: json['id'],
      name: json['name'],
      content: json['content'],
      isActive: json['isActive'],
    );
  }
} 
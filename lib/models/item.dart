import 'package:json_annotation/json_annotation.dart';

part 'item.g.dart';

@JsonSerializable()
class Item {
  final int id;
  final String name;
  final String description;
  final String iconPath;
  final ItemType type;
  final int value; // 아이템 효과 값 (타입에 따라 다른 의미)
  final int price; // 상점에서의 가격

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.type,
    required this.value,
    required this.price,
  });

  // JSON 직렬화
  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
  Map<String, dynamic> toJson() => _$ItemToJson(this);
}

enum ItemType {
  hintCard,      // 힌트 카드: 객관식 문제에서 2개의 오답을 제거
  timeExtension, // 시간 연장: 시간제한 퀴즈에서 추가 시간 부여
  expBooster,    // 경험치 부스터: 일정 시간 동안 획득 경험치 2배
  shield,        // 방어막: 한 번의 오답을 무시하고 경험치 감소 방지
  retryChance,   // 재도전 기회: 틀린 문제를 바로 다시 풀 수 있는 기회
  topicChange,   // 주제 변경: 현재 어려운 주제를 다른 주제로 바꿀 수 있음
} 
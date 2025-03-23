import 'package:json_annotation/json_annotation.dart';

part 'player.g.dart';

@JsonSerializable()
class Player {
  int id;
  String name;
  int level;
  int experience;
  int requiredExperience;
  List<int> itemInventory; // 보유 아이템 ID 목록
  List<int> wrongQuestions; // 틀린 문제 ID 목록

  Player({
    this.id = 0,
    required this.name,
    this.level = 1,
    this.experience = 0,
    this.requiredExperience = 100,
    List<int>? itemInventory,
    List<int>? wrongQuestions,
  }) : 
    itemInventory = itemInventory ?? [],
    wrongQuestions = wrongQuestions ?? [];

  // 경험치 획득
  void gainExperience(int amount) {
    experience += amount;
    checkLevelUp();
  }

  // 경험치 감소
  void loseExperience(int amount) {
    experience -= amount;
    if (experience < 0) {
      experience = 0;
      if (level > 1) {
        level--;
        experience = requiredExperience ~/ 2; // 레벨 다운 시 이전 레벨의 50% 경험치에서 시작
        calculateRequiredExperience();
      }
    }
  }

  // 레벨업 체크
  bool checkLevelUp() {
    if (experience >= requiredExperience) {
      experience -= requiredExperience;
      level++;
      calculateRequiredExperience();
      return true;
    }
    return false;
  }

  // 필요 경험치 계산 (레벨에 따라 증가)
  void calculateRequiredExperience() {
    requiredExperience = 100 * level;
  }

  // 아이템 추가
  void addItem(int itemId) {
    itemInventory.add(itemId);
  }

  // 아이템 사용
  bool useItem(int itemId) {
    int index = itemInventory.indexOf(itemId);
    if (index != -1) {
      itemInventory.removeAt(index);
      return true;
    }
    return false;
  }

  // 틀린 문제 추가
  void addWrongQuestion(int questionId) {
    if (!wrongQuestions.contains(questionId)) {
      wrongQuestions.add(questionId);
    }
  }

  // 틀린 문제 제거 (맞게 답했을 때)
  void removeWrongQuestion(int questionId) {
    wrongQuestions.remove(questionId);
  }

  // JSON 직렬화
  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerToJson(this);
} 
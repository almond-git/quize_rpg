import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quiz_rpg/models/item.dart';

class ItemService {
  static final ItemService _instance = ItemService._internal();
  List<Item> _items = [];

  factory ItemService() {
    return _instance;
  }

  ItemService._internal();

  // 모든 아이템 불러오기
  Future<void> loadItems() async {
    if (_items.isNotEmpty) return;
    
    try {
      // assets 폴더에서 JSON 파일 로드
      final String jsonData = await rootBundle.loadString('assets/data/items.json');
      final List<dynamic> itemList = json.decode(jsonData);
      _items = itemList.map((json) => Item.fromJson(json)).toList();
    } catch (e) {
      debugPrint('아이템 데이터 로드 오류: $e');
      // 아이템 로드 실패 시 기본 더미 데이터 생성
      _generateDummyItems();
    }
  }

  // 테스트용 더미 아이템 생성
  void _generateDummyItems() {
    _items = [
      Item(
        id: 1,
        name: '힌트 카드',
        description: '객관식 문제에서 2개의 오답을 제거합니다.',
        iconPath: 'assets/images/items/hint_card.png',
        type: ItemType.hintCard,
        value: 2, // 제거할 오답 수
        price: 100,
      ),
      Item(
        id: 2,
        name: '시간 연장',
        description: '퀴즈 시간을 30초 추가합니다.',
        iconPath: 'assets/images/items/time_extension.png',
        type: ItemType.timeExtension,
        value: 30, // 추가 시간(초)
        price: 150,
      ),
      Item(
        id: 3,
        name: '경험치 부스터',
        description: '다음 퀴즈에서 획득하는 경험치가 2배가 됩니다.',
        iconPath: 'assets/images/items/exp_booster.png',
        type: ItemType.expBooster,
        value: 2, // 경험치 배수
        price: 200,
      ),
      Item(
        id: 4,
        name: '방어막',
        description: '한 번의 오답을 무시하고 경험치 감소를 방지합니다.',
        iconPath: 'assets/images/items/shield.png',
        type: ItemType.shield,
        value: 1, // 방어 횟수
        price: 250,
      ),
      Item(
        id: 5,
        name: '재도전 기회',
        description: '틀린 문제를 바로 다시 풀 수 있는 기회를 제공합니다.',
        iconPath: 'assets/images/items/retry_chance.png',
        type: ItemType.retryChance,
        value: 1, // 재도전 횟수
        price: 200,
      ),
      Item(
        id: 6,
        name: '주제 변경',
        description: '현재 주제를 다른 주제로 변경합니다.',
        iconPath: 'assets/images/items/topic_change.png',
        type: ItemType.topicChange,
        value: 1, // 변경 횟수
        price: 150,
      ),
    ];
  }

  // 모든 아이템 가져오기
  Future<List<Item>> getAllItems() async {
    await loadItems();
    return _items;
  }

  // ID로 아이템 가져오기
  Future<Item?> getItemById(int id) async {
    await loadItems();
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  // 여러 ID로 아이템 목록 가져오기
  Future<List<Item>> getItemsByIds(List<int> ids) async {
    await loadItems();
    return _items.where((item) => ids.contains(item.id)).toList();
  }

  // 아이템 유형별 가져오기
  Future<List<Item>> getItemsByType(ItemType type) async {
    await loadItems();
    return _items.where((item) => item.type == type).toList();
  }
} 
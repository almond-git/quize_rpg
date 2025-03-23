import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiz_rpg/models/player.dart';
import 'package:quiz_rpg/models/item.dart';
import 'package:quiz_rpg/services/database_service.dart';
import 'package:quiz_rpg/services/item_service.dart';

class PlayerProvider with ChangeNotifier {
  Player? _player;
  final DatabaseService _databaseService = DatabaseService();
  final ItemService _itemService = ItemService();
  
  // 레벨업/다운 이벤트 관련 상태
  bool _isLevelingUp = false;
  bool _isLevelingDown = false;
  
  // 아이템 효과 상태
  bool _expBoosterActive = false;
  bool _shieldActive = false;
  bool _initialized = false;
  bool _initializing = false;
  
  // 게터
  Player? get player => _player;
  bool get isLevelingUp => _isLevelingUp;
  bool get isLevelingDown => _isLevelingDown;
  bool get expBoosterActive => _expBoosterActive;
  bool get shieldActive => _shieldActive;
  
  // 초기화 메서드
  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    
    try {
      // 기존 플레이어 목록이 있는지 확인
      final players = await _databaseService.getAllPlayers();
      
      // 플레이어가 없는 경우 초기화 완료 상태만 설정(플레이어 생성 화면으로 넘어가도록)
      if (players.isEmpty) {
        _initialized = true;
        _initializing = false;
        _safeNotifyListeners();
        return;
      }
      
      // 웹 환경에서는 기본 플레이어 생성
      if (kIsWeb && _player == null) {
        _player = Player(
          id: 1,
          name: "웹 플레이어",
          level: 1,
          experience: 0,
          requiredExperience: 100,
          itemInventory: [1, 2, 3],
          wrongQuestions: [],
        );
        _initialized = true;
        _initializing = false;
        
        // 빌드 사이클 이후에 상태 업데이트 알림
        _safeNotifyListeners();
        return;
      }
      
      // 자동으로 플레이어를 로드하지 않도록 변경 (선택 다이얼로그에서 처리)
      _initialized = true;
      _initializing = false;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('플레이어 초기화 오류: $e');
      // 오류 발생 시에도 초기화 완료 상태로 설정
      _initialized = true;
      _initializing = false;
      _safeNotifyListeners();
    }
  }
  
  // 안전하게 notifyListeners 호출
  void _safeNotifyListeners() {
    // 항상 빌드 사이클 이후에 실행되도록 변경
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!SchedulerBinding.instance.hasScheduledFrame) {
        notifyListeners();
      } else {
        // 이미 프레임이 예약되어 있으면 다음 프레임 이후에 실행
        SchedulerBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    });
  }
  
  // 새 플레이어 생성
  Future<void> createNewPlayer(String name) async {
    debugPrint('PlayerProvider: 새 플레이어 생성 시작: $name');
    
    try {
      // 지연 시간을 줘서 UI 상태 변경이 먼저 이루어지도록 함
      await Future.delayed(const Duration(milliseconds: 100));
      
      _player = Player(name: name);
      
      try {
        int id = await _databaseService.insertPlayer(_player!);
        _player!.id = id;
        debugPrint('PlayerProvider: 새 플레이어 생성 완료 (ID: ${_player!.id})');
      } catch (e) {
        debugPrint('PlayerProvider: 플레이어 DB 저장 오류: $e');
        // 웹 환경이나 오류 시 기본 ID 설정
        _player!.id = 1;
      }
      
      _initialized = true;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('PlayerProvider: 플레이어 생성 오류: $e');
      throw Exception('플레이어 생성 중 오류 발생: $e');
    }
  }
  
  // 경험치 획득
  Future<bool> gainExperience(int amount) async {
    if (_player == null) return false;
    
    // 경험치 부스터 효과 적용
    if (_expBoosterActive) {
      amount *= 2;
      _expBoosterActive = false; // 한 번 사용하면 효과 소멸
    }
    
    // 경험치 획득 및 레벨업 체크
    int oldLevel = _player!.level;
    _player!.gainExperience(amount);
    
    // 플레이어 상태 저장
    try {
      await _databaseService.updatePlayer(_player!);
    } catch (e) {
      debugPrint('플레이어 업데이트 오류: $e');
    }
    
    // 레벨업 애니메이션 처리
    bool leveledUp = _player!.level > oldLevel;
    if (leveledUp) {
      _isLevelingUp = true;
      _safeNotifyListeners();
      
      // 애니메이션 시간 후 상태 초기화
      await Future.delayed(const Duration(seconds: 2));
      _isLevelingUp = false;
      _safeNotifyListeners();
    } else {
      _safeNotifyListeners();
    }
    
    return leveledUp;
  }
  
  // 경험치 감소
  Future<bool> loseExperience(int amount) async {
    if (_player == null) return false;
    
    // 방어막 효과 적용
    if (_shieldActive) {
      _shieldActive = false; // 한 번 사용하면 효과 소멸
      _safeNotifyListeners();
      return false;
    }
    
    // 경험치 감소 및 레벨 다운 체크
    int oldLevel = _player!.level;
    _player!.loseExperience(amount);
    
    // 플레이어 상태 저장
    try {
      await _databaseService.updatePlayer(_player!);
    } catch (e) {
      debugPrint('플레이어 업데이트 오류: $e');
    }
    
    // 레벨 다운 애니메이션 처리
    bool leveledDown = _player!.level < oldLevel;
    if (leveledDown) {
      _isLevelingDown = true;
      _safeNotifyListeners();
      
      // 애니메이션 시간 후 상태 초기화
      await Future.delayed(const Duration(seconds: 2));
      _isLevelingDown = false;
      _safeNotifyListeners();
    } else {
      _safeNotifyListeners();
    }
    
    return leveledDown;
  }
  
  // 틀린 문제 추가
  Future<void> addWrongQuestion(int questionId) async {
    if (_player == null) return;
    
    _player!.addWrongQuestion(questionId);
    try {
      await _databaseService.updatePlayer(_player!);
    } catch (e) {
      debugPrint('틀린 문제 추가 오류: $e');
    }
    _safeNotifyListeners();
  }
  
  // 틀린 문제 제거
  Future<void> removeWrongQuestion(int questionId) async {
    if (_player == null) return;
    
    _player!.removeWrongQuestion(questionId);
    try {
      await _databaseService.updatePlayer(_player!);
    } catch (e) {
      debugPrint('틀린 문제 제거 오류: $e');
    }
    _safeNotifyListeners();
  }
  
  // 아이템 추가
  Future<void> addItem(int itemId) async {
    if (_player == null) return;
    
    _player!.addItem(itemId);
    try {
      await _databaseService.updatePlayer(_player!);
    } catch (e) {
      debugPrint('아이템 추가 오류: $e');
    }
    _safeNotifyListeners();
  }
  
  // 아이템 사용
  Future<bool> useItem(int itemId) async {
    if (_player == null) return false;
    
    // 아이템 존재 여부 확인
    if (!_player!.useItem(itemId)) return false;
    
    // 아이템 효과 적용
    Item? item = await _itemService.getItemById(itemId);
    if (item == null) return false;
    
    switch (item.type) {
      case ItemType.expBooster:
        _expBoosterActive = true;
        break;
      case ItemType.shield:
        _shieldActive = true;
        break;
      // 다른 아이템 타입은 외부에서 처리
      default:
        break;
    }
    
    // 플레이어 상태 저장
    try {
      await _databaseService.updatePlayer(_player!);
    } catch (e) {
      debugPrint('아이템 사용 후 플레이어 업데이트 오류: $e');
    }
    
    _safeNotifyListeners();
    return true;
  }
  
  // 아이템 목록 가져오기
  Future<List<Item>> getInventoryItems() async {
    if (_player == null) return [];
    return await _itemService.getItemsByIds(_player!.itemInventory);
  }
  
  // 플레이어 선택 메서드
  Future<void> selectPlayer(int id) async {
    debugPrint('PlayerProvider: 플레이어($id) 선택 시작');
    
    try {
      // 지연 시간을 줘서 UI 상태 변경이 먼저 이루어지도록 함
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 플레이어 정보 로드
      final player = await _databaseService.getPlayer(id);
      if (player == null) {
        debugPrint('PlayerProvider: 플레이어($id) 정보를 찾을 수 없음');
        throw Exception('플레이어 정보를 찾을 수 없습니다.');
      }
      
      _player = player;
      _initialized = true;
      
      debugPrint('PlayerProvider: 플레이어(${_player?.name}) 선택 완료');
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('PlayerProvider: 플레이어 선택 오류: $e');
      throw Exception('플레이어 선택 중 오류 발생: $e');
    }
  }
  
  // 플레이어 삭제 메서드
  Future<bool> deletePlayer(int id) async {
    debugPrint('PlayerProvider: 플레이어($id) 삭제 시작');
    
    try {
      // 현재 선택된 플레이어를 삭제하는 경우
      if (_player != null && _player!.id == id) {
        _player = null;
      }
      
      // 지연 시간을 줘서 UI 상태 변경이 먼저 이루어지도록 함
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 데이터베이스에서 플레이어 삭제
      final result = await _databaseService.deletePlayer(id);
      
      debugPrint('PlayerProvider: 플레이어($id) 삭제 완료, 결과: $result');
      _safeNotifyListeners();
      return result > 0;
    } catch (e) {
      debugPrint('PlayerProvider: 플레이어 삭제 오류: $e');
      return false;
    }
  }
} 
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 전역 인스턴스를 제공하여 싱글톤 패턴을 강화
// 지연 초기화로 변경하여 시작 시점에 올바르게 초기화되도록 함
late final SoundService soundService;

// 앱 시작시 호출하여 soundService를 초기화
Future<void> initSoundService() async {
  soundService = SoundService();
  await soundService.initialize();
  debugPrint('사운드 서비스 초기화 완료');
}

enum SoundType {
  buttonClick,
  quizCorrect,
  quizWrong,
  levelUp,
  levelDown, // 레벨 다운 사운드 추가
  itemUse,
  timeLow, // 시간 부족 경고음 추가
  gameWin, // 게임 승리 사운드 추가
}

class SoundService {
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _isSoundEnabled = true;
  double _soundVolume = 1.0;
  bool _isWebInitialized = false;
  bool _isInitialized = false;

  // 사운드 파일 맵핑
  final Map<SoundType, String> _soundFiles = {
    SoundType.buttonClick: 'button_click.mp3',
    SoundType.quizCorrect: 'correct_answer.mp3',
    SoundType.quizWrong: 'wrong_answer.mp3',
    SoundType.levelUp: 'level_up.mp3',
    SoundType.levelDown: 'level_down.mp3',
    SoundType.itemUse: 'item_use.mp3',
    SoundType.timeLow: 'time_low.wav',
    SoundType.gameWin: 'game_win.mp3',
  };

  SoundService() {
    debugPrint('SoundService 생성됨');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('SoundService 초기화 시작');
    await _initAudioPlayers();
    await _loadSettings();
    _isInitialized = true;
    debugPrint('SoundService 초기화 완료');

    // 빈 사운드 재생을 통해 오디오 시스템 워밍업
    await playSound(SoundType.buttonClick);
  }

  // 오디오 플레이어 초기화
  Future<void> _initAudioPlayers() async {
    await _effectPlayer.setReleaseMode(ReleaseMode.release);
    await _effectPlayer.setVolume(_soundVolume);

    // 웹 환경일 경우 초기화 로그 출력
    if (kIsWeb) {
      debugPrint('웹 환경에서 오디오 플레이어 초기화');
      // 웹에서는 AudioCache가 필요 없으므로 기본 설정만 유지
      await _effectPlayer.setPlayerMode(PlayerMode.lowLatency);
    }
  }

  // 웹 환경을 위한 사운드 파일 사전 로딩
  Future<void> _preloadWebSounds() async {
    if (!kIsWeb || _isWebInitialized) return;

    try {
      // 웹에서는 첫 사용자 상호작용 이후 사전 로드
      debugPrint('웹 환경에서 사운드 파일 사전 로드 시작');
      _isWebInitialized = true;

      // 개별 사운드를 사전 로드할 필요가 있으면 여기에 코드 추가
    } catch (e) {
      debugPrint('웹 사운드 사전 로드 오류: $e');
    }
  }

  // 설정 불러오기
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSoundEnabled = prefs.getBool('sound_enabled') ?? true;
      _soundVolume = prefs.getDouble('sound_volume') ?? 1.0;

      // 볼륨 적용
      await _effectPlayer.setVolume(_soundVolume);
    } catch (e) {
      debugPrint('사운드 설정 로드 오류: $e');
    }
  }

  // 설정 저장하기
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', _isSoundEnabled);
      await prefs.setDouble('sound_volume', _soundVolume);
    } catch (e) {
      debugPrint('사운드 설정 저장 오류: $e');
    }
  }

  // 효과음 재생
  Future<void> playSound(SoundType type) async {
    if (!_isSoundEnabled) return;

    try {
      // 웹 환경에서 첫 상호작용 시 초기화
      if (kIsWeb && !_isWebInitialized) {
        await _preloadWebSounds();
      }

      final soundFile = _soundFiles[type];
      if (soundFile == null) {
        debugPrint('알 수 없는 효과음 타입: $type');
        return;
      }

      debugPrint('효과음 재생 시도: $type, 파일: $soundFile');

      // 일단 현재 재생 중인 사운드를 중지
      await _effectPlayer.stop();

      // 경로 구성
      String soundPath =
          kIsWeb ? 'assets/sounds/$soundFile' : 'sounds/$soundFile';

      try {
        // 첫 번째 방법으로 재생 시도
        await _effectPlayer.play(AssetSource(soundPath));
        debugPrint('효과음 재생 성공: $soundPath');
      } catch (e) {
        debugPrint('효과음 재생 첫 번째 방법 실패, 두 번째 방법 시도: $e');
        try {
          // 두 번째 방법: 바이트로 직접 로드하여 재생
          final audioBytes = await rootBundle.load('assets/sounds/$soundFile');
          await _effectPlayer
              .play(BytesSource(audioBytes.buffer.asUint8List()));
          debugPrint('효과음 재생 두 번째 방법 성공');
        } catch (e2) {
          debugPrint('효과음 재생 최종 실패: $e2');
          // 세 번째 방법: 절대 경로 시도 (웹에서는 작동하지 않음)
          if (!kIsWeb) {
            try {
              await _effectPlayer
                  .play(AssetSource('/assets/sounds/$soundFile'));
              debugPrint('효과음 재생 세 번째 방법 성공');
            } catch (e3) {
              debugPrint('모든 효과음 재생 방법 실패: $e3');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('효과음 재생 오류: $e');
    }
  }

  // 모든 소리 중지
  Future<void> stopAllSounds() async {
    await _effectPlayer.stop();
  }

  // 효과음 활성화/비활성화
  Future<void> setSoundEnabled(bool enabled) async {
    _isSoundEnabled = enabled;
    await _saveSettings();
  }

  // 효과음 볼륨 설정
  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume;
    await _effectPlayer.setVolume(volume);
    await _saveSettings();
  }

  // 효과음 직접 테스트
  Future<void> testAllSounds() async {
    if (!_isSoundEnabled) return;

    // 웹에서는 이벤트로 사운드 재생 초기화
    if (kIsWeb) {
      await _preloadWebSounds();
    }

    // 버튼 클릭 효과음만 테스트 (나머지는 필요시 추가)
    await playSound(SoundType.buttonClick);
    await Future.delayed(const Duration(milliseconds: 500));
    await playSound(SoundType.quizCorrect);
  }

  // Getters
  bool get isSoundEnabled => _isSoundEnabled;
  double get soundVolume => _soundVolume;
}

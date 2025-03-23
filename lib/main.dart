import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/providers/quiz_file_provider.dart';
import 'package:quiz_rpg/screens/home_screen.dart';
import 'package:quiz_rpg/services/quiz_service.dart';
import 'package:quiz_rpg/services/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 웹 환경에서의 초기화
  if (kIsWeb) {
    debugPrint('웹 환경에서 실행 중입니다. 로컬 데이터베이스는 사용할 수 없습니다.');
  }
  
  // 사운드 서비스 초기화
  final _ = soundService;
  
  // 사운드 파일 확인
  debugPrint('사운드 파일 테스트 - 다음 파일들이 assets/sounds/ 디렉토리에 존재해야 합니다:');
  debugPrint('- button_click.mp3');
  debugPrint('- correct_answer.mp3');
  debugPrint('- wrong_answer.mp3');
  debugPrint('- level_up.mp3');
  debugPrint('- level_down.mp3');
  debugPrint('- item_use.mp3');
  
  // 웹에서도 사운드가 재생되도록 설정
  debugPrint('웹 환경에서도 사운드가 재생되도록 설정되었습니다.');
  
  // 앱 시작 시 효과음 재생 테스트 (3초 후)
  Timer(const Duration(seconds: 3), () {
    soundService.playSound(SoundType.buttonClick);
    debugPrint('시작 효과음 재생 시도 - buttonClick');
  });
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;
  
  @override
  void initState() {
    super.initState();
    
    // 스플래시 화면 표시 시간 (3초)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
        // 스플래시 화면이 사라질 때 효과음 재생
        // ignore: unawaited_futures
        soundService.playSound(SoundType.buttonClick);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final playerProvider = PlayerProvider();
            // 앱 시작 시 초기화 (플레이어 선택 다이얼로그를 위해)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              playerProvider.initialize();
            });
            return playerProvider;
          }
        ),
        ChangeNotifierProvider(
          create: (_) {
            final quizFileProvider = QuizFileProvider();
            
            // QuizService와 연결
            WidgetsBinding.instance.addPostFrameCallback((_) {
              QuizService().setQuizFileProvider(quizFileProvider);
            });
            
            return quizFileProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: '골든벨',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: _showSplash ? const SplashScreen() : const HomeScreen(),
      ),
    );
  }
}

// 스플래시 화면 위젯
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 또는 아이콘
            const Icon(
              Icons.quiz,
              size: 100,
              color: Colors.white,
            ),
            
            const SizedBox(height: 20),
            
            // 앱 이름
            const Text(
              '골든벨',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 로딩 인디케이터
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            
            const SizedBox(height: 20),
            
            // 버전 정보
            const Text(
              '버전 1.0.0',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

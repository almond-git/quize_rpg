import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/screens/quiz_screen.dart';
import 'package:quiz_rpg/screens/inventory_screen.dart';
import 'package:quiz_rpg/screens/settings_screen.dart';
import 'package:quiz_rpg/services/quiz_service.dart';
import 'package:quiz_rpg/services/sound_service.dart';
import 'package:quiz_rpg/widgets/player_status_card.dart';
import 'package:quiz_rpg/widgets/player_selection_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final QuizService _quizService = QuizService();
  List<String> _categories = [];
  bool _isLoading = true;
  bool _playerInitialized = false;
  bool _showDetailedStats = false; // 상세 통계 표시 여부
  // 다이얼로그 표시 중인지 추적하는 변수
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    
    // initState에서 한 번만 초기화 작업 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_playerInitialized) {
        _initializePlayer(context);
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _quizService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('카테고리 로드 오류: $e');
    }
  }

  // 플레이어 초기화
  Future<void> _initializePlayer(BuildContext context) async {
    // 이미 초기화 중이거나 완료된 경우 무시
    if (_playerInitialized) return;
    
    debugPrint('플레이어 초기화 시작');
    // 플레이어 선택 다이얼로그 표시
    await _showPlayerSelectionDialog(context);
  }
  
  // 플레이어 선택 다이얼로그 표시
  Future<void> _showPlayerSelectionDialog(BuildContext context) async {
    // 이미 다이얼로그가 표시 중이면 무시
    if (_isShowingDialog) {
      debugPrint('이미 다이얼로그 표시 중');
      return;
    }
    
    _isShowingDialog = true;
    debugPrint('플레이어 선택 다이얼로그 표시 시작');
    
    try {
      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return PlayerSelectionDialog(
            onPlayerSelected: () {
              debugPrint('플레이어 선택 완료 콜백');
              if (mounted) {
                setState(() {
                  _playerInitialized = true;
                });
              }
            },
          );
        },
      );
      
      debugPrint('다이얼로그 결과: $result');
      // 다이얼로그가 정상적으로 닫힌 경우에만 상태 업데이트
      if (mounted) {
        setState(() {
          _playerInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('플레이어 선택 다이얼로그 오류: $e');
    } finally {
      // 다이얼로그 표시 상태 복원
      _isShowingDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('골든벨'),
        actions: [
          // 플레이어 선택 버튼
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _isShowingDialog ? null : () {
              // ignore: unawaited_futures
              soundService.playSound(SoundType.buttonClick);
              _showPlayerSelectionDialog(context);
            },
          ),
          // 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // ignore: unawaited_futures
              soundService.playSound(SoundType.buttonClick);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(),
                ),
              );
            },
          ),
          // 인벤토리 버튼
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () {
              // ignore: unawaited_futures
              soundService.playSound(SoundType.buttonClick);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InventoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 플레이어 상태 카드
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: () {
                      // 카드를 탭하면 상세 통계 표시 전환
                      // ignore: unawaited_futures
                      soundService.playSound(SoundType.buttonClick);
                      setState(() {
                        _showDetailedStats = !_showDetailedStats;
                      });
                    },
                    child: PlayerStatusCard(
                      player: playerProvider.player,
                      showDetailedStats: _showDetailedStats,
                    ),
                  ),
                ),
                
                // 빠른 퀴즈 시작 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // ignore: unawaited_futures
                      soundService.playSound(SoundType.buttonClick);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuizScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      '랜덤 퀴즈 시작',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 카테고리 제목
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.category),
                      const SizedBox(width: 8),
                      const Text(
                        '카테고리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_categories.length}개',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 카테고리 그리드
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return InkWell(
                        onTap: () {
                          // ignore: unawaited_futures
                          soundService.playSound(SoundType.buttonClick);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                category: category,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor.withAlpha(51),
                                  Theme.of(context).primaryColor.withAlpha(102),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getCategoryIcon(category),
                                    size: 36.0,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case '역사':
        return Icons.history_edu;
      case '과학':
        return Icons.science;
      case '문학':
        return Icons.book;
      case '예술':
        return Icons.palette;
      case '지리':
        return Icons.public;
      case '스포츠':
        return Icons.sports_soccer;
      case '음악':
        return Icons.music_note;
      case '영화':
        return Icons.movie;
      case '기술':
        return Icons.computer;
      case '게임':
        return Icons.videogame_asset;
      default:
        return Icons.quiz;
    }
  }
} 
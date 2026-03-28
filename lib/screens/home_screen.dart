import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/screens/quiz_screen.dart';
import 'package:quiz_rpg/screens/inventory_screen.dart';
import 'package:quiz_rpg/screens/settings_screen.dart';
import 'package:quiz_rpg/services/quiz_service.dart';
import 'package:quiz_rpg/services/sound_service.dart';
import 'package:quiz_rpg/services/preference_service.dart';
import 'package:quiz_rpg/widgets/player_status_card.dart';
import 'package:quiz_rpg/widgets/player_selection_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final QuizService _quizService = QuizService();
  final PreferenceService _preferenceService = PreferenceService();
  List<String> _parentCategories = [];
  Map<String, List<String>> _subCategories = {};
  String? _selectedParentCategory;
  bool _isLoading = true;
  bool _playerInitialized = false;
  bool _showDetailedStats = false; // 상세 통계 표시 여부
  // 다이얼로그 표시 중인지 추적하는 변수
  bool _isShowingDialog = false;
  // 완료된 카테고리 목록
  List<String> _completedCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadCompletedCategories(); // 완료된 카테고리 로드

    // initState에서 한 번만 초기화 작업 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_playerInitialized) {
        _initializePlayer(context);
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 상위 카테고리 로드
      final parentCategories = await _quizService.getParentCategories();

      // 각 상위 카테고리별 하위 카테고리 로드
      Map<String, List<String>> subCategories = {};
      for (var parent in parentCategories) {
        final subCats = await _quizService.getSubCategories(parent);
        subCategories[parent] = subCats;
      }

      setState(() {
        _parentCategories = parentCategories;
        _subCategories = subCategories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('카테고리 로드 오류: $e');
    }
  }

  // 완료된 카테고리 로드
  Future<void> _loadCompletedCategories() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final playerId = playerProvider.player?.id ?? 0;

    if (playerId > 0) {
      final completedCats =
          await _preferenceService.getCompletedCategories(playerId);

      if (mounted) {
        setState(() {
          _completedCategories = completedCats;
          debugPrint('완료된 카테고리 업데이트: $_completedCategories');
        });
      }
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
            onPressed: _isShowingDialog
                ? null
                : () {
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
                        _selectedParentCategory == null
                            ? '${_parentCategories.length}개'
                            : '${_subCategories[_selectedParentCategory]?.length ?? 0}개',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // 뒤로가기 버튼 (하위 카테고리 보기 중일 때만 표시)
                if (_selectedParentCategory != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 6.0),
                    child: Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back, size: 14),
                          label: const Text('상위 카테고리로 돌아가기',
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                          ),
                          onPressed: () {
                            // ignore: unawaited_futures
                            soundService.playSound(SoundType.buttonClick);
                            setState(() {
                              _selectedParentCategory = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // 카테고리 그리드
                Expanded(
                  child: _selectedParentCategory == null
                      ? _buildParentCategoriesGrid() // 상위 카테고리 표시
                      : _buildSubCategoriesGrid(), // 하위 카테고리 표시
                ),
              ],
            ),
    );
  }

  // 상위 카테고리 그리드 위젯
  Widget _buildParentCategoriesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _parentCategories.length,
      itemBuilder: (context, index) {
        final category = _parentCategories[index];
        return InkWell(
          onTap: () {
            // ignore: unawaited_futures
            soundService.playSound(SoundType.buttonClick);
            setState(() {
              _selectedParentCategory = category;
            });
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    const SizedBox(height: 4),
                    Text(
                      '${_subCategories[category]?.length ?? 0}개 카테고리',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
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
    );
  }

  // 하위 카테고리 그리드 위젯
  Widget _buildSubCategoriesGrid() {
    if (_selectedParentCategory == null) {
      return const Center(child: Text('선택된 카테고리가 없습니다.'));
    }

    final subCats = _subCategories[_selectedParentCategory] ?? [];

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: subCats.length,
      itemBuilder: (context, index) {
        final category = subCats[index];
        final isCompleted = _completedCategories.contains(category);

        return InkWell(
          onTap: () async {
            // ignore: unawaited_futures
            soundService.playSound(SoundType.buttonClick);

            // 퀴즈 화면으로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizScreen(
                  category: category,
                ),
              ),
            );

            // 퀴즈 화면에서 돌아온 후에 완료된 카테고리를 다시 로드
            if (mounted) {
              await _loadCompletedCategories();
              setState(() {
                // UI 강제 업데이트
              });
            }
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                  if (isCompleted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case '구구단':
        return Icons.calculate;
      case '나라 맞히기':
        return Icons.public;
      case '구구단 1단':
      case '구구단 2단':
      case '구구단 3단':
      case '구구단 4단':
      case '구구단 5단':
      case '구구단 6단':
      case '구구단 7단':
      case '구구단 8단':
      case '구구단 9단':
        return Icons.calculate;
      case '나라 수도 맞히기':
        return Icons.location_city;
      case '나라 국기 맞히기':
        return Icons.flag;
      case '역사':
        return Icons.history_edu;
      case '한국사':
        return Icons.temple_buddhist;
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

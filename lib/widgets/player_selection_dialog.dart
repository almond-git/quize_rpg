import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quiz_rpg/providers/player_provider.dart';
import 'package:quiz_rpg/models/player.dart';
import 'package:quiz_rpg/services/preference_service.dart';
import 'package:quiz_rpg/services/sound_service.dart';

class PlayerSelectionDialog extends StatefulWidget {
  final Function onPlayerSelected;

  const PlayerSelectionDialog({
    super.key,
    required this.onPlayerSelected,
  });

  @override
  State<PlayerSelectionDialog> createState() => _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<PlayerSelectionDialog> {
  final PreferenceService _preferenceService = PreferenceService();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  List<Player> _players = [];
  bool _isLoading = true;
  bool _isCreatingNewPlayer = false;
  bool _isSelecting = false;
  int? _selectedPlayerId;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    try {
      final players = await _preferenceService.getPlayers();
      setState(() {
        _players = players;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('플레이어 목록 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewPlayer() async {
    if (kIsWeb) {
      _nameFocusNode.unfocus();
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }

    if (_isSelecting) {
      debugPrint('이미 플레이어 생성 진행 중');
      return;
    }

    debugPrint('플레이어 생성 시작: ${_nameController.text}');

    setState(() {
      _isSelecting = true;
    });

    // 효과음 재생
    // ignore: unawaited_futures
    soundService.playSound(SoundType.buttonClick);

    try {
      final playerProvider = context.read<PlayerProvider>();

      // 생성 작업 수행 전 딜레이
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint('Provider에 플레이어 생성 요청 시작');
      await playerProvider.createNewPlayer(_nameController.text);
      debugPrint('Provider에 플레이어 생성 완료');

      // 우선 콜백 호출로 상태 업데이트
      if (!mounted) {
        debugPrint('위젯이 마운트 해제됨');
        return;
      }

      widget.onPlayerSelected();

      debugPrint('다이얼로그 닫기 시도 (생성)');
      // 즉시 다이얼로그 닫기 시도
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('플레이어 생성 오류: $e');
      if (!mounted) return;

      setState(() {
        _isSelecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('플레이어 생성 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _selectPlayer(Player player) async {
    if (kIsWeb) {
      _nameFocusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.clearClient');
    }

    if (_isSelecting) {
      debugPrint('이미 플레이어 선택 진행 중');
      return;
    }

    debugPrint('플레이어 선택 시작: ${player.name} (ID: ${player.id})');

    setState(() {
      _isSelecting = true;
      _selectedPlayerId = player.id;
    });

    // 효과음 재생
    // ignore: unawaited_futures
    soundService.playSound(SoundType.buttonClick);

    try {
      final playerProvider = context.read<PlayerProvider>();

      // 선택 작업 수행 전 딜레이
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint('Provider에 플레이어 선택 요청 시작');
      await playerProvider.selectPlayer(player.id);
      debugPrint('Provider에 플레이어 선택 완료');

      // 우선 콜백 호출로 상태 업데이트
      if (!mounted) {
        debugPrint('위젯이 마운트 해제됨');
        return;
      }

      widget.onPlayerSelected();

      debugPrint('다이얼로그 닫기 시도 (선택)');
      // 즉시 다이얼로그 닫기 시도
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('플레이어 선택 오류: $e');
      if (!mounted) return;

      setState(() {
        _isSelecting = false;
        _selectedPlayerId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('플레이어 선택 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 플레이어 삭제 확인 다이얼로그 표시
  void _confirmDeletePlayer(Player player) async {
    // 웹 환경에서 포커스 문제 해결
    if (kIsWeb) {
      _nameFocusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.clearClient');
    }

    // 버튼 클릭 사운드 재생
    // ignore: unawaited_futures
    soundService.playSound(SoundType.buttonClick);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('플레이어 삭제'),
          content: Text('${player.name} 플레이어를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                // ignore: unawaited_futures
                soundService.playSound(SoundType.buttonClick);
                Navigator.of(context).pop(false);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                // ignore: unawaited_futures
                soundService.playSound(SoundType.buttonClick);
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isSelecting = true;
      });

      try {
        if (!mounted) return;
        // 비동기 작업 전에 접근하여 컨텍스트 참조를 미리 저장
        final playerProvider = context.read<PlayerProvider>();
        final playerName = player.name; // 비동기 작업 전에 필요한 데이터 저장

        // PlayerProvider의 deletePlayer 메서드 사용 (PreferenceService를 내부적으로 사용함)
        final bool success = await playerProvider.deletePlayer(player.id);

        if (!mounted) return;

        if (success) {
          // 플레이어 목록 다시 로드
          await _loadPlayers();

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$playerName 플레이어가 삭제되었습니다.')),
          );
        } else {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('플레이어 삭제에 실패했습니다.')),
          );
        }
      } catch (e) {
        debugPrint('플레이어 삭제 오류: $e');
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이어 삭제 중 오류가 발생했습니다: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSelecting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isCreatingNewPlayer
                ? _buildNewPlayerForm()
                : _buildPlayerSelection(),
      ),
    );
  }

  Widget _buildPlayerSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '플레이어 선택',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        _players.isEmpty
            ? const Text('등록된 플레이어가 없습니다.')
            : Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _players.length,
                  itemBuilder: (context, index) {
                    final player = _players[index];
                    final bool isSelected = _selectedPlayerId == player.id;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(player.name.substring(0, 1)),
                      ),
                      title: Text(player.name),
                      subtitle: Text('Lv.${player.level}'),
                      trailing: isSelected
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _isSelecting
                                  ? null
                                  : () => _confirmDeletePlayer(player),
                            ),
                      selected: isSelected,
                      onTap: _isSelecting ? null : () => _selectPlayer(player),
                    );
                  },
                ),
              ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            // ignore: unawaited_futures
            soundService.playSound(SoundType.buttonClick);
            setState(() {
              _isCreatingNewPlayer = true;
            });
          },
          child: const Text('새 플레이어 만들기'),
        ),
      ],
    );
  }

  Widget _buildNewPlayerForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '새 플레이어 만들기',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        AutofillGroup(
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            decoration: const InputDecoration(
              labelText: '플레이어 이름',
              border: OutlineInputBorder(),
            ),
            maxLength: 10,
            autofocus: true,
            enabled: !_isSelecting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (kIsWeb) {
                _nameFocusNode.unfocus();
              }
              if (!_isSelecting) {
                _createNewPlayer();
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: _isSelecting
                  ? null
                  : () {
                      if (kIsWeb) {
                        _nameFocusNode.unfocus();
                      }
                      // ignore: unawaited_futures
                      soundService.playSound(SoundType.buttonClick);
                      setState(() {
                        _isCreatingNewPlayer = false;
                        _isSelecting = false;
                      });
                    },
              child: const Text('취소'),
            ),
            _isSelecting
                ? const ElevatedButton(
                    onPressed: null,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _createNewPlayer,
                    child: const Text('생성'),
                  ),
          ],
        ),
      ],
    );
  }
}

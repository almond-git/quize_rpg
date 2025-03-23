import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:quiz_rpg/providers/quiz_file_provider.dart';
import 'package:quiz_rpg/models/quiz_file.dart';
import 'package:quiz_rpg/services/sound_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useAllQuizFiles = false;
  // 사운드 설정 상태
  bool _isSoundEnabled = true;
  double _soundVolume = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final quizFileProvider = Provider.of<QuizFileProvider>(context, listen: false);
      setState(() {
        _useAllQuizFiles = quizFileProvider.useAllFiles;
        _isSoundEnabled = soundService.isSoundEnabled;
        _soundVolume = soundService.soundVolume;
      });
    });
  }

  // 사운드 설정 저장
  Future<void> _updateSoundSettings() async {
    await soundService.setSoundEnabled(_isSoundEnabled);
    await soundService.setSoundVolume(_soundVolume);
    
    // 설정 변경 효과음 재생
    if (_isSoundEnabled) {
      // ignore: unawaited_futures
      soundService.playSound(SoundType.buttonClick);
    }
  }

  // 퀴즈 파일 가져오기
  Future<void> _importQuizFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (!mounted) return;
      
      if (result != null && result.files.isNotEmpty) {
        // 웹에서는 바이트 데이터 처리
        if (kIsWeb) {
          final bytes = result.files.first.bytes;
          if (bytes == null) {
            _showErrorSnackbar('파일을 읽을 수 없습니다.');
            return;
          }
          
          final jsonString = String.fromCharCodes(bytes);
          _processQuizFile(jsonString, result.files.first.name);
        } 
        // 모바일/데스크톱에서는 파일 경로 처리
        else {
          final path = result.files.first.path;
          if (path == null) {
            _showErrorSnackbar('파일을 읽을 수 없습니다.');
            return;
          }
          
          final file = File(path);
          final jsonString = await file.readAsString();
          
          if (!mounted) return;
          
          _processQuizFile(jsonString, result.files.first.name);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('파일 가져오기 오류: $e');
    }
  }
  
  // 퀴즈 파일 처리
  void _processQuizFile(String jsonString, String fileName) {
    try {
      // JSON 유효성 검사
      final jsonData = json.decode(jsonString);
      
      // 퀴즈 배열 확인
      if (!jsonData.containsKey('quizzes') || jsonData['quizzes'] is! List) {
        _showErrorSnackbar('유효한 퀴즈 파일 형식이 아닙니다.');
        return;
      }
      
      final quizzes = jsonData['quizzes'] as List;
      if (quizzes.isEmpty) {
        _showErrorSnackbar('퀴즈가 없는 파일입니다.');
        return;
      }
      
      // 퀴즈 파일 생성 및 저장
      final quizFile = QuizFile(
        id: DateTime.now().millisecondsSinceEpoch,
        name: fileName.replaceAll('.json', ''),
        content: jsonString,
        isActive: true,
      );
      
      final quizFileProvider = Provider.of<QuizFileProvider>(context, listen: false);
      quizFileProvider.addQuizFile(quizFile);
      
      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getQuizCount(jsonString)}개의 퀴즈를 추가했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('파일 형식 오류: $e');
    }
  }
  
  // 퀴즈 수 확인
  int _getQuizCount(String jsonString) {
    try {
      final jsonData = json.decode(jsonString);
      return (jsonData['quizzes'] as List).length;
    } catch (e) {
      return 0;
    }
  }
  
  // 퀴즈 파일 삭제
  Future<void> _deleteQuizFile(QuizFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈 파일 삭제'),
        content: Text('${file.name} 파일을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      final quizFileProvider = Provider.of<QuizFileProvider>(context, listen: false);
      quizFileProvider.removeQuizFile(file.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('퀴즈 파일이 삭제되었습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 에러 메시지
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: Consumer<QuizFileProvider>(
        builder: (context, quizFileProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사운드 설정 섹션
                  const Text(
                    '사운드 설정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 효과음 설정
                  SwitchListTile(
                    title: const Text('효과음'),
                    subtitle: const Text('버튼 클릭, 정답/오답 소리 등'),
                    value: _isSoundEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isSoundEnabled = value;
                      });
                      _updateSoundSettings();
                    },
                  ),
                  
                  // 웹 브라우저 환경에서 사운드 사용 안내
                  if (kIsWeb && _isSoundEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: Colors.amber.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber.shade800),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '웹 브라우저 사운드 안내',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '웹 브라우저에서는 사용자 상호작용(클릭) 이후에만 사운드가 재생됩니다. 테스트 버튼을 클릭하여 소리를 확인해 보세요.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // 효과음 볼륨 슬라이더
                  if (_isSoundEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_down),
                          Expanded(
                            child: Slider(
                              value: _soundVolume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              onChanged: (value) {
                                setState(() {
                                  _soundVolume = value;
                                });
                              },
                              onChangeEnd: (value) {
                                _updateSoundSettings();
                                // 볼륨 변경 시 효과음 테스트
                                // ignore: unawaited_futures
                                soundService.playSound(SoundType.buttonClick);
                              },
                            ),
                          ),
                          const Icon(Icons.volume_up),
                        ],
                      ),
                    ),
                  
                  // 효과음 테스트 버튼
                  if (_isSoundEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // ignore: unawaited_futures
                          soundService.testAllSounds();
                        },
                        icon: const Icon(Icons.music_note),
                        label: const Text('효과음 테스트'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    
                  const Divider(height: 32),
                    
                  // 퀴즈 파일 관리 섹션
                  const Text(
                    '퀴즈 파일 관리',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 모든 퀴즈 파일 사용 옵션
                  SwitchListTile(
                    title: const Text('모든 퀴즈 파일 혼합'),
                    subtitle: const Text('모든 활성화된 퀴즈 파일에서 문제를 출제합니다'),
                    value: _useAllQuizFiles,
                    onChanged: (value) {
                      setState(() {
                        _useAllQuizFiles = value;
                      });
                      quizFileProvider.setUseAllFiles(value);
                      if (_isSoundEnabled) {
                        // ignore: unawaited_futures
                        soundService.playSound(SoundType.buttonClick);
                      }
                    },
                  ),
                  
                  const Divider(),
                  
                  // 퀴즈 파일 추가 버튼
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_isSoundEnabled) {
                        // ignore: unawaited_futures
                        soundService.playSound(SoundType.buttonClick);
                      }
                      _importQuizFile();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('퀴즈 파일 추가'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const Text(
                    '추가된 퀴즈 파일',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 퀴즈 파일 목록
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: quizFileProvider.quizFiles.isEmpty
                        ? const Center(
                            child: Text('추가된 퀴즈 파일이 없습니다.'),
                          )
                        : ListView.builder(
                            itemCount: quizFileProvider.quizFiles.length,
                            itemBuilder: (context, index) {
                              final file = quizFileProvider.quizFiles[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  title: Text(file.name),
                                  subtitle: Text(
                                    '${_getQuizCount(file.content)} 문제',
                                    style: TextStyle(
                                      color: file.isActive 
                                          ? Colors.green 
                                          : Colors.grey,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 파일 활성화/비활성화 스위치
                                      Switch(
                                        value: file.isActive,
                                        onChanged: (value) {
                                          if (_isSoundEnabled) {
                                            // ignore: unawaited_futures
                                            soundService.playSound(SoundType.buttonClick);
                                          }
                                          quizFileProvider.toggleQuizFile(
                                            file.id, 
                                            value,
                                          );
                                        },
                                      ),
                                      // 삭제 버튼
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          if (_isSoundEnabled) {
                                            // ignore: unawaited_futures
                                            soundService.playSound(SoundType.buttonClick);
                                          }
                                          _deleteQuizFile(file);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 
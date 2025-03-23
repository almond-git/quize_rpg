import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quiz_rpg/models/quiz_file.dart';

class QuizFileProvider with ChangeNotifier {
  List<QuizFile> _quizFiles = [];
  QuizFile? _activeFile;
  bool _useAllFiles = false;

  // Getters
  List<QuizFile> get quizFiles => _quizFiles;
  QuizFile? get activeFile => _activeFile;
  bool get useAllFiles => _useAllFiles;

  // Constructor
  QuizFileProvider() {
    _loadQuizFiles();
  }

  // 모든 퀴즈 파일 사용 설정
  Future<void> setUseAllFiles(bool useAll) async {
    _useAllFiles = useAll;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_all_files', useAll);
  }

  // 퀴즈 파일 추가
  Future<void> addQuizFile(QuizFile file) async {
    _quizFiles.add(file);
    
    // 첫 번째 파일이 추가된 경우 활성 파일로 설정
    if (_quizFiles.length == 1 && _activeFile == null) {
      _activeFile = file;
    }
    
    notifyListeners();
    await _saveQuizFiles();
  }

  // 퀴즈 파일 삭제
  Future<void> removeQuizFile(int id) async {
    _quizFiles.removeWhere((file) => file.id == id);
    
    // 활성 파일이 삭제된 경우
    if (_activeFile != null && _activeFile!.id == id) {
      _activeFile = _quizFiles.isNotEmpty ? _quizFiles.first : null;
    }
    
    notifyListeners();
    await _saveQuizFiles();
  }

  // 퀴즈 파일 활성화/비활성화 토글
  Future<void> toggleQuizFile(int id, bool isActive) async {
    final index = _quizFiles.indexWhere((file) => file.id == id);
    if (index >= 0) {
      _quizFiles[index] = _quizFiles[index].copyWith(isActive: isActive);
      notifyListeners();
      await _saveQuizFiles();
    }
  }

  // 활성 퀴즈 파일 설정
  Future<void> setActiveFile(int id) async {
    final file = _quizFiles.firstWhere(
      (file) => file.id == id,
      orElse: () => _quizFiles.isNotEmpty ? _quizFiles.first : _quizFiles.first,
    );
    
    _activeFile = file;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_file_id', id);
  }

  // 활성화된 모든 퀴즈 파일의 내용 가져오기
  List<String> getActiveQuizContents() {
    if (_useAllFiles) {
      // 모든 활성 파일의 내용 반환
      return _quizFiles
          .where((file) => file.isActive)
          .map((file) => file.content)
          .toList();
    } else if (_activeFile != null && _activeFile!.isActive) {
      // 활성 파일만 반환
      return [_activeFile!.content];
    }
    
    // 기본값으로 첫 번째 활성 파일 반환
    final activeFiles = _quizFiles.where((file) => file.isActive);
    if (activeFiles.isNotEmpty) {
      return [activeFiles.first.content];
    }
    
    return [];
  }

  // 저장된 퀴즈 파일 목록 불러오기
  Future<void> _loadQuizFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 퀴즈 파일 목록 로드
      final filesJson = prefs.getString('quiz_files');
      if (filesJson != null) {
        final List<dynamic> filesData = jsonDecode(filesJson);
        _quizFiles = filesData
            .map((fileData) => QuizFile.fromJson(fileData))
            .toList();
      }
      
      // 활성 파일 ID 로드
      final activeFileId = prefs.getInt('active_file_id');
      if (activeFileId != null && _quizFiles.isNotEmpty) {
        _activeFile = _quizFiles.firstWhere(
          (file) => file.id == activeFileId,
          orElse: () => _quizFiles.first,
        );
      } else if (_quizFiles.isNotEmpty) {
        _activeFile = _quizFiles.first;
      }
      
      // 모든 파일 사용 설정 로드
      _useAllFiles = prefs.getBool('use_all_files') ?? false;
      
      notifyListeners();
    } catch (e) {
      debugPrint('퀴즈 파일 로드 오류: $e');
    }
  }

  // 퀴즈 파일 목록 저장
  Future<void> _saveQuizFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 퀴즈 파일 목록을 JSON으로 직렬화
      final filesData = _quizFiles.map((file) => file.toJson()).toList();
      final filesJson = jsonEncode(filesData);
      
      // 저장
      await prefs.setString('quiz_files', filesJson);
      
      // 활성 파일 ID 저장
      if (_activeFile != null) {
        await prefs.setInt('active_file_id', _activeFile!.id);
      }
    } catch (e) {
      debugPrint('퀴즈 파일 저장 오류: $e');
    }
  }
} 
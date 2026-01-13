import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/device_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final DeviceService _deviceService = DeviceService();

  Student? _student;
  List<AttendanceRecord> _history = [];
  bool _isLoading = false;
  bool _isOnboarded = false;
  String? _deviceHash;
  bool _isConnected = true;

  // Getters
  Student? get student => _student;
  List<AttendanceRecord> get history => _history;
  bool get isLoading => _isLoading;
  bool get isOnboarded => _isOnboarded;
  String? get deviceHash => _deviceHash;
  bool get isConnected => _isConnected;

  // Stats
  int get presentCount => _history.where((r) => r.isPresent).length;
  int get flaggedCount => _history.where((r) => r.isFlagged).length;
  int get totalCount => _history.length;

  // Initialize app state
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load device hash
      _deviceHash = await _deviceService.getDeviceHash();
      
      // Check onboarding status
      _isOnboarded = await _storageService.isOnboarded();
      
      // Load student data
      _student = await _storageService.getStudent();
      
      // Load cached history
      _history = await _storageService.getCachedHistory();
      
      // Check connection and refresh history
      _isConnected = await _apiService.checkConnection();
      
      if (_isConnected && _student != null) {
        await refreshHistory();
      }
    } catch (e) {
      debugPrint('Initialize error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Complete onboarding
  Future<bool> completeOnboarding({
    required String studentId,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _deviceHash ??= await _deviceService.getDeviceHash();
      
      // Create student object
      _student = Student(
        studentId: studentId,
        name: name,
        deviceHash: _deviceHash,
        enrolledAt: DateTime.now(),
      );

      // Try to enroll with server
      await _apiService.enrollStudent(
        studentId: studentId,
        name: name,
        deviceHash: _deviceHash!,
      );

      // Save locally regardless of server response
      await _storageService.saveStudent(_student!);
      await _storageService.setOnboarded(true);
      
      _isOnboarded = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Onboarding error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Mark attendance
  // authMethod: 'biometric' = Present, 'fallback' = Flagged for teacher review
  Future<AttendanceResult> markAttendance({
    required String token,
    required String pin,
    required String authMethod, // 'biometric' or 'fallback'
    String classId = 'DEFAULT',
  }) async {
    if (_student == null || _deviceHash == null) {
      return AttendanceResult.error('Not logged in');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.markAttendance(
        studentId: _student!.studentId,
        name: _student!.name,
        token: token,
        pin: pin,
        deviceHash: _deviceHash!,
        authMethod: authMethod, // Pass auth method to API
        classId: classId,
      );

      if (result.success) {
        // Add to local history
        final record = AttendanceRecord(
          studentId: _student!.studentId,
          name: _student!.name,
          status: result.status,
          time: DateTime.now(),
          classId: classId,
        );
        _history.insert(0, record);
        await _storageService.cacheAttendanceHistory(_history);
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return AttendanceResult.error('Failed to mark attendance');
    }
  }

  // Refresh history from server
  Future<void> refreshHistory() async {
    if (_student == null) return;

    try {
      final records = await _apiService.getAttendanceHistory(
        studentId: _student!.studentId,
      );
      
      if (records.isNotEmpty) {
        // Filter to only this student's records
        _history = records.where((r) => r.studentId == _student!.studentId).toList();
        await _storageService.cacheAttendanceHistory(_history);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh history error: $e');
    }
  }

  // Check server connection
  Future<void> checkConnection() async {
    _isConnected = await _apiService.checkConnection();
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    await _storageService.clearAll();
    _student = null;
    _history = [];
    _isOnboarded = false;
    notifyListeners();
  }
}

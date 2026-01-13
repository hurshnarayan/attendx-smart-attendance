import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _studentKey = 'student_data';
  static const String _historyKey = 'attendance_history';
  static const String _onboardedKey = 'is_onboarded';

  // Student Data
  Future<void> saveStudent(Student student) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_studentKey, jsonEncode(student.toJson()));
  }

  Future<Student?> getStudent() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_studentKey);
    if (data != null) {
      return Student.fromJson(jsonDecode(data));
    }
    return null;
  }

  Future<void> clearStudent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_studentKey);
  }

  // Onboarding Status
  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, value);
  }

  // Local Attendance History Cache
  Future<void> cacheAttendanceHistory(List<AttendanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((r) => {
      'id': r.id,
      'studentId': r.studentId,
      'name': r.name,
      'status': r.status,
      'reason': r.reason,
      'time': r.time.toIso8601String(),
      'classId': r.classId,
    }).toList();
    await prefs.setString(_historyKey, jsonEncode(jsonList));
  }

  Future<List<AttendanceRecord>> getCachedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_historyKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => AttendanceRecord.fromJson(json)).toList();
    }
    return [];
  }

  // Add single record to cache
  Future<void> addToHistory(AttendanceRecord record) async {
    final history = await getCachedHistory();
    history.insert(0, record);
    await cacheAttendanceHistory(history);
  }

  // Clear all data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

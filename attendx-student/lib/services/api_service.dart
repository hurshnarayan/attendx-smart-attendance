import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = ApiConfig.baseUrl;

  // Mark attendance
  // authMethod: 'biometric' = Present, 'fallback' = Flagged
  Future<AttendanceResult> markAttendance({
    required String studentId,
    required String name,
    required String token,
    required String pin,
    required String deviceHash,
    required String authMethod, // 'biometric' or 'fallback'
    String classId = 'DEFAULT',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConfig.markAttendance}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId': studentId,
          'name': name,
          'token': token,
          'pin': pin,
          'deviceHash': deviceHash,
          'classId': classId,
          'authMethod': authMethod, // Send auth method to backend
          'biometricSig': authMethod == 'biometric' 
              ? 'biometric-verified-${DateTime.now().millisecondsSinceEpoch}'
              : 'fallback-auth-${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AttendanceResult.fromJson(data);
      } else {
        final data = jsonDecode(response.body);
        return AttendanceResult.error(data['error'] ?? 'Failed to mark attendance');
      }
    } catch (e) {
      return AttendanceResult.error('Network error: ${e.toString()}');
    }
  }

  // Enroll student
  Future<bool> enrollStudent({
    required String studentId,
    required String name,
    required String deviceHash,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConfig.enrollStudent}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId': studentId,
          'name': name,
          'deviceHash': deviceHash,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get attendance history for a student
  Future<List<AttendanceRecord>> getAttendanceHistory({
    String classId = 'DEFAULT',
    String? studentId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${ApiConfig.getAttendance}')
          .replace(queryParameters: {'classId': classId});
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) ?? [];
        final records = data.map((json) => AttendanceRecord.fromJson(json)).toList();
        
        // Filter by studentId if provided
        if (studentId != null) {
          return records.where((r) => r.studentId == studentId).toList();
        }
        return records;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Check server connection
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConfig.getToken}?classId=DEFAULT'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

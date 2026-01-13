class Student {
  final String studentId;
  final String name;
  final String? deviceHash;
  final DateTime? enrolledAt;

  Student({
    required this.studentId,
    required this.name,
    this.deviceHash,
    this.enrolledAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      studentId: json['studentId'] ?? json['student_id'] ?? '',
      name: json['name'] ?? '',
      deviceHash: json['deviceHash'] ?? json['device_hash'],
      enrolledAt: json['enrolledAt'] != null 
          ? DateTime.tryParse(json['enrolledAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'name': name,
      'deviceHash': deviceHash,
    };
  }
}

class AttendanceRecord {
  final int? id;
  final String studentId;
  final String name;
  final String status;
  final String? reason;
  final DateTime time;
  final String? classId;

  AttendanceRecord({
    this.id,
    required this.studentId,
    required this.name,
    required this.status,
    this.reason,
    required this.time,
    this.classId,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      studentId: json['studentId'] ?? json['student_id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'pending',
      reason: json['reason'],
      time: json['time'] != null 
          ? DateTime.tryParse(json['time']) ?? DateTime.now()
          : DateTime.now(),
      classId: json['classId'] ?? json['class_id'],
    );
  }

  bool get isPresent => status == 'present';
  bool get isFlagged => status == 'flagged';
  bool get isPending => status == 'pending';
}

class QRData {
  final String tokenString;
  final String pin;
  final String? classId;

  QRData({
    required this.tokenString,
    required this.pin,
    this.classId,
  });

  // Parse QR code data - the QR contains the tokenString directly
  factory QRData.fromQRString(String qrString, String pin, {String? classId}) {
    return QRData(
      tokenString: qrString,
      pin: pin,
      classId: classId,
    );
  }
}

class AttendanceResult {
  final bool success;
  final String status;
  final String? studentId;
  final String? name;
  final String? error;

  AttendanceResult({
    required this.success,
    required this.status,
    this.studentId,
    this.name,
    this.error,
  });

  factory AttendanceResult.fromJson(Map<String, dynamic> json) {
    return AttendanceResult(
      success: json['success'] ?? false,
      status: json['status'] ?? 'unknown',
      studentId: json['studentId'],
      name: json['name'],
      error: json['error'],
    );
  }

  factory AttendanceResult.error(String message) {
    return AttendanceResult(
      success: false,
      status: 'error',
      error: message,
    );
  }

  bool get isPresent => status == 'present';
  bool get isFlagged => status == 'flagged';
}

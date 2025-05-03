class TeacherAttendance {
  final String id;
  final String teacherId;
  final DateTime date;
  final DateTime time;
  final String status;
  final String verificationMethod;
  final Map<String, dynamic> deviceInfo;
  final DateTime createdAt;

  TeacherAttendance({
    required this.id,
    required this.teacherId,
    required this.date,
    required this.time,
    required this.status,
    required this.verificationMethod,
    required this.deviceInfo,
    required this.createdAt,
  });

  // Factory constructor to create a TeacherAttendance from a JSON map
  factory TeacherAttendance.fromJson(Map<String, dynamic> json) {
    return TeacherAttendance(
      id: json['id'] ?? '',
      teacherId: json['teacher_id'],
      date: DateTime.parse(json['date']),
      time: DateTime.parse(json['time']),
      status: json['status'],
      verificationMethod: json['verification_method'],
      deviceInfo: json['device_info'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  // Convert TeacherAttendance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'teacher_id': teacherId,
      'date': date.toIso8601String().split('T')[0], // Just the date part
      'time': time.toIso8601String(),
      'status': status,
      'verification_method': verificationMethod,
      'device_info': deviceInfo,
      // Only include created_at if it's a new record
      if (id.isEmpty) 'created_at': createdAt.toIso8601String(),
    };
  }

  // Create a new attendance record for today
  static TeacherAttendance createForToday(String teacherId, Map<String, dynamic> deviceInfo) {
    final now = DateTime.now();
    return TeacherAttendance(
      id: '', // Will be assigned by Supabase
      teacherId: teacherId,
      date: DateTime(now.year, now.month, now.day), // Just the date part
      time: now,
      status: 'present',
      verificationMethod: 'biometric',
      deviceInfo: deviceInfo,
      createdAt: now,
    );
  }
  
  // Create a record for updating an existing attendance
  static TeacherAttendance createForUpdate(
    String id,
    String teacherId,
    DateTime date,
    Map<String, dynamic> deviceInfo
  ) {
    final now = DateTime.now();
    return TeacherAttendance(
      id: id,
      teacherId: teacherId,
      date: date,
      time: now,
      status: 'present',
      verificationMethod: 'biometric',
      deviceInfo: deviceInfo,
      createdAt: now,
    );
  }
}

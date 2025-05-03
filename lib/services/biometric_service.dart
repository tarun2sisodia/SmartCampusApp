import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/utils/constants/colors.dart';
import '../common/utils/local_storage/storage_utility.dart';
import '../models/teacher_attendance_model.dart';

class BiometricService extends GetxService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TStorageUtility _storageUtil = TStorageUtility();
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  // Observable to track biometric status
  final RxBool isBiometricAvailable = false.obs;
  final RxBool isAuthenticated = false.obs;
  final RxBool devModeEnabled = false.obs;

  Future<BiometricService> init() async {
    // Check if running on a supported platform first
    if (GetPlatform.isLinux) {
      print('Biometric debug: Running on Linux - biometrics not supported');
      isBiometricAvailable.value = false;
      Get.snackbar(
        'Biometric Status',
        'Biometrics not available on Linux platform',
        duration: const Duration(seconds: 3),
      );
      return this;
    }

    // Check if biometrics are available on device
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      print('Biometric debug: canCheckBiometrics = $canCheckBiometrics');
      print('Biometric debug: isDeviceSupported = $isDeviceSupported');

      isBiometricAvailable.value = canCheckBiometrics && isDeviceSupported;

      Get.snackbar(
        'Biometric Status',
        'Biometrics available: ${isBiometricAvailable.value}',
        duration: const Duration(seconds: 3),
      );
    } on PlatformException catch (e) {
      print('Biometric debug: PlatformException during init - ${e.message}');
      isBiometricAvailable.value = false;
      Get.snackbar(
          'Biometric Error', 'Error initializing biometrics: ${e.message}');
    }

    return this;
  }

  // Check if teacher has already marked attendance today
  Future<bool> hasMarkedAttendanceToday() async {
    final String today = DateTime.now().toIso8601String().split('T')[0];
    
    try {
      // First check local storage for quick response
      final String? lastAttendanceDate = _storageUtil.getString('last_attendance_date');
      if (lastAttendanceDate == today) {
        return true;
      }
      
      // If not in local storage, check the database
      if (userId != null) {
        final response = await _supabase
            .from('teacher_attendance')
            .select('status')
            .eq('teacher_id', userId!)
            .eq('date', today)
            .eq('status', 'present')
            .maybeSingle();
            
        return response != null;
      }
      
      return false;
    } catch (e) {
      print('Biometric debug: Error checking attendance - $e');
      return false;
    }
  }

  // Add this method to BiometricService
  void toggleDevMode(bool enabled) {
    devModeEnabled.value = enabled;
    if (enabled) {
      Get.snackbar(
        'Dev Mode Enabled',
        'Biometric authentication will be bypassed',
        backgroundColor: TColors.orange,
      );
    }
  }

  // Add this method to BiometricService
  Future<List<TeacherAttendance>> getTeacherAttendanceHistory(
      String teacherId, DateTime startDate, DateTime endDate) async {
    // Get actual attendance records
    final response = await _supabase
        .from('teacher_attendance')
        .select()
        .eq('teacher_id', teacherId)
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0]);

    List<TeacherAttendance> records = (response as List)
        .map((record) => TeacherAttendance.fromJson(record))
        .toList();

    // Create a map of existing records by date
    Map<String, TeacherAttendance> recordsByDate = {};
    for (var record in records) {
      recordsByDate[record.date.toIso8601String().split('T')[0]] = record;
    }

    // Fill in missing dates with "not marked" status
    List<TeacherAttendance> completeRecords = [];
    DateTime currentDate = startDate;

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      String dateString = currentDate.toIso8601String().split('T')[0];

      if (recordsByDate.containsKey(dateString)) {
        completeRecords.add(recordsByDate[dateString]!);
      } else {
        // Create a "not marked" record for this date
        completeRecords.add(TeacherAttendance(
          id: '',
          teacherId: teacherId,
          date: currentDate,
          time: currentDate,
          status: 'not_marked',
          verificationMethod: 'none',
          deviceInfo: {'generated': 'app_logic'},
          createdAt: DateTime.now(),
        ));
      }

      currentDate = currentDate.add(Duration(days: 1));
    }

    return completeRecords;
  }

  Future<bool> authenticateWithBiometrics() async {
    if (GetPlatform.isLinux || devModeEnabled.value) {
      print('Biometric debug: Running on Linux - biometrics not supported');
      Get.snackbar(
        'Development Mode',
        'Biometric authentication bypassed on Linux',
        backgroundColor: TColors.orange,
      );
      // For development purposes, you can simulate successful authentication
      isAuthenticated.value = true;
      return true;
    }

    try {
      print('Biometric debug: Starting authentication...');

      // Get available biometrics for debugging
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      print('Biometric debug: Available biometrics - $availableBiometrics');

      isAuthenticated.value = await _localAuth.authenticate(
        localizedReason: 'Authenticate to mark your attendance',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      print(
          'Biometric debug: Authentication result - ${isAuthenticated.value}');

      if (!isAuthenticated.value) {
        Get.snackbar(
            'Error', 'Biometric authentication failed. Please try again.');
      } else {
        Get.snackbar('Success', 'Biometric authentication successful!');
      }

      return isAuthenticated.value;
    } on PlatformException catch (e) {
      print('Biometric debug: Authentication error - ${e.code}: ${e.message}');

      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet) {
        Get.snackbar('Error',
            'Biometric authentication not available or not set up on this device (${e.code})');
      } else {
        Get.snackbar(
            'Error', 'Authentication failed: ${e.message} (${e.code})');
      }
      return false;
    }
  }

  // Mark attendance in Supabase
  Future<bool> markAttendance(String teacherId) async {
    try {
      print('Biometric debug: Starting attendance marking for teacher $teacherId');
      
      // Get today's date in ISO format (YYYY-MM-DD)
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Check if a record already exists for today
      final existingRecord = await _supabase
          .from('teacher_attendance')
          .select()
          .eq('teacher_id', teacherId)
          .eq('date', today)
          .maybeSingle();
      
      final deviceInfo = await _getDeviceInfo();
      print('Biometric debug: Device info - $deviceInfo');
      
      if (existingRecord != null) {
        // Update existing record
        print('Biometric debug: Updating existing attendance record');
        
        final response = await _supabase
            .from('teacher_attendance')
            .update({
              'status': 'present',
              'verification_method': 'biometric',
              'time': DateTime.now().toIso8601String(),
              'device_info': deviceInfo
            })
            .eq('id', existingRecord['id'])
            .select();
        
        print('Biometric debug: Update response - $response');
      } else {
        // Create a new attendance record
        print('Biometric debug: Creating new attendance record');
        
        final attendance = TeacherAttendance.createForToday(teacherId, deviceInfo);
        print('Biometric debug: Created attendance record - ${attendance.toJson()}');
        
        final response = await _supabase
            .from('teacher_attendance')
            .insert(attendance.toJson())
            .select();
        
        print('Biometric debug: Insert response - $response');
      }

      // Save locally that attendance was marked today
      await _storageUtil.setString('last_attendance_date', today);
      print('Biometric debug: Saved attendance date locally - $today');

      Get.snackbar(
        'Attendance Marked',
        'Your attendance has been successfully recorded',
        backgroundColor: TColors.green,
        colorText: TColors.white,
      );

      return true;
    } catch (e) {
      print('Biometric debug: Error marking attendance - $e');
      Get.snackbar('Error', 'Failed to mark attendance: $e');
      return false;
    }
  }

  // Get basic device info for verification
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    // You can expand this with a device_info_plus package
    return {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'platform': GetPlatform.isAndroid ? 'Android' : 'iOS',
    };
  }
}

import 'package:attedance__/app/routes/app_routes.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/biometric_service.dart';

class BiometricVerificationController extends GetxController {
  final BiometricService _biometricService = Get.find<BiometricService>();
  final _supabase = Supabase.instance.client;

  final RxBool isLoading = false.obs;
  final RxBool attendanceMarked = false.obs;
  final RxString teacherName = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadTeacherInfo();
    checkDailyAttendance();
  }

  // Load teacher information
  Future<void> loadTeacherInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userData = await _supabase
            .from('users')
            .select('name')
            .eq('id', user.id)
            .single();

        teacherName.value = userData['name'] ?? 'Teacher';
      }
    } catch (e) {
      print("BiometricVerificationController: Error loading teacher info - $e");
    }
  }

  // Check if attendance needs to be marked today
  Future<void> checkDailyAttendance() async {
    print("BiometricVerificationController: Checking daily attendance");
    isLoading.value = true;

    try {
      // Check if user is a teacher
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      print("BiometricVerificationController: Current user: ${user.id}");

      // Get user role from Supabase
      final userData = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      final String role = userData['role'] as String;

      // Only proceed if user is a teacher
      if (role != 'teacher') {
        print("BiometricVerificationController: User is not a teacher");
        return;
      }

      // Check if attendance already marked today
      attendanceMarked.value =
          await _biometricService.hasMarkedAttendanceToday();
      print(
          "BiometricVerificationController: Attendance marked today: ${attendanceMarked.value}");

      // Check if there's an existing record for today (even if not marked as present)
      final today = DateTime.now().toIso8601String().split('T')[0];
      final existingRecord = await _supabase
          .from('teacher_attendance')
          .select()
          .eq('teacher_id', user.id)
          .eq('date', today)
          .maybeSingle();

      // If no record exists at all, create a default "not_marked" record
      if (existingRecord == null) {
        print(
            "BiometricVerificationController: Creating default attendance record");
        await _supabase.from('teacher_attendance').insert({
          'teacher_id': user.id,
          'date': today,
          'time': DateTime.now().toIso8601String(),
          'status': 'not_marked',
          'verification_method': 'system',
          'device_info': {'source': 'app_initialization'}
        });
      }

      // If not marked as present and app just opened, prompt for biometric
      if (!attendanceMarked.value) {
        Get.offAllNamed(AppRoutes.biometricVerification);
      }
    } catch (e) {
      print("BiometricVerificationController: Error - $e");
      Get.snackbar('Error', 'Failed to check attendance status: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Verify biometric and mark attendance
  Future<bool> verifyAndMarkAttendance() async {
    isLoading.value = true;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Authenticate with biometrics
      final authenticated =
          await _biometricService.authenticateWithBiometrics();
      if (!authenticated) return false;

      // Mark attendance in database
      final success = await _biometricService.markAttendance(user.id);
      if (success) {
        attendanceMarked.value = true;
      }

      return success;
    } catch (e) {
      print("BiometricVerificationController: Error marking attendance - $e");
      Get.snackbar('Error', 'Failed to mark attendance: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Get attendance history for the current month
  Future<List<Map<String, dynamic>>> getMonthlyAttendance() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final attendanceRecords = await _biometricService
          .getTeacherAttendanceHistory(user.id, startOfMonth, endOfMonth);

      return attendanceRecords
          .map((record) => {
                'date': record.date,
                'status': record.status,
                'verification': record.verificationMethod,
              })
          .toList();
    } catch (e) {
      print(
          "BiometricVerificationController: Error getting monthly attendance - $e");
      return [];
    }
  }

  // Force check biometrics (for debugging)
  Future<void> forceCheckBiometrics() async {
    try {
      print('Debug: Force checking biometrics...');
      final biometricService = Get.find<BiometricService>();

      // Re-initialize biometric service
      await biometricService.init();

      // Print available biometrics
      final localAuth = LocalAuthentication();
      final availableBiometrics = await localAuth.getAvailableBiometrics();

      print('Debug: Available biometrics - $availableBiometrics');
      print(
          'Debug: Biometrics available - ${biometricService.isBiometricAvailable.value}');

      Get.snackbar(
        'Biometric Check',
        'Available: ${biometricService.isBiometricAvailable.value}\nTypes: $availableBiometrics',
        duration: Duration(seconds: 5),
      );
    } catch (e) {
      print('Debug: Error checking biometrics - $e');
      Get.snackbar('Error', 'Failed to check biometrics: $e');
    }
  }
}

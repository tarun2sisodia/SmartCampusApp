import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/biometric_service.dart';

class BiometricVerificationController extends GetxController {
  final BiometricService _biometricService = Get.find<BiometricService>();
  final _supabase = Supabase.instance.client;

  final RxBool isLoading = false.obs;
  final RxBool attendanceMarked = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkDailyAttendance();
  }

  // Check if attendance needs to be marked today
  Future<void> checkDailyAttendance() async {
    isLoading.value = true;

    try {
      // Check if user is a teacher
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get user role from Supabase
      final userData = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      final String role = userData['role'] as String;

      // Only proceed if user is a teacher
      if (role != 'teacher') return;

      // Check if attendance already marked today
      attendanceMarked.value =
          await _biometricService.hasMarkedAttendanceToday();

      // If not marked and app just opened, prompt for biometric
      if (!attendanceMarked.value) {
        Get.toNamed('/biometric-verification');
      }
    } catch (e) {
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
      Get.snackbar('Error', 'Failed to mark attendance: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}

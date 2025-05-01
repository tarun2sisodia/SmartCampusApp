import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/utils/local_storage/storage_utility.dart';

class BiometricService extends GetxService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TStorageUtility _storageUtil = TStorageUtility();
  final _supabase = Supabase.instance.client;

  // Observable to track biometric status
  final RxBool isBiometricAvailable = false.obs;
  final RxBool isAuthenticated = false.obs;

  Future<BiometricService> init() async {
    // Check if biometrics are available on device
    try {
      isBiometricAvailable.value = await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } on PlatformException catch (_) {
      isBiometricAvailable.value = false;
    }

    return this;
  }

  // Check if teacher has already marked attendance today
  Future<bool> hasMarkedAttendanceToday() async {
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String? lastAttendanceDate =
        _storageUtil.getString('last_attendance_date');

    return lastAttendanceDate == today;
  }

  // Authenticate using biometrics
  Future<bool> authenticateWithBiometrics() async {
    if (!isBiometricAvailable.value) return false;

    try {
      isAuthenticated.value = await _localAuth.authenticate(
        localizedReason: 'Authenticate to mark your attendance',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return isAuthenticated.value;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet) {
        // Handle specific errors
        Get.snackbar('Error',
            'Biometric authentication not available or not set up on this device');
      } else {
        Get.snackbar('Error', 'Authentication failed. Please try again.');
      }
      return false;
    }
  }

  // Mark attendance in Supabase
  Future<bool> markAttendance(String teacherId) async {
    try {
      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];

      // Record attendance in Supabase
      await _supabase.from('teacher_attendance').insert({
        'teacher_id': teacherId,
        'date': today,
        'time': now.toIso8601String(),
        'status': 'present',
        'verification_method': 'biometric',
        'device_info': await _getDeviceInfo(),
      });

      // Save locally that attendance was marked today
      await _storageUtil.setString('last_attendance_date', today);

      return true;
    } catch (e) {
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

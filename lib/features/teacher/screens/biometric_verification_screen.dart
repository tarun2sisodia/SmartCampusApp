import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/biometric_verification_controller.dart';

class BiometricVerificationScreen extends StatelessWidget {
  final BiometricVerificationController controller = Get.find<BiometricVerificationController>();

  // ignore: use_super_parameters
  BiometricVerificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Verification'),
        automaticallyImplyLeading: false,
      ),
      body: Obx(() => Center(
        child: controller.isLoading.value
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fingerprint,
                    size: 100,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Daily Attendance Verification',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      'Please verify your identity using biometrics to mark your attendance for today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Verify & Mark Attendance'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    onPressed: () async {
                      final success = await controller.verifyAndMarkAttendance();
                      if (success) {
                        Get.offAllNamed('/dashboard');
                        Get.snackbar(
                          'Success',
                          'Your attendance has been marked for today.',
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Get.offAllNamed('/dashboard');
                      Get.snackbar(
                        'Reminder',
                        'You need to mark your attendance today.',
                        backgroundColor: Colors.orange,
                      );
                    },
                    child: const Text('Skip for now (Attendance not marked)'),
                  ),
                ],
              ),
      )),
    );
  }
}
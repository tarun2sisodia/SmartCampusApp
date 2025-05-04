import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_routes.dart';
import 'app/theme/theme.dart';
import 'common/translations/app_translations.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    // _autoLogin();
    return GetMaterialApp(
      title: 'Attendance App',
      translations: AppTranslations(),
      locale: languageService.currentLocale.value,
      fallbackLocale: const Locale('en', 'US'),
      // Theme Data is for the UI in Light theme
      // Use your enhanced theme from TAppTheme
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,

      themeMode: ThemeMode.system, // Respects system theme setting
      debugShowCheckedModeBanner: false, // Remove debug banner from UI
      // Set the splash screen as the initial route
      initialRoute: AppRoutes.splash,
      // Managing the routes by disposing of unused controllers from memory
      smartManagement: SmartManagement.keepFactory,
      // Use the routes defined in AppRoutes
      getPages: AppRoutes.routes,
    );
  }
}
/*Future<void> _autoLogin() async {
  //print('Attempting auto-login...');

  // Initialize the storage service
  await Get.putAsync(() => StorageService().init());
  //print('StorageService initialized.');

  // Retrieve the storage service instance
final storageService = Get.find<StorageService>();
  //print('StorageService instance retrieved.');

  // Check if user credentials are saved
  final bool isLoggedIn =
      storageService.getRememberUserStatus() &&
      storageService.getUserEmail() != null &&
      storageService.getUserPassword() != null;

  //print('Is user logged in? $isLoggedIn');

  if (isLoggedIn) {
    try {
      final email = storageService.getUserEmail()!;
      final password = storageService.getUserPassword()!;
      //print('Attempting auto-login with email: $email');

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      //print('Auto-login successful.');
    } catch (e) {
      //print('Auto-login failed: $e');
      Get.snackbar(
        'Auto-login Failed',
        'Unable to log in automatically. Please log in manually.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}*/

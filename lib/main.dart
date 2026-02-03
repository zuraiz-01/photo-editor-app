import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:sizer/sizer.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/theme_controller.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  Get.put(ThemeController());
  await Future<void>.delayed(const Duration(seconds: 3));
  FlutterNativeSplash.remove();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00E5FF);
    const neonPurple = Color(0xFFB44CFF);
    const bg = Color(0xFF070A12);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: neonCyan,
          brightness: Brightness.dark,
        ).copyWith(
          primary: neonCyan,
          secondary: neonPurple,
          surface: const Color(0xFF0B1020),
        );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1020),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0B1020),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: neonCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonCyan,
          side: const BorderSide(color: neonCyan),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: neonCyan,
        inactiveTrackColor: Color(0xFF1C2947),
        thumbColor: neonCyan,
      ),
    );

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: neonCyan),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
      ),
    );

    return Sizer(
      builder: (context, orientation, deviceType) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Photo Editor',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: Get.find<ThemeController>().mode,
          initialRoute: Routes.home,
          getPages: AppPages.pages,
        );
      },
    );
  }
}

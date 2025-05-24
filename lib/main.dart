import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libretv_app/widgets/app_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '苹果CMS电影播放器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(const TextTheme(
          displayLarge: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          displayMedium: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          displaySmall: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineMedium: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineSmall: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          titleLarge: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        )).apply(
          displayColor: Colors.white,
          bodyColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 4,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const AppWrapper(),
    );
  }
}
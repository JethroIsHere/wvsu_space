import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';

// --- Define your custom colors class ---
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color? success;
  final Color? warning;
  final Color? inactive;
  final Color? cyan;

  const AppColors({
    required this.success,
    required this.warning,
    required this.inactive,
    required this.cyan,
  });

  // Helper for easy access
  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>()!;
  }

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? inactive,
    Color? cyan,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      inactive: inactive ?? this.inactive,
      cyan: cyan ?? this.cyan,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      success: Color.lerp(success, other.success, t),
      warning: Color.lerp(warning, other.warning, t),
      inactive: Color.lerp(inactive, other.inactive, t),
      cyan: Color.lerp(cyan, other.cyan, t),
    );
  }
}
// --- End of custom colors class ---

// --- This is the ONLY main function ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
// ------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo', // You can change this later
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,

        // --- STANDARD COLORS ---
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003087), // 'Primary'

          primary: const Color(0xFF003087), // 'Primary'
          secondary: const Color(0xFFFDB813), // 'Accent'
          surface: const Color(0xFFF5F5F7), // 'Surface'
          error: const Color(0xFFFF3B30), // 'Error'

          onSurface: const Color(0xFF111111), // 'Text Dark'

          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onError: Colors.white,
        ),

        // --- STANDARD TEXT STYLES ---
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
          ), // h1
          headlineLarge: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ), // Getting Started Headline
          headlineMedium: TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
          ), // h2
          headlineSmall: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.bold,
          ), // h3
          titleLarge: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
          ), // h4
          titleMedium: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w500,
          ), // Find your match
          labelLarge: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w500,
          ), // Button Text Size
          bodyLarge: TextStyle(fontSize: 14.0), // Login Text Label
          bodyMedium: TextStyle(fontSize: 15.0), // Getting started description
          bodySmall: TextStyle(
            fontSize: 12.0,
            color: Color(0xFF6E6E73),
          ), // Log In Text Hint
          labelSmall: TextStyle(fontSize: 10.0), // Interest Icon Label
        ),

        // --- OTHER STANDARD THEMES ---
        dividerTheme: const DividerThemeData(
          color: Color(0xFFC7C7CC), // 'Divider'
          thickness: 1.0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(fontSize: 14.0, color: Color(0xFF6E6E73)),
          hintStyle: TextStyle(fontSize: 12.0, color: Color(0xFF6E6E73)),
        ),

        // --- Register your custom colors ---
        extensions: const <ThemeExtension<dynamic>>[
          AppColors(
            success: Color(0xFF34C759),
            warning: Color(0xFFFFD60A),
            inactive: Color(0xFF8E8E93),
            cyan: Color(0xFFE8F4FD),
          ),
        ],
      ),
      // Centralized router
      initialRoute: AppRouter.gettingStarted,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

// --- MyHomePage removed as it's no longer the home screen ---
// class MyHomePage extends StatefulWidget { ... }
// class _MyHomePageState extends State<MyHomePage> { ... }
// -----------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
      // Wrap all routes with a global activity tracker so any screen usage updates lastActiveAt.
      builder: (context, child) => _ActivityTracker(child: child),
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

/// Global lifecycle observer that writes lastActiveAt for the signed-in user
/// when the app starts, resumes, and periodically while foregrounded.
class _ActivityTracker extends StatefulWidget {
  final Widget? child;
  const _ActivityTracker({this.child});

  @override
  State<_ActivityTracker> createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends State<_ActivityTracker>
    with WidgetsBindingObserver {
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _touch();
    // Periodic heartbeat (every 5 minutes) while app is running
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) => _touch());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _touch();
    }
  }

  Future<void> _touch() async {
    // Skip if Firebase hasn't been initialized (e.g., widget tests)
    if (Firebase.apps.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'lastActiveAt': FieldValue.serverTimestamp(),
          // Maintain legacy field for compatibility
          'lastActive': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // Avoid spamming logs; keep this quiet in release builds
      // debugPrint('Failed to update lastActiveAt: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

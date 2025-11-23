// Upon user's entry in the app, initialize Firebase, set theme, and track user activity.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wvsu_space/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:wvsu_space/router/app_router.dart';

// App color group (success, warning, inactive, cyan). Cyan is for tooltips hehe!
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

  // Get these colors from the app theme.
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

// Main entry point for the application. This is where everything starts.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // If nobody is signed in, sign in anonymously so local testing and rules work.
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    // If signing in fails, don't stop the app. It will keep running without the authentication.
  }

  // This part is optional since if you set USE_FIREBASE_EMULATOR=true, the app uses local test servers.
  const useEmulator =
      bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    try {
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    } catch (e) {
      // If the emulators aren't running, just continue normally.
    }
  }
  runApp(const MyApp());
}
// ------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WVSU Space', // This is the App Title, in here, it is WVSU Space
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,

        /* Colors used across the app */
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

        /* Text sizes and styles used in the app */
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

        /* Other theme pieces like dividers and inputs */
        dividerTheme: const DividerThemeData(
          color: Color(0xFFC7C7CC), // 'Divider'
          thickness: 1.0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(fontSize: 14.0, color: Color(0xFF6E6E73)),
          hintStyle: TextStyle(fontSize: 12.0, color: Color(0xFF6E6E73)),
        ),

        /* Add our extra color group to the theme */
        extensions: const <ThemeExtension<dynamic>>[
          AppColors(
            success: Color(0xFF34C759),
            warning: Color(0xFFFFD60A),
            inactive: Color(0xFF8E8E93),
            cyan: Color(0xFFE8F4FD),
          ),
        ],
      ),
      // Wrap screens with a tracker that records last active time.
      builder: (context, child) => _ActivityTracker(child: child),
      // Routes: where screens are picked and opened
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

/// Purpose: Save when the signed-in user was last active so we know if they are around.
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
    // Heartbeat: every 5 minutes while the app runs
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
    // If Firebase is not ready (like in tests), don't try to update the database.
    if (Firebase.apps.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'lastActiveAt': FieldValue.serverTimestamp(),
          // Also save the older field name so older code can still read it
          'lastActive': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // If saving fails, ignore the problem so the app keeps working.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

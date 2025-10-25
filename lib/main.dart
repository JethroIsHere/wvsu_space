import 'package:flutter/material.dart';
import 'getting_started.dart';

// --- STEP 1: Define your custom colors class ---
// This class holds all your non-standard colors
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

  // Helper for easy access (e.g., AppColors.of(context).success)
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

  // This allows your custom colors to animate when the theme changes
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

// --- End of Step 1 ---

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,

        // --- STANDARD COLORS ---
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF003087), // 'Primary'

          primary: Color(0xFF003087), // 'Primary'
          secondary: Color(0xFFFDB813), // 'Accent'
          background: Color(0xFFF5F5F7), // 'Background'
          error: Color(0xFFFF3B30), // 'Error'

          onBackground: Color(0xFF111111), // 'Text Dark'
          onSurface: Color(0xFF111111), // 'Text Dark'

          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onError: Colors.white,
        ),

        // --- STANDARD TEXT STYLES ---
        textTheme: TextTheme(
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
        dividerTheme: DividerThemeData(
          color: Color(0xFFC7C7CC), // 'Divider'
          thickness: 1.0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(fontSize: 14.0, color: Color(0xFF6E6E73)),
          hintStyle: TextStyle(fontSize: 12.0, color: Color(0xFF6E6E73)),
        ),

        // --- STEP 2: Register your custom colors ---
        extensions: const <ThemeExtension<dynamic>>[
          AppColors(
            success: Color(0xFF34C759),
            warning: Color(0xFFFFD60A),
            inactive: Color(0xFF8E8E93),
            cyan: Color(0xFFE8F4FD),
          ),
        ],
      ),
      home: const GettingStartedScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- STEP 3: How to USE your custom colors ---
    final appColors = AppColors.of(context); // Helper to get your colors

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'This text uses the "Text Secondary" color:',
              // Using a standard theme color (that we customized)
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '$_counter',
              // Using a standard theme text style
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),

            // --- Example of using your custom color ---
            Container(
              color:
                  appColors.success, // <-- Using your custom "Success" color!
              padding: const EdgeInsets.all(12),
              child: Text(
                'This container uses the "Success" color',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 10),

            // --- Example of using another custom color ---
            Text(
              'This text uses the "Inactive" color',
              style: TextStyle(
                color: appColors.inactive,
              ), // <-- Using "Inactive"!
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

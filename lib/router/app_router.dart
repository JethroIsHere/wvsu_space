import 'package:flutter/material.dart';

import '../getting_started.dart';
import '../choose.dart';
import '../log_in.dart';
import '../sign_up.dart';
import '../home.dart';
import '../chat_lobby.dart';
import '../matching_progress.dart';
import '../admin/reports_admin.dart';
import '../admin/admin_login.dart';
import '../admin/admin_dashboard.dart';
import '../settings.dart';
import '../profile.dart';
import '../community_guidelines.dart';
import '../delete_account.dart';

// Optional stub for chat session
import '../chat_session.dart';

class AppRouter {
  // Route names
  static const String gettingStarted = '/';
  static const String choose = '/choose';
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String home = '/home';
  static const String lobby = '/lobby';
  static const String matching = '/matching';
  static const String chatSession = '/chat';
  static const String adminReports = '/admin/reports';
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String settings = '/settings';
  static const String communityGuidelines = '/community-guidelines';
  static const String deleteAccount = '/delete-account';
  static const String profile = '/profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case gettingStarted:
        return MaterialPageRoute(
          builder: (_) => const GettingStartedScreen(),
          settings: settings,
        );
      case choose:
        return MaterialPageRoute(
          builder: (_) => const ChooseScreen(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LogInScreen(),
          settings: settings,
        );
      case signUp:
        return MaterialPageRoute(
          builder: (_) => const SignUpScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case lobby:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialMode = args?['mode'] as String?;
        final lock = (args?['lock'] == true);
        return MaterialPageRoute(
          builder: (_) =>
              ChatLobbyScreen(initialMode: initialMode, lockMode: lock),
          settings: settings,
        );
      case matching:
        final args = settings.arguments as Map<String, dynamic>?;
        final mode = (args?['mode'] as String?) ?? 'random';
        final keywords =
            (args?['keywords'] as List?)?.whereType<String>().toList() ??
            const <String>[];
        return MaterialPageRoute(
          builder: (_) =>
              MatchingProgressScreen(mode: mode, keywords: keywords),
          settings: settings,
        );
      case chatSession:
        return MaterialPageRoute(
          builder: (_) => const ChatSessionScreen(),
          settings: settings,
        );
      case adminLogin:
        return MaterialPageRoute(
          builder: (_) => const AdminLoginScreen(),
          settings: settings,
        );
      case adminDashboard:
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(),
          settings: settings,
        );
      case adminReports:
        return MaterialPageRoute(
          builder: (_) => const ReportsAdminScreen(),
          settings: settings,
        );
      case AppRouter.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case AppRouter.communityGuidelines:
        return MaterialPageRoute(
          builder: (_) => const CommunityGuidelinesScreen(),
          settings: settings,
        );
      case AppRouter.deleteAccount:
        return MaterialPageRoute(
          builder: (_) => const DeleteAccountScreen(),
          settings: settings,
        );
      case AppRouter.profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const _NotFoundPage(),
          settings: settings,
        );
    }
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: const Center(child: Text('404 — This page does not exist.')),
    );
  }
}

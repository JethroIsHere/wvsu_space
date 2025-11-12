import 'package:flutter/material.dart';

import '../getting_started.dart';
import '../choose.dart';
import '../change_password.dart';
import '../log_in.dart';
import '../sign_up.dart';
import '../main_shell.dart';
import '../chat_lobby.dart';
import '../matching_progress.dart';
import '../admin/reports_admin.dart';
import '../admin/admin_login.dart';
import '../admin/admin_dashboard.dart';
import '../admin/admin_settings.dart';
import '../admin/user_management.dart';
import '../settings.dart';
import '../profile.dart';
import '../community_guidelines.dart';
import '../community_standing.dart';
import '../standing_activity.dart';
import '../delete_account.dart';
import '../request_review.dart';
import '../notifications.dart';

// Optional stub for chat session
import '../chat_session.dart';

class AppRouter {
  // Route names
  static const String gettingStarted = '/';
  static const String choose = '/choose';
  static const String changePassword = '/change-password';
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String home = '/home';
  static const String lobby = '/lobby';
  static const String matching = '/matching';
  static const String chatSession = '/chat';
  static const String adminReports = '/admin/reports';
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminSettings = '/admin/settings';
  static const String adminUserManagement = '/admin/users';
  static const String settings = '/settings';
  static const String communityGuidelines = '/community-guidelines';
  static const String communityStanding = '/standing';
  static const String standingActivity = '/standing/activity';
  static const String deleteAccount = '/delete-account';
  static const String profile = '/profile';
  static const String requestReview = '/request-review';
  static const String notifications = '/notifications';
  // Legacy route name for backwards compatibility
  static const String warnings = '/warnings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case gettingStarted:
        return _buildRoute(const GettingStartedScreen(), settings);
      case choose:
        return _buildRoute(const ChooseScreen(), settings);
      case changePassword:
        return _buildRoute(const ChangePasswordScreen(), settings);
      case login:
        return _buildRoute(const LogInScreen(), settings);
      case signUp:
        return _buildRoute(const SignUpScreen(), settings);
      case home:
        return _buildRoute(const MainShell(), settings);
      case lobby:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialMode = args?['mode'] as String?;
        final lock = (args?['lock'] == true);
        return _buildRoute(
          ChatLobbyScreen(initialMode: initialMode, lockMode: lock),
          settings,
        );
      case matching:
        final args = settings.arguments as Map<String, dynamic>?;
        final mode = (args?['mode'] as String?) ?? 'random';
        final keywords =
            (args?['keywords'] as List?)?.whereType<String>().toList() ??
                const <String>[];
        return _buildRoute(
          MatchingProgressScreen(mode: mode, keywords: keywords),
          settings,
        );
      case chatSession:
        return _buildRoute(const ChatSessionScreen(), settings);
      case adminLogin:
        return _buildRoute(const AdminLoginScreen(), settings);
      case adminDashboard:
        return _buildRoute(const AdminDashboardScreen(), settings);
      case adminSettings:
        return _buildRoute(const AdminSettingsScreen(), settings);
      case adminUserManagement:
        return _buildRoute(const UserManagementScreen(), settings);
      case adminReports:
        return _buildRoute(const ReportsAdminScreen(), settings);
      case AppRouter.settings:
        return _buildRoute(const SettingsScreen(), settings);
      case AppRouter.communityGuidelines:
        return _buildRoute(const CommunityGuidelinesScreen(), settings);
      case AppRouter.communityStanding:
        return _buildRoute(const CommunityStandingScreen(), settings);
      case AppRouter.standingActivity:
        return _buildRoute(const StandingActivityScreen(), settings);
      case AppRouter.deleteAccount:
        return _buildRoute(const DeleteAccountScreen(), settings);
      case AppRouter.profile:
        return _buildRoute(const ProfileScreen(), settings);
      case AppRouter.requestReview:
        return _buildRoute(const RequestReviewScreen(), settings);
      case AppRouter.notifications:
      case AppRouter.warnings: // Legacy route support
        return _buildRoute(const NotificationsScreen(), settings);
      default:
        return _buildRoute(const _NotFoundPage(), settings);
    }
  }

  static PageRouteBuilder<dynamic> _buildRoute(
    Widget child,
    RouteSettings settings,
  ) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
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

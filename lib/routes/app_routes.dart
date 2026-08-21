import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/live_safety_screen.dart';
import '../screens/emergency/emergency_contacts_screen.dart';
import '../screens/safety_circle/safety_circle_screen.dart';
import '../screens/tourist_id/digital_tourist_id_screen.dart';
import '../screens/incidents/report_incident_screen.dart';

/// Centralized route names for SafeGuard.
///
/// [login], [signup], [home], [liveSafety], [emergency] (Emergency
/// Contacts), [groups] (Safety Circle), and [incidents] (Report an
/// Incident) are wired to real screens.
/// [trips], [notifications] (Alerts), and [profile] are wired to a
/// temporary placeholder screen from the Home dashboard until their
/// dedicated prompts build them out. The remaining constants exist so
/// later prompts can register their screens here without renaming routes
/// used elsewhere in the app.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String trips = '/trips';
  static const String liveSafety = '/live-safety';
  static const String emergency = '/emergency';
  static const String groups = '/groups';
  static const String digitalTouristId = '/digital-tourist-id';
  static const String incidents = '/incidents';
  static const String insurance = '/insurance';
  static const String touristAssistance = '/tourist-assistance';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  /// Temporary initial route until Splash (Prompt #2) exists.
  static const String initialRoute = home;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case signup:
        return MaterialPageRoute(
          builder: (_) => const SignupScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case trips:
        return MaterialPageRoute(
          builder: (_) => const PlaceholderScreen(
            title: 'My Trips',
            icon: Icons.card_travel_outlined,
          ),
          settings: settings,
        );
      case liveSafety:
        return MaterialPageRoute(
          builder: (_) => const LiveSafetyScreen(),
          settings: settings,
        );
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const PlaceholderScreen(
            title: 'Alerts',
            icon: Icons.notifications_none_outlined,
          ),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute(
          builder: (_) => const PlaceholderScreen(
            title: 'Profile',
            icon: Icons.person_outline,
          ),
          settings: settings,
        );
      case groups:
        return MaterialPageRoute(
          builder: (_) => const SafetyCircleScreen(),
          settings: settings,
        );
      case emergency:
        return MaterialPageRoute(
          builder: (_) => const EmergencyContactsScreen(),
          settings: settings,
        );
      case digitalTouristId:
        return MaterialPageRoute(
          builder: (_) => const DigitalTouristIdScreen(),
          settings: settings,
        );
      case incidents:
        return MaterialPageRoute(
          builder: (_) => const ReportIncidentScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
    }
  }
}
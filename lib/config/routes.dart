import '../../models/campaign.dart';
import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/campaign/campaign_detail_screen.dart';
import '../screens/donation/donation_flow_screen.dart';
import '../screens/donations/my_donations_screen.dart';
import '../screens/help/help_screen.dart'; // Admin contact/Help: FAQ + KCA support
import '../screens/home/home_screen.dart';
import '../screens/impact/impact_screen.dart'; // Impact/Stories: photos, videos, milestones
import '../screens/notifications/notifications_screen.dart'; // Notifications/Inbox: confirmations, updates
import '../screens/profile/profile_screen.dart';
import '../screens/splash/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  //Adin routes
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminCampaigns = '/admin/campaigns';
  static const String adminDonors = '/admin/donors';
  static const String adminTransactions = '/admin/transactions';
  static const String adminReports = '/admin/reports';

  //user routes
  static const String home = '/home';
  static const String campaignDetail = '/campaign-detail';
  static const String donate = '/donate';
  static const String donationFlow = '/donation-flow';
  static const String myDonations = '/my-donations';
  static const String profile = '/profile';
  static const String impact = '/impact'; // Per manuscript #7: Impact / Stories
  static const String notifications = '/notifications'; // Per manuscript #9: Notifications / Inbox
  static const String help = '/help'; // Per manuscript #10: Admin contact / Help

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case campaignDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => CampaignDetailScreen(
            campaignId: args?['campaignId'] as String? ?? '', // Default empty to prevent crash
          ),
        );

      case donationFlow:
        final args = settings.arguments as Map<String, dynamic>?;
        final campaignMap = args?['campaign'] as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => DonationFlowScreen(
            campaign: Campaign.fromJson(campaignMap), // Use fromJson
          ),
        );
      case myDonations:
        return MaterialPageRoute(builder: (_) => const MyDonationsScreen());

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case impact:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ImpactScreen(
            campaignId: args?['campaignId'] as String?, // Optional: filter by campaign
          ),
        );

      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());

      case help:
        return MaterialPageRoute(builder: (_) => const HelpScreen());

      default:
      // Enhanced default: Log for debugging
        debugPrint('Undefined route: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
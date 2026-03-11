// lib/config/routes.dart

import 'package:flutter/material.dart';
import '../models/campaign.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/campaign/campaign_detail_screen.dart';
import '../screens/donation/donation_flow_screen.dart';
import '../screens/donations/my_donations_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/impact/impact_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/admin/admin_login_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_campaigns_screen.dart';
import '../screens/admin/admin_donors_screen.dart';
import '../screens/admin/admin_transactions_screen.dart';
import '../screens/admin/admin_staff_screen.dart';
import '../screens/admin/admin_roles_screen.dart';
import '../screens/admin/admin_reports_screen.dart';      // ✅ WIRED
import '../screens/admin/admin_settings_screen.dart';     // ✅ WIRED
import '../screens/admin/staff_dashboard_screen.dart';    // ✅ WIRED

class AppRoutes {
  // ── Donor app ───────────────────────────────────────────────────────────────
  static const String splash            = '/';
  static const String login             = '/login';
  static const String register          = '/register';
  static const String forgotPassword    = '/forgot-password';
  static const String home              = '/home';
  static const String campaignDetail    = '/campaign-detail';
  static const String donate            = '/donate';
  static const String donationFlow      = '/donation-flow';
  static const String myDonations       = '/my-donations';
  static const String profile           = '/profile';
  static const String impact            = '/impact';
  static const String notifications     = '/notifications';
  static const String help              = '/help';

  // ── Admin portal ────────────────────────────────────────────────────────────
  static const String adminLogin        = '/admin/login';
  static const String adminDashboard    = '/admin/dashboard';
  static const String adminCampaigns    = '/admin/campaigns';
  static const String adminDonors       = '/admin/donors';
  static const String adminTransactions = '/admin/transactions';
  static const String adminStaff        = '/admin/staff';
  static const String adminRoles        = '/admin/roles';
  static const String adminReports      = '/admin/reports';    // ✅ WIRED
  static const String adminSettings     = '/admin/settings';   // ✅ WIRED
  static const String staffDashboard    = '/admin/staff-dashboard'; // ✅ NEW

  // ── Route generator ─────────────────────────────────────────────────────────
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {

    // Donor app
      case splash:           return _route(const SplashScreen());
      case login:            return _route(const LoginScreen());
      case register:         return _route(const RegisterScreen());
      case forgotPassword:   return _route(const ForgotPasswordScreen());
      case home:             return _route(const HomeScreen());
      case profile:          return _route(const ProfileScreen());
      case myDonations:      return _route(const MyDonationsScreen());
      case notifications:    return _route(const NotificationsScreen());
      case help:             return _route(const HelpScreen());

      case impact:
        final args = settings.arguments as Map<String, dynamic>?;
        return _route(ImpactScreen(campaignId: args?['campaignId'] as String?));

      case campaignDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return _route(CampaignDetailScreen(campaignId: args?['campaignId'] as String? ?? ''));

      case donationFlow:
        final args       = settings.arguments as Map<String, dynamic>?;
        final map        = args?['campaign'] as Map<String, dynamic>? ?? {};
        final campaignId = args?['campaignId'] as String? ?? map['id'] as String? ?? '';
        // Merge the doc id into the map so Campaign.fromJson can read it
        return _route(DonationFlowScreen(campaign: Campaign.fromJson({'id': campaignId, ...map})));

    // Admin portal
      case adminLogin:        return _route(const AdminLoginScreen());
      case adminDashboard:    return _route(const AdminDashboardScreen());
      case adminCampaigns:    return _route(const AdminCampaignsScreen());
      case adminDonors:       return _route(const AdminDonorsScreen());
      case adminTransactions: return _route(const AdminTransactionsScreen());
      case adminStaff:        return _route(const AdminStaffScreen());
      case adminRoles:        return _route(const AdminRolesScreen());
      case adminReports:      return _route(const AdminReportsScreen());      // ✅
      case adminSettings:     return _route(const AdminSettingsScreen());     // ✅
      case staffDashboard:    return _route(const StaffDashboardScreen());    // ✅

      default:
        debugPrint('⚠ Undefined route: ${settings.name}');
        return _route(Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}'))));
    }
  }

  static MaterialPageRoute _route(Widget page) =>
      MaterialPageRoute(builder: (_) => page);
}
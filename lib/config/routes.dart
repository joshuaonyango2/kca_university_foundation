// lib/config/routes.dart

import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/campaign/campaign_detail_screen.dart';
import '../screens/donation/donation_flow_screen.dart';
import '../screens/donation/bank_transfer_screen.dart';
import '../screens/donations/my_donations_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/impact/impact_screen.dart';
import '../screens/admin/admin_login_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_campaigns_screen.dart';
import '../screens/admin/admin_donors_screen.dart';
import '../screens/admin/admin_transactions_screen.dart';
import '../screens/admin/admin_staff_screen.dart';
import '../screens/admin/admin_roles_screen.dart';
import '../screens/admin/admin_reports_screen.dart';
import '../screens/admin/admin_settings_screen.dart';
import '../screens/admin/admin_payment_methods_screen.dart';
import '../screens/admin/staff_dashboard_screen.dart';
import '../models/campaign.dart';

// ─── Route name constants ─────────────────────────────────────────────────────
class AppRoutes {
  static const String onboarding          = '/onboarding';
  static const String splash              = '/';
  static const String login               = '/login';
  static const String register            = '/register';
  static const String forgotPassword      = '/forgot-password';
  static const String home                = '/home';
  static const String campaignDetail      = '/campaign-detail';
  static const String donate              = '/donate';
  static const String donationFlow        = '/donation-flow';
  static const String bankTransfer        = '/bank-transfer';
  static const String myDonations         = '/my-donations';
  static const String profile             = '/profile';
  static const String impact              = '/impact';
  static const String notifications       = '/notifications';
  static const String help                = '/help';
  static const String adminLogin          = '/admin/login';
  static const String adminDashboard      = '/admin/dashboard';
  static const String adminCampaigns      = '/admin/campaigns';
  static const String adminDonors         = '/admin/donors';
  static const String adminTransactions   = '/admin/transactions';
  static const String adminStaff          = '/admin/staff';
  static const String adminRoles          = '/admin/roles';
  static const String adminReports        = '/admin/reports';
  static const String adminSettings       = '/admin/settings';
  static const String staffDashboard      = '/admin/staff-dashboard';
  static const String adminPaymentMethods = '/admin/payment-methods';
}

// ─── Route generator ──────────────────────────────────────────────────────────
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {

      case AppRoutes.onboarding:
        return _fade(const OnboardingScreen());

      case AppRoutes.splash:
        return _fade(const SplashScreen());

      case AppRoutes.login:
        return _slide(const LoginScreen());

      case AppRoutes.register:
        return _slide(const RegisterScreen());

      case AppRoutes.forgotPassword:
        return _slide(const ForgotPasswordScreen());

      case AppRoutes.home:
        return _fade(const HomeScreen());

    // ── CampaignDetailScreen takes a String campaignId, NOT a Campaign object ──
    // Navigate with:
    //   Navigator.pushNamed(context, AppRoutes.campaignDetail, arguments: campaign.id);
      case AppRoutes.campaignDetail:
        return _slide(CampaignDetailScreen(campaignId: args as String));

    // ── ImpactScreen takes a String campaignId, NOT a Campaign object ──
    // Navigate to this route with:
    //   Navigator.pushNamed(context, AppRoutes.impact, arguments: campaign.id);
      case AppRoutes.impact:
        return _slide(ImpactScreen(campaignId: args as String));

      case AppRoutes.donationFlow:
        return _slide(DonationFlowScreen(campaign: args as Campaign));

      case AppRoutes.bankTransfer:
        if (args is Map<String, dynamic>) {
          return _slide(BankTransferScreen(
            campaign:     args['campaign']      as Campaign,
            donorName:    args['donor_name']    as String? ?? '',
            donorEmail:   args['donor_email']   as String? ?? '',
            donorPhone:   args['donor_phone']   as String? ?? '',
            amount:       (args['amount'] as num?)?.toDouble() ?? 0,
            purpose:      args['purpose']       as String? ?? 'General Fund',
            frequency:    args['frequency']     as String? ?? 'one-time',
            anonymous:    args['anonymous']     as bool?   ?? false,
            selectedBank: args['selected_bank'] as String? ?? '',
          ));
        }
        return _slide(BankTransferScreen(
          campaign:   args as Campaign,
          donorName:  '',
          donorEmail: '',
          donorPhone: '',
          amount:     0,
        ));

      case AppRoutes.myDonations:
        return _slide(const MyDonationsScreen());

      case AppRoutes.notifications:
        return _slide(const NotificationsScreen());

      case AppRoutes.help:
        return _slide(const HelpScreen());

      case AppRoutes.adminLogin:
        return _fade(const AdminLoginScreen());

      case AppRoutes.adminDashboard:
        return _fade(const AdminDashboardScreen());

      case AppRoutes.adminCampaigns:
        return _fade(const AdminCampaignsScreen());

      case AppRoutes.adminDonors:
        return _fade(const AdminDonorsScreen());

      case AppRoutes.adminTransactions:
        return _fade(const AdminTransactionsScreen());

      case AppRoutes.adminStaff:
        return _fade(const AdminStaffScreen());

      case AppRoutes.adminRoles:
        return _fade(const AdminRolesScreen());

      case AppRoutes.adminReports:
        return _fade(const AdminReportsScreen());

      case AppRoutes.adminSettings:
        return _fade(const AdminSettingsScreen());

      case AppRoutes.adminPaymentMethods:
        return _fade(const AdminPaymentMethodsScreen());

      case AppRoutes.staffDashboard:
        return _fade(const StaffDashboardScreen());

      default:
        return _fade(Scaffold(
          body: Center(
            child: Text(
              'Route not found: ${settings.name}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ));
    }
  }

  // ─── Transitions ───────────────────────────────────────────────────────────
  static PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 250),
  );

  static PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );
}
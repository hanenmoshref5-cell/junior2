import 'package:get/get.dart';

import '../../feature/auth/presentation/screen/splash_screen.dart';
import '../../feature/auth/presentation/screen/onboarding_screen.dart';
import '../../feature/auth/presentation/screen/login_screen.dart';
import '../../feature/auth/presentation/screen/register_screen.dart';
// import '../../feature/auth/presentation/screen/reset_password_screen.dart';
import '../../feature/home/presentation/screen/home_screen.dart';
import '../../feature/measure/presentation/screen/measurefinger.dart';
import '../../feature/measure/presentation/screen/manual_input_screen.dart';
import '../../feature/history/presentation/screen/history_screen.dart';
import '../../feature/programs/presentation/screen/programs_screen.dart';
import '../../feature/programs/presentation/screen/program_detail_screen.dart';
import '../../feature/tips/presentation/screen/tips_screen.dart';
import '../../feature/chatbot/presentation/screen/chatbot_screen.dart';
import '../../feature/profile/presentation/screen/profile_screen.dart';

/// مسارات التنقل في التطبيق
class AppRoutes {
  AppRoutes._();

  // أسماء المسارات
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String measureFinger = '/measure-finger';
  static const String manualInput = '/manual-input';
  static const String history = '/history';
  static const String programs = '/programs';
  static const String programDetail = '/program-detail';
  static const String tips = '/tips';
  static const String chatbot = '/chatbot';
  static const String profile = '/profile';

  // قائمة المسارات
  static final List<GetPage> pages = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(name: onboarding, page: () => const OnboardingScreen()),
    GetPage(name: login, page: () => const LoginScreen()),
    GetPage(name: register, page: () => const RegisterScreen()),
    // GetPage(name: resetPassword, page: () => const ResetPasswordScreen()),
    GetPage(name: home, page: () => const HomeScreen()),
    GetPage(name: measureFinger, page: () => const Measurefinger()),
    GetPage(name: manualInput, page: () => const ManualInputScreen()),
    GetPage(name: history, page: () => const HistoryScreen()),
    GetPage(name: programs, page: () => const ProgramsScreen()),
    GetPage(name: programDetail, page: () => const ProgramDetailScreen()),
    GetPage(name: tips, page: () => const TipsScreen()),
    GetPage(name: chatbot, page: () => const ChatbotScreen()),
    GetPage(name: profile, page: () => const ProfileScreen()),
  ];
}

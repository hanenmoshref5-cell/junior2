// import 'package:flutter/material.dart';
// import 'package:testttt/feature/measure/presentation/screen/measurefinger.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 144, 124, 179)),
//       ),
//       home: Measurefinger(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'feature/auth/business/controller/auth_controller.dart';
import 'feature/home/business/controller/home_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Supabase
  await Supabase.initialize(
    url: 'https://pbhpjoflblihmhsvplda.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBiaHBqb2ZsYmxpaG1oc3ZwbGRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4MDk5NzAsImV4cCI6MjA5NTM4NTk3MH0.oAT11VqP3pjWDZkEHzpF_ipgQtu4NlGmpbY8gl0PvH0',
  );

  // تسجيل المتحكمات (Controllers) بشكل مباشر
  Get.put(AuthController(), permanent: true);
  Get.put(HomeController(), permanent: false);

  // إعداد شريط الحالة
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // قفل الاتجاه عمودياً
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'سكرك بإيد',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
      textDirection: TextDirection.rtl,
      locale: const Locale('ar'),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

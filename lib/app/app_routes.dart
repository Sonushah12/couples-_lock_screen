import 'package:get/get.dart';

import '../data/repositories/couple_repository.dart';
import '../modules/home/controllers/home_controller.dart';
import '../modules/home/views/home_view.dart';
import '../modules/onboarding/views/onboarding_view.dart';
import '../modules/features/views/feature_views.dart';
import '../modules/doodle/controllers/doodle_controller.dart';
import '../modules/doodle/views/doodle_view.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/controllers/auth_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController(Get.find<CoupleRepository>()), permanent: true);
  }
}

abstract final class AppRoutes {
  static final pages = [
    GetPage(
      name: '/auth',
      page: () => const AuthView(),
      binding: BindingsBuilder(
        () => Get.lazyPut(() => AuthController(Get.find<CoupleRepository>())),
      ),
    ),
    GetPage(name: '/welcome', page: () => const OnboardingView()),
    GetPage(name: '/profile', page: () => const OnboardingView(edit: true)),
    GetPage(name: '/home', page: () => const HomeView()),
    GetPage(name: '/note', page: () => const ComposeView()),
    GetPage(name: '/question', page: () => const ComposeView(question: true)),
    GetPage(name: '/countdown', page: () => const ComposeView(countdown: true)),
    GetPage(
      name: '/doodle',
      page: () => const DoodleView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => DoodleController())),
    ),
    GetPage(name: '/setup', page: () => const SetupView()),
    GetPage(name: '/pairing', page: () => const PairingView()),
    GetPage(name: '/settings', page: () => const SettingsView()),
  ];
}

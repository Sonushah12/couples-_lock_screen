import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'app/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/couple_repository.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/firebase_config.dart';
import 'data/services/firebase_couple_service.dart';
import 'data/services/notification_service.dart';
import 'core/motion/app_motion.dart';
import 'modules/home/controllers/home_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  FirebaseCoupleService? cloud;
  if (FirebaseConfig.configured) {
    try {
      final firebaseApp = await Firebase.initializeApp(
        name: FirebaseConfig.emulator ? 'pairlight-emulator' : null,
        options: FirebaseConfig.options,
      );
      final auth = FirebaseAuth.instanceFor(app: firebaseApp);
      final db = FirebaseFirestore.instanceFor(app: firebaseApp);
      final functions = FirebaseFunctions.instanceFor(
        app: firebaseApp,
        region: 'asia-south1',
      );
      final storage = FirebaseStorage.instanceFor(app: firebaseApp);
      // Disable disk caching; repository listeners verify access before exposing cached data.
      db.settings = const Settings(persistenceEnabled: false);
      if (FirebaseConfig.emulator) {
        await auth.useAuthEmulator(FirebaseConfig.host, 9099);
        db.useFirestoreEmulator(FirebaseConfig.host, 8080);
        functions.useFunctionsEmulator(FirebaseConfig.host, 5001);
        await storage.useStorageEmulator(FirebaseConfig.host, 9199);
      } else {
        try {
          if (!kIsWeb) {
            await FirebaseAppCheck.instance.activate(
              providerAndroid: kDebugMode
                  ? AndroidDebugProvider(
                      debugToken: FirebaseConfig.debugToken.isEmpty
                          ? null
                          : FirebaseConfig.debugToken,
                    )
                  : const AndroidPlayIntegrityProvider(),
              providerApple: kDebugMode
                  ? AppleDebugProvider(
                      debugToken: FirebaseConfig.debugToken.isEmpty
                          ? null
                          : FirebaseConfig.debugToken,
                    )
                  : const AppleAppAttestWithDeviceCheckFallbackProvider(),
            );
          }
        } catch (e) {
          debugPrint('AppCheck notice: $e');
        }
      }
      cloud = FirebaseCoupleService(
        auth: auth,
        db: db,
        functions: functions,
        storage: storage,
      );
    } catch (e) {
      debugPrint('Firebase init notice: $e');
    }
  }
  final repository = CoupleRepository(
    LocalStorageService(preferences),
    cloud: cloud,
  );
  Get.put(repository, permanent: true);
  repository.start();
  runApp(const PairlightApp());
  if (cloud != null && !FirebaseConfig.emulator) {
    NotificationService(repository).start().catchError((Object _) {
      /* Settings provides a retry. */
    });
  }
}

class PairlightApp extends StatelessWidget {
  const PairlightApp({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'Pairlight',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    initialBinding: AppBinding(),
    initialRoute:
        Get.find<CoupleRepository>().isCloud ||
            Get.find<CoupleRepository>().state['onboarded'] == true
        ? '/home'
        : '/welcome',
    getPages: AppRoutes.pages,
    defaultTransition: Transition.fadeIn,
    transitionDuration: AppMotion.move,
    customTransition: AppRouteTransition(),
    builder: (context, child) {
      final media = MediaQuery.of(context);
      if (!Get.isRegistered<HomeController>()) return child!;
      return Obx(
        () => MediaQuery(
          data: media.copyWith(
            disableAnimations:
                media.disableAnimations ||
                Get.find<HomeController>().reducedMotion.value,
          ),
          child: child!,
        ),
      );
    },
  );
}

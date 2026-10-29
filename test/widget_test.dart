import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pairlight/main.dart';
import 'package:pairlight/data/repositories/couple_repository.dart';
import 'package:pairlight/data/services/local_storage_service.dart';
import 'package:pairlight/modules/home/controllers/home_controller.dart';
import 'package:pairlight/modules/moments/views/moments_view.dart';
import 'package:pairlight/modules/profile/views/us_view.dart';
import 'package:pairlight/modules/widgets_gallery/views/gallery_view.dart';
import 'package:pairlight/modules/pairing/views/pairing_view.dart';
import 'package:pairlight/modules/settings/views/settings_view.dart';
import 'package:pairlight/modules/compose/views/compose_view.dart';
import 'package:pairlight/data/models/moment.dart';
import 'package:pairlight/core/motion/app_motion.dart';
import 'package:pairlight/core/theme/app_theme.dart';

void main() {
  tearDown(() => Get.reset());
  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1024, 768),
  ]) {
    testWidgets('onboarding and dashboard fit $size at large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({});
      Get.put(
        CoupleRepository(
          LocalStorageService(await SharedPreferences.getInstance()),
        ),
      );
      await tester.pumpWidget(const PairlightApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Explore the local demo'), 250);
      await tester.ensureVisible(find.text('Explore the local demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore the local demo'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('Hello, Alex.'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Hello, Alex.')).dy, lessThan(250));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Share my answer'), 250);
      expect(tester.takeException(), isNull);
      await Get.delete<HomeController>(force: true);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('feature screens remain usable at 2x text with reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({'reduce_motion': true});
    final repository = CoupleRepository(
      LocalStorageService(await SharedPreferences.getInstance()),
    );
    await repository.update({
      'name': 'Alex',
      'partner': 'Jamie',
      'onboarded': true,
      'moments': [
        Moment(
          id: 'test_moment_1',
          kind: 'note',
          content: 'A lovely memory from a long afternoon together.',
          createdAt: DateTime.now(),
        ).toJson(),
      ],
      'countdowns': [
        Countdown(
          'Our very long and exciting next adventure together',
          DateTime.now().add(const Duration(days: 400)),
          id: 'test_countdown',
        ).toJson(),
      ],
    });
    Get.put(repository);
    final controller = Get.put(HomeController(repository), permanent: true);
    for (final screen in <Widget>[
      const MomentsView(),
      const UsView(),
      const GalleryView(),
      const PairingView(),
      const SettingsView(),
      const ComposeView(question: true),
    ]) {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 812),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(body: screen),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: screen.runtimeType.toString(),
      );
      expect(controller.reducedMotion.value, isTrue);
    }
    expect(AppMotion.reduced, isTrue);
    await Get.delete<HomeController>(force: true);
    await repository.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    AppMotion.reduced = false;
  });
}

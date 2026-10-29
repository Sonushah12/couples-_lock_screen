import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pairlight/main.dart' as app;
import 'package:pairlight/modules/home/controllers/home_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'RMX: onboarding, note, question, doodle, countdown, native widget',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      final c = Get.find<HomeController>();
      if (!c.onboarded.value) {
        await tester.scrollUntilVisible(
          find.text('Explore the local demo'),
          200,
        );
        await tester.tap(find.text('Explore the local demo'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Hello,'), findsOneWidget);
      Get.toNamed('/note');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'RMX test: thinking of you',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save my note'));
      await tester.tap(find.text('Save my note'));
      await tester.pumpAndSettle();
      expect(c.moments.first.content, 'RMX test: thinking of you');
      Get.toNamed('/question');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Our evening walk');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save my answer'));
      await tester.tap(find.text('Save my answer'));
      await tester.pumpAndSettle();
      expect(c.answer.value, 'Our evening walk');
      Get.toNamed('/doodle');
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('doodle_canvas'));
      await tester.ensureVisible(canvas);
      await tester.pumpAndSettle();
      await tester.drag(canvas, const Offset(50, 30));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save my drawing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save my drawing'));
      await tester.pumpAndSettle();
      expect(c.moments.first.kind, 'doodle');
      Get.toNamed('/countdown');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Our next adventure');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add countdown'));
      await tester.tap(find.text('Add countdown'));
      await tester.pumpAndSettle();
      expect(c.countdowns.last.title, 'Our next adventure');
      expect(
        await c.bridge.update(
          'Alex & Jamie',
          'RMX integration test passed',
          anniversary: DateTime(2025, 2, 14),
        ),
        true,
      );
      c.tab.value = 1;
      await tester.pumpAndSettle();
      expect(find.text('A little drawing for you'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

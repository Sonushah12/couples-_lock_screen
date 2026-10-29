import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/theme/app_theme.dart';

class GalleryView extends StatelessWidget {
  const GalleryView({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Text('Keep us close.', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      const Text('A little connection, right on your home screen.'),
      const SectionTitle('Your everyday companions'),
      AppCard(
        color: AppColors.peach,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.favorite_border),
            const SizedBox(height: 18),
            const Text(
              'Days of us',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Text(
                '${Get.find<HomeController>().daysTogether} days together',
                style: const TextStyle(fontSize: 18, color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Get.toNamed('/setup'),
              child: const Text('Add home screen widget'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppCard(
        color: AppColors.mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.chat_bubble_outline),
            const SizedBox(height: 18),
            const Text(
              'A message from us',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Text(
                Get.find<HomeController>().isCloud
                    ? 'A private preview lets you know when a moment is waiting. Open the app to read it.'
                    : 'Your latest saved moment appears in the same widget.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Lock screen placement depends on your Android version and launcher. On this app’s Android build, use the home screen widget. iOS WidgetKit support is planned.',
      ),
    ],
  );
}

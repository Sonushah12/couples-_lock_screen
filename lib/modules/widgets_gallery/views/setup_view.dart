import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../home/controllers/home_controller.dart';

class SetupView extends StatelessWidget {
  const SetupView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('A little us, on your screen')),
    body: PageBody(
      children: [
        Text(
          'Close, even when\nyour app is closed.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 24),
        ...[
          (
            Icons.touch_app_outlined,
            '1. Make a little space',
            'Long-press an empty area on your home screen.',
          ),
          (
            Icons.widgets_outlined,
            '2. Find Pairlight',
            'Tap Widgets, then choose the Pairlight widget.',
          ),
          (
            Icons.open_with,
            '3. Make it yours',
            'Drag it onto your home screen. Your latest moment stays with you.',
          ),
        ].map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              child: Row(
                children: [
                  Icon(s.$1, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$2,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(s.$3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: () async {
            final c = Get.find<HomeController>();
            try {
              await c.bridge.update(
                '${c.displayName} & ${c.displayPartner}',
                c.isCloud
                    ? 'Open Pairlight for your private moments.'
                    : c.moments.firstOrNull?.content ??
                          'A little closer, every day.',
                spaceId: c.repository.spaceId,
                anniversary: c.anniversary.value,
              );
              final pinned = await c.bridge.pin();
              if (!pinned) {
                Get.snackbar(
                  'Add manually',
                  'Follow the three steps above; your launcher does not support automatic pinning.',
                );
              }
            } catch (_) {
              Get.snackbar(
                'Widget unavailable',
                'Use the Android build to add a home screen widget.',
              );
            }
          },
          child: const Text('Add widget'),
        ),
      ],
    ),
  );
}

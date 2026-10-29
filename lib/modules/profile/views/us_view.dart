import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/theme/app_theme.dart';

class UsView extends GetView<HomeController> {
  const UsView({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Text(
        'The story of us.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 24),
      AppCard(
        child: Obx(
          () => Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Avatar(controller.displayName),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(Icons.favorite_border),
                  ),
                  Avatar(controller.displayPartner, color: AppColors.mint),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${controller.displayName} & ${controller.displayPartner}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.relationship.value} • ${controller.daysTogether} days together',
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Get.toNamed('/pairing'),
                child: const Text('Partner connection'),
              ),
            ],
          ),
        ),
      ),
      SectionTitle(
        'Things to look forward to',
        action: 'Add',
        onTap: () => Get.toNamed('/countdown'),
      ),
      Obx(
        () => controller.countdowns.isEmpty
            ? const EmptyState(
                'Make a date',
                'Add your next visit, anniversary, or little adventure.',
                icon: Icons.calendar_today_outlined,
              )
            : Column(
                children: controller.countdowns.map((c) {
                  final days = c.daysFrom(DateTime.now());
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  days < 0
                                      ? '${-days} days ago'
                                      : days == 0
                                      ? 'Today'
                                      : '$days days',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (c.id != null)
                            IconButton(
                              tooltip: 'Remove countdown',
                              onPressed: () async {
                                final confirmed = await Get.dialog<bool>(
                                  AlertDialog(
                                    title: const Text('Remove this date?'),
                                    content: Text(c.title),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Get.back(result: false),
                                        child: const Text('Keep it'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Get.back(result: true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await controller.removeItem(
                                    'countdowns',
                                    c.id!,
                                  );
                                }
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => Get.toNamed('/profile'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit our details'),
      ),
      const SizedBox(height: 16),
      Obx(
        () => Text(
          controller.paired
              ? 'A shared story, one little moment at a time. No location data is collected.'
              : 'Invite your person to start sharing. No location data is collected.',
        ),
      ),
    ],
  );
}

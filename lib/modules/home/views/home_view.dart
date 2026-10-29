import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/together_scene.dart';
import '../controllers/home_controller.dart';
import '../../features/views/feature_views.dart';
import '../../onboarding/views/onboarding_view.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/widgets/connection_status.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const _tabs = [
    HomeDashboard(),
    MomentsView(),
    GalleryView(),
    UsView(),
  ];

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.isCloud && controller.loading.value) {
      return const Scaffold(body: Center(child: Text('Opening your space…')));
    }
    if (controller.isCloud &&
        !controller.onboarded.value &&
        controller.cloudError.value == null) {
      return const OnboardingView();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flare_rounded),
            SizedBox(width: 8),
            Text(
              'pairlight',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.8),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Get.toNamed('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const ConnectionStatus(),
          Expanded(
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: AppMotion.resolve(context, AppMotion.quick),
                layoutBuilder: (current, previous) =>
                    current ?? const SizedBox.shrink(),
                child: KeyedSubtree(
                  key: ValueKey(controller.tab.value),
                  child: _tabs[controller.tab.value],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.cream,
        indicatorColor: AppColors.peach,
        selectedIndex: controller.tab.value,
        onDestinationSelected: (i) {
          controller.tab.value = i;
          AppMotion.selection();
        },
        animationDuration: AppMotion.resolve(context, AppMotion.quick),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Our space',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Moments',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            label: 'Widgets',
          ),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Us'),
        ],
      ),
    );
  });
}

class HomeDashboard extends GetView<HomeController> {
  const HomeDashboard({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A LITTLE CLOSER, EVERY DAY',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => Text(
                    'Hello, ${controller.displayName}.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
          ),
          Obx(() => Avatar(controller.displayName)),
        ],
      ),
      const SizedBox(height: 24),
      Obx(
        () => TogetherScene(
          names: '${controller.displayName} & ${controller.displayPartner}',
          days: controller.daysTogether,
        ),
      ),
      const SizedBox(height: 12),
      Obx(
        () => Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                controller.isCloud
                    ? controller.paired
                          ? 'Your private space • Connected'
                          : 'Your cloud space • Invite your person'
                    : 'Your private space • Local mode',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      Obx(
        () => controller.isCloud && !controller.hasSpace
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: () => Get.toNamed('/pairing'),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Connect with your person'),
                ),
              )
            : const SizedBox.shrink(),
      ),
      const SectionTitle('Send a little love'),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            MomentAction(
              'Thinking of you',
              Icons.favorite_border,
              AppColors.peach,
              () => _send('Thinking of you'),
              width: (constraints.maxWidth - 10) / 2,
            ),
            MomentAction(
              'A warm hug',
              Icons.diversity_1_outlined,
              AppColors.mint,
              () => _send('Sending you a warm hug'),
              width: (constraints.maxWidth - 10) / 2,
            ),
            MomentAction(
              'Little note',
              Icons.edit_note_outlined,
              const Color(0xFFE9DFF0),
              () => Get.toNamed('/note'),
              width: (constraints.maxWidth - 10) / 2,
            ),
            MomentAction(
              'Draw for them',
              Icons.brush_outlined,
              const Color(0xFFF4E7C8),
              () => Get.toNamed('/doodle'),
              width: (constraints.maxWidth - 10) / 2,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Obx(
        () => OutlinedButton.icon(
          onPressed: controller.busy.value ? null : controller.sharePhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: BusyLabel('Share a photo', busy: controller.busy.value),
        ),
      ),
      const SectionTitle('One question. Two hearts.'),
      AppCard(
        color: const Color(0xFFEDE6F2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny_outlined, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'TODAY’S QUESTION',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Obx(
              () => Text(
                controller.todayQuestion,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Make a little time for a meaningful conversation.'),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton(
                onPressed: () => Get.toNamed('/question'),
                child: Text(
                  controller.answer.isEmpty
                      ? 'Share my answer'
                      : 'Read my answer',
                ),
              ),
            ),
          ],
        ),
      ),
      SectionTitle(
        'Made for your everyday',
        action: 'Explore',
        onTap: () => controller.tab.value = 2,
      ),
      AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.widgets_outlined),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A little us, on your screen',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('Add your first home screen widget.'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open widget setup',
              onPressed: () => Get.toNamed('/setup'),
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> _send(String message) async {
    if (await controller.send('moment', message)) {
      Get.snackbar(
        controller.isCloud ? 'A little love, shared' : 'A little love, saved',
        controller.saveMessage,
        backgroundColor: AppColors.peach,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

class MomentAction extends StatefulWidget {
  const MomentAction(
    this.title,
    this.icon,
    this.color,
    this.onTap, {
    super.key,
    required this.width,
  });
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double width;
  @override
  State<MomentAction> createState() => _MomentActionState();
}

class _MomentActionState extends State<MomentAction> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale:
        pressed && AppMotion.resolve(context, AppMotion.press) != Duration.zero
        ? .975
        : 1,
    duration: AppMotion.resolve(context, AppMotion.press),
    child: SizedBox(
      width: widget.width,
      child: Material(
        color: widget.color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => pressed = value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.icon, color: AppColors.ink),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

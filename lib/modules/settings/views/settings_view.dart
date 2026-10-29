import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../core/motion/app_motion.dart';
import '../../../data/services/notification_service.dart';
import '../../home/controllers/home_controller.dart';

class SettingsView extends GetView<HomeController> {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: Obx(
      () => PageBody(
        children: [
          Text(
            'Your space. Your choice.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Private by default',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  controller.isCloud
                      ? 'Your shared moments are stored in Firebase and accessible to members of your space. Notifications and home screen widgets use generic previews. Daily answers stay hidden from your person until you answer. No location data is collected.'
                      : 'Local mode saves profiles, notes, drawings, answers, and dates on this phone. Sign in to share across phones. Local preferences are not an encrypted vault.',
                ),
              ],
            ),
          ),
          const SectionTitle('Make it feel like you'),
          AppCard(
            padding: 8,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Reduce motion'),
                  subtitle: const Text(
                    'Gentler transitions. Also respects your device setting.',
                  ),
                  value: controller.reducedMotion.value,
                  onChanged: controller.setMotion,
                ),
                SwitchListTile(
                  title: const Text('Touch feedback'),
                  subtitle: const Text(
                    'A small haptic when an action succeeds.',
                  ),
                  value: controller.haptics.value,
                  onChanged: controller.setHaptics,
                ),
                if (controller.isCloud)
                  SwitchListTile(
                    title: const Text('Partner notifications'),
                    subtitle: const Text(
                      'Turn on to allow private, generic alerts on this phone.',
                    ),
                    value: controller.repository.state['notifications'] == true,
                    onChanged: controller.busy.value
                        ? null
                        : (enabled) => controller.perform(() async {
                            final service = NotificationService.instance;
                            if (service == null) {
                              throw StateError(
                                'Notifications are not available in this build.',
                              );
                            }
                            if (!await service.enable(enabled)) {
                              throw StateError(
                                'Enable Pairlight notifications in your phone settings, then try again.',
                              );
                            }
                          }),
                  ),
              ],
            ),
          ),
          const SectionTitle('Your account and space'),
          AppCard(
            padding: 4,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Edit profile and anniversary'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed('/profile'),
                ),
                ListTile(
                  leading: const Icon(Icons.widgets_outlined),
                  title: const Text('Widget setup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed('/setup'),
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Partner connection'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed('/pairing'),
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Copy data export'),
                  subtitle: const Text(
                    'Profile, moments, drawings, answers, and dates as JSON',
                  ),
                  onTap: controller.busy.value ? null : controller.exportData,
                ),
                if (controller.isCloud)
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    subtitle: Text(
                      controller.repository.cloud!.auth.currentUser?.email ??
                          '',
                    ),
                    onTap: controller.busy.value ? null : controller.signOut,
                  ),
                if (!controller.isCloud && controller.repository.cloud != null)
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Sign in to Firebase'),
                    onTap: () => Get.toNamed('/auth'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: controller.busy.value ? null : () => _delete(context),
            icon: const Icon(Icons.delete_outline),
            label: BusyLabel(
              controller.isCloud
                  ? 'Delete my account'
                  : 'Delete all local data',
              busy: controller.busy.value,
            ),
          ),
          const SizedBox(height: 32),
          const Center(child: Text('Pairlight • Made for little moments')),
        ],
      ),
    ),
  );
  Future<void> _delete(BuildContext context) async {
    final cloud = controller.isCloud;
    final password = TextEditingController();
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(cloud ? 'Delete your account?' : 'Delete local data?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cloud
                    ? 'This permanently deletes your account, your shared contributions, and your photos. Your person’s own contributions remain in their space. Enter your password to confirm.'
                    : 'This permanently removes all saved moments, drawings, answers, dates, and your profile from this phone.',
              ),
              if (cloud) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  autofillHints: const [AutofillHints.password],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep my space'),
          ),
          FilledButton(
            onPressed: () {
              if (!cloud || password.text.isNotEmpty) Get.back(result: true);
            },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    final value = password.text;
    // Let the dialog route finish disposing its field before disposing the controller.
    await Future<void>.delayed(AppMotion.move);
    password.dispose();
    if (confirmed == true) {
      if (cloud) {
        await controller.deleteAccount(value);
      } else {
        await controller.deleteData();
      }
    }
  }
}

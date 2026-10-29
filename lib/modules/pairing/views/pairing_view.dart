import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/controllers/home_controller.dart';

class PairingView extends StatefulWidget {
  const PairingView({super.key});
  @override
  State<PairingView> createState() => _PairingViewState();
}

class _PairingViewState extends State<PairingView> {
  final code = TextEditingController();
  final form = GlobalKey<FormState>();
  HomeController get c => Get.find<HomeController>();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Partner connection')),
    body: Obx(
      () => PageBody(
        children: [
          Text(
            c.paired
                ? 'A little world, for two.'
                : 'Make room for your person.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'One private space. Two people. Little moments that travel between you.',
          ),
          const SizedBox(height: 24),
          if (!c.isCloud) ...[
            const EmptyState(
              'Start with your account',
              'Sign in to create an invitation and share moments across phones.',
              icon: Icons.people_outline,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: c.repository.cloud == null
                  ? null
                  : () => Get.toNamed('/auth'),
              child: const Text('Sign in to connect'),
            ),
            if (c.repository.cloud == null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Cloud connection is not configured in this build. You can keep exploring locally.',
                ),
              ),
          ] else if (!c.verified) ...[
            const EmptyState(
              'A quick email check',
              'Open the verification email to protect your account before connecting.',
              icon: Icons.mark_email_read_outlined,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: c.busy.value ? null : c.refreshVerification,
              child: BusyLabel('I have verified', busy: c.busy.value),
            ),
            TextButton(
              onPressed: c.busy.value ? null : c.sendVerification,
              child: const Text('Resend verification email'),
            ),
          ] else if (c.paired) ...[
            AppCard(
              color: AppColors.peach,
              child: Column(
                children: [
                  const Icon(Icons.favorite_rounded, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    '${c.displayName} & ${c.displayPartner}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connected • Your shared space is ready',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Get.offAllNamed('/home'),
              child: const Text('Back to our space'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Get.toNamed('/settings'),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Choose moment notifications'),
            ),
            OutlinedButton(
              onPressed: c.busy.value ? null : () => _disconnect(),
              child: const Text('Disconnect from this space'),
            ),
          ] else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Invite your person',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share a private code with them. Only the latest code works, and it expires after 24 hours.',
                  ),
                  if (c.inviteCode.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SelectableText(
                      c.inviteCode.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (c.inviteExpires.value != null)
                      Text(
                        'Expires ${c.inviteExpires.value!.toLocal()}',
                        textAlign: TextAlign.center,
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: c.inviteCode.value),
                        );
                        Get.snackbar(
                          'Code copied',
                          'Share it privately with your person.',
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy invitation'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: c.busy.value ? null : c.createInvite,
                    child: BusyLabel(
                      c.inviteCode.isEmpty
                          ? 'Create invitation'
                          : 'Create a new code',
                      busy: c.busy.value,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!c.hasSpace)
              AppCard(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Already have a code?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: code,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 12,
                        decoration: const InputDecoration(
                          labelText: 'Invitation code',
                        ),
                        validator: (value) =>
                            value == null ||
                                !RegExp(r'^[a-fA-F0-9]{12}$')
                                    .hasMatch(value.trim())
                            ? 'Enter the 12-character code'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: c.busy.value
                            ? null
                            : () async {
                                if (form.currentState!.validate() &&
                                    await c.acceptInvite(code.text)) {
                                  Get.snackbar(
                                    'You’re connected',
                                    'Your shared space is ready.',
                                  );
                                }
                              },
                        child: const Text('Join their space'),
                      ),
                    ],
                  ),
                ),
              ),
            if (c.hasSpace)
              TextButton(
                onPressed: c.busy.value ? null : () => _disconnect(),
                child: const Text(
                  'Leave this space to join another invitation',
                ),
              ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Keep invitation codes private. Disconnecting removes your access; the other person keeps their space.',
          ),
        ],
      ),
    ),
  );
  Future<void> _disconnect() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Leave this space?'),
        content: const Text(
          'You will lose access to this space’s moments and dates. The other person keeps their access. If you are its only member, the space will be deleted. Export anything you want to keep first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirm == true) await c.disconnect();
  }
}

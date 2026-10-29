import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/motion/app_motion.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key, this.edit = false});
  final bool edit;
  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), partner = TextEditingController();
  int step = 0;
  String relationship = 'Couple';
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    if (widget.edit) {
      final c = Get.find<HomeController>();
      step = 1;
      name.text = c.name.value;
      partner.text = c.partner.value;
      relationship = c.relationship.value;
      date = c.anniversary.value;
    }
  }

  @override
  void dispose() {
    name.dispose();
    partner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        children: [
          Row(
            children: [
              if (widget.edit)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back),
                ),
              const Icon(Icons.flare_rounded, color: AppColors.ink),
              const SizedBox(width: 8),
              Text('pairlight', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 48),
          AppCard(
            color: AppColors.peach,
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.nights_stay_outlined,
                  size: 80,
                  color: AppColors.ink,
                ),
                const SizedBox(height: 24),
                Text(
                  step == 0
                      ? 'Your own little\ncorner of the world.'
                      : 'Make room for\nyour favorite person.',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Small moments. Shared rituals.\nA connection that feels like home.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (step == 0) ...[
            const Text(
              '01 / A SPACE FOR TWO',
              style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Send a little love, draw a memory, and keep your person close with a home screen widget.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final c = Get.find<HomeController>();
                if (c.repository.cloud != null && !c.isCloud) {
                  Get.toNamed('/auth');
                } else {
                  setState(() => step = 1);
                }
              },
              child: Text(
                Get.find<HomeController>().isCloud
                    ? 'Set up my profile'
                    : 'Create our space',
              ),
            ),
            if (Get.find<HomeController>().isCloud)
              TextButton(
                onPressed: Get.find<HomeController>().signOut,
                child: const Text('Sign out'),
              ),
            if (!Get.find<HomeController>().isCloud)
              TextButton(
                onPressed: () async {
                  final c = Get.find<HomeController>();
                  if (await c.setup(
                    'Alex',
                    'Jamie',
                    'Couple',
                    DateTime.now().subtract(const Duration(days: 365)),
                  )) {
                    Get.offAllNamed('/home');
                  }
                },
                child: const Text('Explore the local demo'),
              ),
          ] else
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Your name'),
                    maxLength: 30,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (!Get.find<HomeController>().isCloud)
                    TextFormField(
                      controller: partner,
                      decoration: const InputDecoration(
                        labelText: 'Your person’s name (optional)',
                      ),
                      maxLength: 30,
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: relationship,
                    decoration: const InputDecoration(
                      labelText: 'Our connection',
                    ),
                    items: ['Couple', 'Friends', 'Family']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => relationship = v!,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => date = d);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Together since ${date.day}/${date.month}/${date.year}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => FilledButton(
                      onPressed: Get.find<HomeController>().busy.value
                          ? null
                          : () async {
                              if (form.currentState!.validate() &&
                                  await Get.find<HomeController>().setup(
                                    name.text,
                                    partner.text,
                                    relationship,
                                    date,
                                  )) {
                                Get.offAllNamed('/home');
                              }
                            },
                      child: BusyLabel(
                        'Let’s begin',
                        busy: Get.find<HomeController>().busy.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Get.find<HomeController>().isCloud
                        ? 'Your profile is saved to your account.\nInvite your person next to share your space.'
                        : 'Local mode • Saved on this phone.\nSign in to connect with your person.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

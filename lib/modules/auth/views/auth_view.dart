import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../core/motion/app_motion.dart';
import '../controllers/auth_controller.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool register = false, obscure = true;
  AuthController get controller => Get.find<AuthController>();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your Pairlight account')),
    body: PageBody(
      children: [
        const Icon(Icons.favorite_outline, size: 48),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: AppMotion.resolve(context, AppMotion.quick),
          child: Text(
            register ? 'A space worth sharing.' : 'Welcome back, you.',
            key: ValueKey(register),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          register
              ? 'Create an account, then invite your favorite person.'
              : 'Sign in to your shared moments and little rituals.',
        ),
        const SizedBox(height: 28),
        AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) =>
                      value == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? 'Enter a valid email address'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: obscure,
                  autofillHints: [
                    register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: register ? 'At least 8 characters' : null,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password'
                      : register && value.length < 8
                      ? 'Use at least 8 characters'
                      : null,
                  onFieldSubmitted: (_) {
                    if (form.currentState!.validate()) {
                      controller.submit(email.text, password.text, register);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => controller.error.value == null
              ? const SizedBox.shrink()
              : Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.error.value!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
        ),
        Obx(
          () => controller.message.value == null
              ? const SizedBox.shrink()
              : Semantics(
                  liveRegion: true,
                  child: Text(controller.message.value!),
                ),
        ),
        const SizedBox(height: 20),
        Obx(
          () => FilledButton(
            onPressed: controller.busy.value
                ? null
                : () {
                    if (form.currentState!.validate()) {
                      controller.submit(email.text, password.text, register);
                    }
                  },
            child: BusyLabel(
              register ? 'Create account' : 'Sign in',
              busy: controller.busy.value,
            ),
          ),
        ),
        if (!register)
          Obx(
            () => TextButton(
              onPressed: controller.busy.value
                  ? null
                  : () {
                      if (email.text.trim().isEmpty) {
                        controller.error.value =
                            'Enter your email above to request a reset link.';
                        return;
                      }
                      controller.reset(email.text);
                    },
              child: const Text('Forgot password?'),
            ),
          ),
        TextButton(
          onPressed: () {
            if (!controller.busy.value) {
              setState(() => register = !register);
              controller.error.value = null;
              controller.message.value = null;
            }
          },
          child: Text(
            register
                ? 'Already have an account? Sign in'
                : 'New here? Create an account',
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => OutlinedButton.icon(
            onPressed:
                controller.busy.value ? null : controller.signInAnonymously,
            icon: const Icon(Icons.person_pin_outlined),
            label: const Text('Instant Guest Sign-In (Quick Test)'),
          ),
        ),
        const SizedBox(height: 16),
        const AppCard(
          child: Row(
            children: [
              Icon(Icons.shield_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Only members of your space can access its shared moments. Your account stays yours.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

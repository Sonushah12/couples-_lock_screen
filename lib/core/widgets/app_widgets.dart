import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../motion/app_motion.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 20,
  });
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border.withValues(alpha: .6)),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: .035),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

class PageBody extends StatefulWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  State<PageBody> createState() => _PageBodyState();
}

class _PageBodyState extends State<PageBody> {
  final controller = ScrollController(keepScrollOffset: false);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Reveal(
        child: ListView(
          controller: controller,
          primary: false,
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
            16,
            MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
            32,
          ),
          children: widget.children,
        ),
      ),
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.color = AppColors.peach});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 24,
    backgroundColor: color,
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.subtitle, {
    super.key,
    this.icon = Icons.auto_awesome_outlined,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.muted),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}

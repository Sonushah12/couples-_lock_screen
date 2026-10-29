import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/moment.dart';
import '../../home/controllers/home_controller.dart';
import '../../doodle/views/doodle_view.dart';

class MomentsView extends GetView<HomeController> {
  const MomentsView({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Obx(
        () => CustomScrollView(
          key: const PageStorageKey('moments'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              sliver: SliverToBoxAdapter(
                child: Reveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Little things.\nLasting feelings.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your notes, hugs, photos, and hand-drawn hellos.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => Get.toNamed('/note'),
                        icon: const Icon(Icons.add),
                        label: const Text('Write a little note'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: controller.busy.value
                            ? null
                            : controller.sharePhoto,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Share a photo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (controller.moments.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    'Your story starts here',
                    'Send your first moment from Our space.',
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: controller.moments.length,
                itemBuilder: (context, index) {
                  final moment = controller.moments[index];
                  return Padding(
                    key: ValueKey(moment.id),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _MomentCard(moment: moment),
                  );
                },
              ),
            ),
            if (controller.hasMore)
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: OutlinedButton(
                    onPressed: controller.busy.value
                        ? null
                        : controller.loadMore,
                    child: BusyLabel(
                      'Load earlier moments',
                      busy: controller.busy.value,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ),
  );
}

class _MomentCard extends GetView<HomeController> {
  const _MomentCard({required this.moment});
  final Moment moment;
  @override
  Widget build(BuildContext context) {
    final own =
        !controller.isCloud || moment.senderId == controller.repository.uid;
    final from = moment.senderName ?? controller.displayName;
    final when = moment.createdAt.toLocal();
    final icon = switch (moment.kind) {
      'doodle' => Icons.brush_outlined,
      'photo' => Icons.photo_outlined,
      'note' => Icons.edit_note,
      _ => Icons.favorite_border,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: own ? AppColors.peach : AppColors.mint,
                child: Icon(icon, color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      own ? 'From you' : 'From $from',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${when.day}/${when.month}/${when.year} • ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (own)
                IconButton(
                  tooltip: 'Delete this moment',
                  onPressed: controller.busy.value
                      ? null
                      : () async {
                          final confirmed = await Get.dialog<bool>(
                            AlertDialog(
                              title: const Text('Delete this moment?'),
                              content: const Text(
                                'This removes the moment from your space for both people.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(result: false),
                                  child: const Text('Keep it'),
                                ),
                                FilledButton(
                                  onPressed: () => Get.back(result: true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await controller.removeItem('moments', moment.id);
                          }
                        },
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(moment.content, style: Theme.of(context).textTheme.bodyLarge),
          if (moment.drawing != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                label: 'A drawing from $from',
                child: RepaintBoundary(
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CustomPaint(painter: DoodlePainter(moment.drawing!)),
                  ),
                ),
              ),
            ),
          if (moment.photoPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: PrivatePhoto(
                key: ValueKey(moment.photoPath),
                path: moment.photoPath!,
              ),
            ),
        ],
      ),
    );
  }
}

class PrivatePhoto extends StatefulWidget {
  const PrivatePhoto({super.key, required this.path});
  final String path;
  @override
  State<PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<PrivatePhoto> {
  late Future<Uint8List?> bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    bytes = Get.find<HomeController>().repository.photo(widget.path);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: FutureBuilder<Uint8List?>(
      future: bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (snapshot.connectionState == ConnectionState.done &&
                snapshot.data == null)) {
          return AppCard(
            child: Column(
              children: [
                const Text('Photo could not load.'),
                TextButton(
                  onPressed: () => setState(_load),
                  child: const Text('Retry photo'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: Text('Loading your memory…')),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          semanticLabel: 'A photo shared in your space',
          cacheWidth: 1200,
        );
      },
    ),
  );
}

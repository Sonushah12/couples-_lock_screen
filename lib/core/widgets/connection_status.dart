import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../modules/home/controllers/home_controller.dart';
import '../theme/app_theme.dart';

class ConnectionStatus extends GetView<HomeController> {
  const ConnectionStatus({super.key});
  @override
  Widget build(BuildContext context) => Obx(() {
    final error = controller.cloudError.value;
    if (error == null && !controller.cached.value && !controller.busy.value) {
      return const SizedBox.shrink();
    }
    return Material(
      color: AppColors.peach,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              error != null ? Icons.cloud_off_outlined : Icons.cloud_outlined,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error ??
                      (controller.busy.value
                          ? 'Saving your changes…'
                          : 'Showing cached data. Connect to refresh.'),
                ),
              ),
            ),
            if (error != null)
              TextButton(
                onPressed: controller.repository.refresh,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  });
}

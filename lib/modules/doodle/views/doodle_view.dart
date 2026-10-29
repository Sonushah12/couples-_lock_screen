import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/doodle_controller.dart';
import '../../../core/motion/app_motion.dart';

class DoodleView extends GetView<DoodleController> {
  const DoodleView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('A hand-drawn hello'),
      actions: [
        IconButton(
          tooltip: 'Undo last stroke',
          onPressed: controller.undo,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Clear drawing',
          onPressed: controller.clear,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: PageBody(
      children: [
        Text(
          'Made by you.\nJust for them.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Draw something that words can’t quite say.'),
        const SizedBox(height: 24),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ColoredBox(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Semantics(
                    label: 'Drawing canvas. Drag to draw. Use the note option for a text alternative.',
                    child: GestureDetector(
                      key: const ValueKey('doodle_canvas'),
                      onPanStart: (d) => controller.add(d.localPosition, size),
                      onPanUpdate: (d) => controller.add(d.localPosition, size),
                      onPanEnd: (_) => controller.end(),
                      onPanCancel: controller.end,
                      child: Obx(
                        () => CustomPaint(
                          size: size,
                          painter: DoodlePainter(controller.points),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => Wrap(
            spacing: 12,
            children: [
              AppColors.ink,
              const Color(0xFFAD4960),
              const Color(0xFF47785B),
              const Color(0xFFCF812E),
              const Color(0xFF7666AF),
            ].map((color) {
              final selected = controller.color.value == color;
              return Semantics(
                selected: selected,
                child: IconButton(
                  tooltip: 'Ink ${color.toARGB32().toRadixString(16)}',
                  style: IconButton.styleFrom(
                    backgroundColor: color.withValues(alpha: .15),
                  ),
                  onPressed: () => controller.color.value = color,
                  icon: Icon(
                    selected ? Icons.check_circle : Icons.circle,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Obx(
          () => FilledButton(
            onPressed:
                !controller.hasDrawing || Get.find<HomeController>().busy.value
                ? null
                : () async {
                    if (await Get.find<HomeController>().send(
                      'doodle',
                      'A little drawing for you',
                      drawing: controller.points
                          .map((p) => List<double>.from(p))
                          .toList(),
                    )) {
                      Get.back();
                    }
                  },
            child: BusyLabel(
              Get.find<HomeController>().isCloud
                  ? 'Share my drawing'
                  : 'Save my drawing',
              busy: Get.find<HomeController>().busy.value,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Get.offNamed('/note'),
          child: const Text('Write a note instead'),
        ),
      ],
    ),
  );
}

class DoodlePainter extends CustomPainter {
  DoodlePainter(this.points);
  final List<List<double>> points;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final strokePaint = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    Path? currentPath;
    int currentColor = -1;
    bool hasMoved = false;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p[0] < 0) {
        if (currentPath != null) {
          canvas.drawPath(currentPath, strokePaint);
          currentPath = null;
        }
        hasMoved = false;
        continue;
      }

      final colorInt = p[2].toInt();
      final at = Offset(p[0] * size.width, p[1] * size.height);

      if (colorInt != currentColor) {
        if (currentPath != null) {
          canvas.drawPath(currentPath, strokePaint);
          currentPath = null;
        }
        currentColor = colorInt;
        strokePaint.color = Color(currentColor);
        dotPaint.color = Color(currentColor);
      }

      final nextIsEnd = (i + 1 >= points.length) || (points[i + 1][0] < 0);
      final prevIsEnd = (i == 0) || (points[i - 1][0] < 0);

      if (prevIsEnd && nextIsEnd) {
        canvas.drawCircle(at, 2, dotPaint);
      } else {
        if (!hasMoved || currentPath == null) {
          currentPath ??= Path();
          currentPath.moveTo(at.dx, at.dy);
          hasMoved = true;
        } else {
          currentPath.lineTo(at.dx, at.dy);
        }
      }
    }

    if (currentPath != null) {
      canvas.drawPath(currentPath, strokePaint);
    }
  }

  @override
  bool shouldRepaint(DoodlePainter oldDelegate) {
    if (identical(points, oldDelegate.points)) return false;
    return points.length != oldDelegate.points.length;
  }
}

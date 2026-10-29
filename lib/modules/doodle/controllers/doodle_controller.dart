import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DoodleController extends GetxController {
  final points = <List<double>>[].obs;
  final color = const Color(0xFF2A1F3D).obs;
  void add(Offset point, Size size) => points.add([
    (point.dx / size.width).clamp(0.0, 1.0),
    (point.dy / size.height).clamp(0.0, 1.0),
    color.value.toARGB32().toDouble(),
  ]);
  void end() => points.add([-1, -1, 0]);
  void clear() => points.clear();
  void undo() {
    if (points.isEmpty) return;
    if (points.last[0] == -1) points.removeLast();
    while (points.isNotEmpty && points.last[0] != -1) {
      points.removeLast();
    }
  }

  bool get hasDrawing => points.any((p) => p[0] >= 0);
}

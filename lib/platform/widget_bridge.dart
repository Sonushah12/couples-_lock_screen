import 'package:flutter/services.dart';

class WidgetBridge {
  static const _channel = MethodChannel('pairlight/widget');
  Future<bool> update(
    String title,
    String message, {
    String? spaceId,
    DateTime? anniversary,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('update', {
            'title': title,
            'message': message,
            'spaceId': spaceId ?? '',
            'anniversary': anniversary?.toIso8601String().substring(0, 10) ?? '',
          }) ??
          false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  Future<bool> pin() async {
    try {
      return await _channel.invokeMethod<bool>('pin') ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }
}

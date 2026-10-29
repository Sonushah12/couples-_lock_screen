import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../repositories/couple_repository.dart';
import '../../modules/home/controllers/home_controller.dart';
import 'firebase_config.dart';

@pragma('vm:entry-point')
Future<void> pairlightBackgroundMessage(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
  }
  // Android's permission-protected native receiver updates its widget after
  // matching the incoming space to the active widget state. Private content
  // is fetched only when the authenticated app is opened.
}

class NotificationService {
  NotificationService(this.repository);
  static NotificationService? instance;
  final CoupleRepository repository;
  final local = FlutterLocalNotificationsPlugin();
  final List<StreamSubscription<dynamic>> subscriptions = [];
  String? _registeredUid, _token;
  bool _registering = false;
  static const channel = AndroidNotificationChannel(
    'pairlight_moments',
    'Shared moments',
    description: 'Little moments from your person',
    importance: Importance.high,
  );
  Future<void> start() async {
    instance = this;
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('pairlight_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _open(),
    );
    await local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    FirebaseMessaging.onBackgroundMessage(pairlightBackgroundMessage);
    subscriptions.add(repository.changes.listen((_) => _registerIfAllowed()));
    subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _token = token;
        _registeredUid = null;
        await _registerIfAllowed();
      }),
    );
    subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) async {
        if (!repository.isCloud ||
            !repository.paired ||
            repository.state['notifications'] == false ||
            message.data['spaceId'] != repository.spaceId) {
          return;
        }
        await local.show(
          id: message.messageId.hashCode & 0x7fffffff,
          title: 'A little moment for you',
          body: 'Open Pairlight to see what your person shared.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'pairlight_moments',
              'Shared moments',
              icon: 'pairlight_notification',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }),
    );
    subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (message.data['spaceId'] == repository.spaceId) _open();
      }),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Profile restoration is asynchronous; validate the space when it becomes available.
      StreamSubscription<void>? pending;
      pending = repository.changes.listen((_) {
        if (repository.loading) return;
        if (initial.data['spaceId'] == repository.spaceId) _open();
        pending?.cancel();
      });
      subscriptions.add(pending);
    }
    await _registerIfAllowed();
  }

  void _open() {
    if (!repository.isCloud || !Get.isRegistered<HomeController>()) {
      return;
    }
    Get.find<HomeController>().tab.value = 1;
    Get.offAllNamed('/home');
  }

  Future<void> _registerIfAllowed() async {
    if (_registering ||
        !repository.isCloud ||
        repository.state['onboarded'] != true ||
        repository.state['notifications'] != true ||
        _registeredUid == repository.uid) {
      return;
    }
    _registering = true;
    final uid = repository.uid;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      _token ??= await FirebaseMessaging.instance.getToken();
      if (_token != null && uid == repository.uid) {
        await repository.cloud!.call('registerDevice', {'token': _token});
        _registeredUid = uid;
      }
    } catch (_) {
      /* Notifications retry on a later state update; sync remains usable. */
    } finally {
      _registering = false;
    }
  }

  Future<bool> enable(bool enabled) async {
    if (enabled) {
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
    }
    await repository.cloud!.call('notificationSettings', {'enabled': enabled});
    _registeredUid = null;
    if (enabled) {
      await _registerIfAllowed();
    } else {
      await unregister();
    }
    return true;
  }

  Future<void> unregister({bool invalidateToken = false}) async {
    try {
      if (repository.isCloud && _token != null) {
        await repository.cloud!.call('unregisterDevice', {'token': _token});
      }
    } finally {
      _registeredUid = null;
      await local.cancelAll();
      if (invalidateToken) {
        _token = null;
        await FirebaseMessaging.instance.deleteToken();
      }
    }
  }
}

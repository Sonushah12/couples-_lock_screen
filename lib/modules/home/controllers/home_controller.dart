import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/motion/app_motion.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/firebase_couple_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/models/moment.dart';
import '../../../data/models/couple_state.dart';
import '../../../platform/widget_bridge.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController(this.repository);
  final CoupleRepository repository;
  final name = ''.obs, partner = ''.obs, relationship = 'Couple'.obs;
  final onboarded = false.obs, busy = false.obs;
  final tab = 0.obs;
  final revision = 0.obs;
  final moments = <Moment>[].obs;
  final countdowns = <Countdown>[].obs;
  final answer = ''.obs, partnerAnswer = ''.obs;
  final anniversary = DateTime.now().obs;
  final bridge = WidgetBridge();
  final reducedMotion = false.obs, haptics = true.obs;
  final cloudError = RxnString();
  final cached = false.obs, loading = false.obs;
  final inviteCode = ''.obs;
  final inviteExpires = Rxn<DateTime>();
  StreamSubscription<void>? _subscription;
  Timer? _dayTimer;
  String? _widgetMoment;
  String? _lastUid;
  String _day = '';
  String get displayName => name.value.isEmpty ? 'You' : name.value;
  String get displayPartner =>
      partner.value.isEmpty ? 'Your person' : partner.value;
  bool get isCloud {
    revision.value;
    return repository.isCloud;
  }

  bool get paired {
    revision.value;
    return repository.paired;
  }

  bool get hasSpace {
    revision.value;
    return repository.spaceId != null;
  }

  bool get verified {
    revision.value;
    return repository.verified;
  }

  bool get hasMore {
    revision.value;
    return repository.hasMore;
  }

  int get daysTogether =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
          .difference(
            DateTime(
              anniversary.value.year,
              anniversary.value.month,
              anniversary.value.day,
            ),
          )
          .inDays
          .clamp(0, 99999);
  String get questionKey {
    revision.value;
    return repository.day;
  }

  static const questions = [
    'What small moment with me would you relive?',
    'What is one little thing that made you smile today?',
    'What would our perfect slow Sunday look like?',
    'Which adventure should we put on our list?',
    'What is something you appreciate about us?',
    'Which song reminds you of a memory together?',
    'How can I make your tomorrow a little easier?',
  ];
  String get todayQuestion {
    revision.value;
    return questionForDay(questionKey);
  }

  String questionForDay(String day) =>
      questions[DateTime.parse('${day}T00:00:00Z')
              .difference(DateTime.utc(2026))
              .inDays %
          questions.length];

  String get saveMessage => isCloud
      ? paired
            ? 'Shared in your space. Your partner can see it when connected.'
            : 'Saved in your cloud space. Invite your person to share it.'
      : 'Saved on this phone.';
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    reducedMotion.value =
        repository.storage.preferences.getBool('reduce_motion') ?? false;
    haptics.value = repository.storage.preferences.getBool('haptics') ?? true;
    AppMotion.reduced = reducedMotion.value;
    AppMotion.haptics = haptics.value;
    _day = questionKey;
    _reload();
    _subscription = repository.changes.listen((_) => _reload());
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkDay());
  }

  void _checkDay() {
    if (_day == questionKey) return;
    _day = questionKey;
    if (isCloud) {
      repository.refresh();
    } else {
      _reload();
    }
  }

  void refreshQuestionDay() => _checkDay();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkDay();
  }

  void _reload() {
    final s = repository.state;
    name.value = s['name'] ?? '';
    partner.value = s['partner'] ?? '';
    relationship.value = s['relationship'] ?? 'Couple';
    onboarded.value = s['onboarded'] ?? false;
    anniversary.value =
        DateTime.tryParse(s['anniversary'] ?? '') ?? DateTime.now();
    answer.value = (s['answers'] as Map?)?[questionKey] ?? '';
    partnerAnswer.value = repository.isCloud
        ? activePartnerAnswer(s, repository.uid!, questionKey)
        : s['partnerAnswer'] ?? '';
    moments.assignAll(repository.moments);
    countdowns.assignAll(repository.countdowns);
    cloudError.value = repository.error;
    cached.value = repository.cached;
    loading.value = repository.loading;
    revision.value++;
    if (_lastUid != repository.uid) {
      inviteCode.value = '';
      inviteExpires.value = null;
      _lastUid = repository.uid;
    }
    final latest = moments.firstOrNull;
    final marker =
        '${repository.uid}:${repository.spaceId}:$displayName:$displayPartner:${anniversary.value}:${latest?.id}';
    if (_widgetMoment != marker) {
      _widgetMoment = marker;
      // Cloud widgets deliberately avoid exposing private notes on a shared screen.
      bridge
          .update(
            '$displayName & $displayPartner',
            isCloud
                ? latest == null
                      ? 'A little closer, every day.'
                      : 'A new moment is waiting in Pairlight.'
                : latest?.content ?? 'A little closer, every day.',
            spaceId: repository.spaceId,
            anniversary: anniversary.value,
          )
          .catchError((_) => false);
    }
  }

  Future<bool> perform(Future<void> Function() action) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await action();
      _reload();
      unawaited(AppMotion.commit());
      return true;
    } catch (error) {
      Get.snackbar(
        'Could not finish',
        backendMessage(error),
        backgroundColor: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> setup(String n, String p, String relation, DateTime date) =>
      perform(() async {
        await repository.update({
          'name': n.trim(),
          'partner': p.trim(),
          'relationship': relation,
          'anniversary': date.toIso8601String(),
          'onboarded': true,
        });
        if (isCloud) {
          // Immediately reload after callable completion, rather than assuming snapshot delivery order.
          await repository.refresh();
        }
      });
  Future<bool> send(
    String kind,
    String content, {
    List<List<double>>? drawing,
  }) => perform(() async {
    await repository.addMoment(
      Moment(
        id: CoupleRepository.newId(),
        kind: kind,
        content: content,
        createdAt: DateTime.now(),
        drawing: drawing,
        senderId: repository.uid,
        senderName: displayName,
      ),
    );
  });
  Future<bool> saveAnswer(String text, {String? questionDay}) => perform(
    () => repository.saveAnswer(text.trim(), questionDay: questionDay),
  );
  Future<bool> addCountdown(String title, DateTime date) =>
      perform(() => repository.addCountdown(title.trim(), date));
  Future<void> loadMore() => perform(repository.loadMore).then((_) {});
  Future<void> removeItem(String collection, String id) =>
      perform(() => repository.remove(collection, id)).then((_) {});
  Future<void> sharePhoto() async {
    if (!isCloud || !hasSpace) {
      Get.toNamed('/pairing');
      return;
    }
    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (photo == null) return;
      await perform(() async {
        final id = CoupleRepository.newId();
        final path =
            'spaces/${repository.spaceId}/photos/${repository.uid}/$id';
        final bytes = await photo.readAsBytes();
        final mime =
            photo.mimeType ??
            (photo.name.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg');
        await repository.cloud!.upload(path, bytes, mime);
        try {
          await repository.addMoment(
            Moment(
              id: id,
              kind: 'photo',
              content: 'A little memory for you',
              createdAt: DateTime.now(),
              photoPath: path,
            ),
          );
        } catch (_) {
          // Cleanup is idempotent and keeps a photo if its moment actually committed.
          try {
            await repository.cloud!.call('discardPhoto', {'path': path});
          } catch (_) {
            /* Retain original error for the user. */
          }
          rethrow;
        }
        Get.snackbar(
          'Photo shared',
          saveMessage,
          snackPosition: SnackPosition.BOTTOM,
        );
      });
    } catch (error) {
      Get.snackbar('Could not open photos', backendMessage(error));
    }
  }

  Future<void> createInvite() => perform(() async {
    final result = await repository.cloud!.call('createInvite');
    inviteCode.value = result['code'];
    inviteExpires.value = DateTime.parse(result['expiresAt']);
  }).then((_) {});
  Future<bool> acceptInvite(String code) => perform(() async {
    await repository.cloud!.call('acceptInvite', {'code': code.trim()});
    await repository.refresh();
  });
  Future<void> disconnect() => perform(() async {
    await repository.cloud!.call('disconnectPartner');
    inviteCode.value = '';
    await repository.refresh();
  }).then((_) {});
  Future<void> refreshVerification() => perform(() async {
    await repository.cloud!.auth.currentUser!.reload();
    await repository.cloud!.auth.currentUser!.getIdToken(true);
    revision.value++;
  }).then((_) {});
  Future<void> sendVerification() =>
      perform(() => repository.cloud!.auth.currentUser!.sendEmailVerification())
          .then((ok) {
            if (ok) {
              Get.snackbar(
                'Email sent',
                'Open the verification link, then tap “I have verified”.',
              );
            }
          });
  Future<void> exportData() => perform(() async {
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ')
            .convert(await repository.export()),
      ),
    );
    Get.snackbar(
      'Export copied',
      'Paste your export into a private file.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }).then((_) {});
  Future<void> signOut() => perform(() async {
    try {
      await NotificationService.instance?.unregister(invalidateToken: true);
    } catch (_) {
      // Signing out stays available when the notification service is offline.
    }
    await repository.cloud!.auth.signOut();
    await repository.refresh();
    Get.offAllNamed('/welcome');
  }).then((_) {});
  Future<void> deleteAccount(String password) => perform(() async {
    final user = repository.cloud!.auth.currentUser!;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    await repository.cloud!.call('deleteAccount');
    await repository.cloud!.auth.signOut();
    await repository.refresh();
    Get.offAllNamed('/welcome');
  }).then((_) {});
  Future<void> setMotion(bool value) async {
    await repository.storage.preferences.setBool('reduce_motion', value);
    AppMotion.reduced = value;
    reducedMotion.value = value;
  }

  Future<void> setHaptics(bool value) async {
    await repository.storage.preferences.setBool('haptics', value);
    AppMotion.haptics = value;
    haptics.value = value;
  }

  Future<void> deleteData() async {
    if (await perform(repository.clear)) {
      tab.value = 0;
      Get.offAllNamed('/welcome');
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}

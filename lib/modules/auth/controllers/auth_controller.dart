import 'package:get/get.dart';

import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/firebase_couple_service.dart';

class AuthController extends GetxController {
  AuthController(this.repository);
  final CoupleRepository repository;
  final busy = false.obs;
  final error = RxnString();
  final message = RxnString();
  Future<void> submit(String email, String password, bool register) async {
    if (busy.value) return;
    busy.value = true;
    error.value = null;
    message.value = null;
    try {
      final auth = repository.cloud!.auth;
      if (register) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        try {
          await credential.user!.sendEmailVerification();
        } catch (_) {
          /* Pairing provides a resend action. */
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }
      await repository.refresh();
      Get.offAllNamed('/home');
    } catch (e) {
      error.value = backendMessage(e);
    } finally {
      busy.value = false;
    }
  }

  Future<void> signInAnonymously() async {
    if (busy.value) return;
    busy.value = true;
    error.value = null;
    message.value = null;
    try {
      final auth = repository.cloud!.auth;
      await auth.signInAnonymously();
      await repository.refresh();
      Get.offAllNamed('/home');
    } catch (e) {
      error.value = backendMessage(e);
    } finally {
      busy.value = false;
    }
  }

  Future<void> reset(String email) async {
    if (busy.value) return;
    busy.value = true;
    error.value = null;
    message.value = null;
    try {
      await repository.cloud!.auth.sendPasswordResetEmail(email: email.trim());
      message.value =
          'If this email has an account, a reset link is on its way.';
    } catch (e) {
      error.value = backendMessage(e);
    } finally {
      busy.value = false;
    }
  }
}

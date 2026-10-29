import 'package:firebase_core/firebase_core.dart';

/// Public client configuration is supplied with --dart-define-from-file.
/// Never put service-account credentials in a Flutter application.
abstract final class FirebaseConfig {
  static const debugToken = String.fromEnvironment(
    'FIREBASE_APP_CHECK_DEBUG_TOKEN',
    defaultValue: 'a5a5eaff-f86f-4664-9cb4-12aee3c2177f',
  );
  static const emulator = bool.fromEnvironment('FIREBASE_EMULATORS');
  static const host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'pairlight-sonu-20261009',
  );
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyDHQ9izsXgQ5GRKZyCkKYpgTXXwQdm68Xs',
  );
  static const appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:314642859962:android:d0dde58b30e74271457f83',
  );
  static const senderId = String.fromEnvironment(
    'FIREBASE_SENDER_ID',
    defaultValue: '314642859962',
  );
  static const bucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'pairlight-sonu-20261009.firebasestorage.app',
  );
  static bool get configured =>
      emulator ||
      (apiKey.isNotEmpty && appId.isNotEmpty && senderId.isNotEmpty);
  static FirebaseOptions get options => FirebaseOptions(
    apiKey: emulator ? 'demo-api-key' : apiKey,
    appId: emulator ? '1:123456789:android:123456789abcdef' : appId,
    messagingSenderId: emulator ? '123456789' : senderId,
    projectId: projectId,
    storageBucket: bucket.isEmpty
        ? emulator
              ? '$projectId.appspot.com'
              : '$projectId.firebasestorage.app'
        : bucket,
    iosBundleId: 'com.pairlight.pairlight',
  );
}

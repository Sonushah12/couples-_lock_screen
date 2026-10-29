# Firebase setup and verification

Project: `pairlight-sonu-20261009`. Android package and iOS bundle ID: `com.pairlight.pairlight`. Firestore and Functions region: `asia-south1` (Mumbai).

## Services

- Authentication: email/password accounts, password reset, email verification, recent-login deletion.
- Firestore: private profiles and spaces containing at most two members. Each moment/countdown has its own document. Concurrent sends do not overwrite shared arrays.
- Callable Functions: validated writes, atomic invitations, throttling, exports, device registration, disconnection and account deletion.
- Storage: authenticated image reads, maximum 5 MB per photo, membership and ownership rules. No permanent public download URLs in moment documents.
- FCM: generic partner notifications. Backend acceptance is not proof of notification delivery or a read receipt.
- App Check: enforced on production callable functions. Debug builds use a development token; release builds use Play Integrity/App Attest.

## Finish project provisioning

1. Email/Password Authentication and email privacy are already enabled in this project. When recreating the project, initialize Auth in the console, then run `node scripts/configure-firebase.cjs PROJECT_ID`. The installed CLI cannot deploy the `auth` configuration; it is included for newer CLI versions.
2. Upgrade this project to Blaze and attach your billing account to deploy Functions and use Storage. This is controlled by the project owner. Free quotas do not guarantee a zero bill. Set budget alerts in Google Cloud.
3. Storage → Get started → create the default bucket. Expected name: `pairlight-sonu-20261009.firebasestorage.app`; update the public configuration if the actual name differs. Firebase's eligible no-cost Storage regions are `us-central1`, `us-east1` and `us-west1`. Choose one for that allowance, or choose Mumbai for closer regional access with different pricing. Firestore's Mumbai location does not force the Storage location. Blaze is required either way; usage above allowances can be billed. See the [official Storage changes and location guidance](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
4. App Check → register Android with the release SHA-256/Play Integrity provider. Register debug tokens for development devices only. Never use a debug token in a release build.
5. Firestore rules and indexes are already deployed. After the bucket exists, deploy: `firebase deploy --project pairlight-sonu-20261009 --only "firestore,storage,functions"`. Storage rules read Firestore membership; grant the Storage rules service account its required Firestore permission when the console/CLI requests it.
6. iOS: register the app, supply its own app ID/config, enable Push Notifications and remote notification background capabilities in Xcode, and upload an APNs key to Firebase Cloud Messaging. Building iOS and testing APNs requires macOS and an Apple developer account.

## Run Android

Public configuration is saved locally in `firebase-config.android.json` and `android/app/google-services.json`. These are environment-specific client settings, not administrator credentials.

```powershell
flutter run -d 1baa8028 --dart-define-from-file=firebase-config.android.debug.json
```

Without cloud defines the app starts in local mode. Existing local demo data stays separate; signing in does not silently upload it. Cloud writes require an internet connection. Cached reads are labelled and shared cached data stays hidden until the server confirms this account's membership. Cloud data is not saved to unencrypted SharedPreferences. Daily questions use UTC dates so both people receive the same question across time zones.

For an Android device connected over USB, start the emulators in a separate terminal, reverse their ports, then run against the isolated named emulator app. Do not supply the production configuration file in this mode:

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:5001 tcp:5001
adb reverse tcp:9199 tcp:9199
flutter run --dart-define=FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Android virtual devices can use the default host `10.0.2.2`. HTTP access for emulators is enabled only in the debug manifest. Real notifications and production App Check are skipped in emulator mode.

## Tests

```powershell
npm.cmd --prefix functions ci
npm.cmd --prefix functions test
firebase emulators:exec --project demo-pairlight --only "auth,firestore,functions,storage" "npm.cmd --prefix functions run test:integration"
flutter analyze
flutter test
```

For a low-memory Windows workstation, the same callable handlers can run inside the test process, avoiding separate emulator workers per function:

```powershell
$env:JAVA_TOOL_OPTIONS='-Xmx160m -Xms16m -XX:+UseSerialGC -XX:MaxMetaspaceSize=96m -XX:ReservedCodeCacheSize=32m -Xss256k'
$env:FUNCTIONS_EMULATOR='true'
$env:PAIRLIGHT_DIRECT_FUNCTION_TESTS='true'
firebase emulators:exec --project demo-pairlight --only "auth,firestore,storage" "npm.cmd --prefix functions run test:integration"
```

This verifies server handlers, transactions and rules. The full emulator command also verifies HTTP callable transport; both modes have passed. Production App Check and FCM still require deployment/device testing. The emulators also check authenticated photo upload, partner reads, intruder/forged uploads, access after disconnect, and simultaneous invitation acceptance.

Development App Check can be provisioned with `node scripts/register-debug-app-check.cjs`; this saves an ignored `firebase-config.android.debug.json`. Use that file for debug runs. The debug token is never logged or committed. Release builds must use production attestation.

Check the project's provisioning status with `node scripts/firebase-status.cjs pairlight-sonu-20261009`. This checks Auth, billing and the default Storage bucket without logging credentials or changing the project.

The integration suite uses a demo project, two partners and an intruder. It checks authentication, atomic pairing, invitation retries, concurrent/idempotent sends, cross-user isolation, answer reveal, countdowns, device settings, exports, disconnection and account deletion.

## Behavior and limits

- Set up a profile, verify email, then create or join an invitation. Only the latest code works; it expires in 24 hours.
- Notifications start off. Enable Partner notifications in Settings to request Android/iOS permission and register this device. Denied system permission leaves alerts off.
- Answers use separate documents. Your person can read yours only after submitting theirs. Exports follow the same reveal condition.
- Timeline reads use pages of 50 moments. Selected pictures are compressed and loaded using authenticated SDK reads.
- Disconnect immediately revokes access. The remaining person retains their space; an empty space is deleted. Deletion also erases the account's contributions in former spaces, files, device tokens and owned invitations.
- Android home screen widgets use generic cloud previews. Android lock screen placement depends on the OS/launcher. An iOS WidgetKit extension is not included.
- The native Android day counter recalculates from the saved anniversary on periodic widget refresh, including while the app is closed. Android schedules these updates approximately every 30 minutes; battery restrictions may delay them.
- Force-stopping an app may prevent push delivery or widget refresh until it is reopened. Backend data remains available on the next authenticated sync.
- Push delivery, billing quotas, signing, App Check and APNs need real deployment/device checks; emulators cannot certify them.

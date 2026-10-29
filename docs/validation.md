# Validation — 9 October 2026

| Check | Result |
|---|---|
| Flutter static analysis | No issues found |
| Flutter tests | 10 passed, including shared-profile, current-partner, incoming-moment pagination and overnight-question regressions |
| Server input validation tests | 3 passed |
| Firebase emulator integration | 2 scenarios passed through both direct handlers and real HTTP callable endpoints |
| Firebase-configured Android debug APK | Built and installed on Realme RMX1911, Android 10 |
| Production Firestore rules and indexes | Compiled and deployed to `pairlight-sonu-20261009` |
| Physical Android flow/widget test | Rerun stopped pending manual device unlock; the current app compiles and installs |

Flutter tests cover profile/moment persistence, deletion, preservation of the shared anniversary during personal profile updates, current-partner answer attribution, calendar countdown boundaries, layouts at 375 × 812, 812 × 375 and 1024 × 768 with 1.5× text scaling, and feature screens at 2× text scaling with reduced motion. The emulator uses a separate named Firebase app so native production configuration cannot collide with it. Shared cached snapshots are hidden until server membership is confirmed; live account-switch behavior still requires device verification.

The Firebase scenarios exercise authenticated server handlers, transactional pairing, rotated/expired invitations, concurrent joins, concurrent/idempotent sends, intruder isolation, daily answer reveal, photo uploads and access rules, countdowns, device preferences, exports, disconnection and account deletion. Expected permission-denied messages come from assertions that reject unauthorized requests.

The integration suite passed both inside the test process and through the Functions emulator's HTTP endpoints. The HTTP suite needed a longer test timeout for separate cold workers on this Windows host; its final run passed in 117 seconds, including notification opt-in preferences. The host emulator uses Node 24; deployment targets Node 22. Production App Check, real email delivery and FCM/APNs delivery still need live verification.

Production status was checked using the signed-in CLI account: Email/Password Auth and email privacy are enabled, billing is disabled, and the default Storage bucket does not exist. Cloud Functions and Storage rules have not been deployed. The owner must enable Blaze/Storage before live partner sharing can be tested. See [Firebase setup](firebase-setup.md). Auth verification: [screenshot](firebase-auth-enabled.jpg).

Android packaging completed with the project-local JVM/worker limits. Firebase plugins currently emit a warning about future Flutter built-in Kotlin compatibility; this does not prevent the current build.

Physical device: Realme RMX1911, Android 10, ADB serial `1baa8028`, 720 × 1600 pixels. Installing with `adb install -r` preserves existing local demo data. The device test adds clearly labelled test content and does not delete existing data.

Visual QA awaits manual device unlock. Automatic approval review rejected the lock-screen dismissal command as a device security boundary. No lock-screen bypass was performed.

Widget pinning requires launcher confirmation; lock screen placement depends on Android/launcher support. The day counter uses native local calendar dates and Android's periodic widget refresh. Force-stop can suspend updates until the app is reopened. iOS builds, APNs and a WidgetKit extension remain unverified or unavailable on this Windows host.

The initial local-only build passed its physical-device flow test on 8 October. Those earlier results do not certify live Firebase behavior.

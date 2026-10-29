# Pairlight

A Flutter couples app using Firebase, GetX, feature modules, repository isolation, reusable widgets, and a separate local demo.

## Run

```powershell
flutter pub get
flutter run -d 1baa8028
```

## Architecture

- `lib/data/models`: serializable moments and calendar countdowns.
- `lib/data/services`: Firebase configuration, callable functions, authenticated photo access, notifications and local storage.
- `lib/data/repositories`: local persistence or authenticated realtime cloud state with paginated moments.
- `functions/src`: authenticated, validated server operations and notification/file cleanup triggers.
- `lib/modules/*/controllers`: GetX presentation state and commands, constructor-injected repository.
- `lib/modules/*/views`: screens and UI interactions.
- `lib/core`: semantic theme tokens, reusable cards, avatars, page layouts, illustrated scene.
- `lib/app`: named routes and GetX bindings; doodle controller lives only for its route.
- `lib/platform`: method channel for native Android widget updates and launcher pinning.
- `android/.../PairlightWidget.kt`: RemoteViews home screen widget.

## Implemented

Profile onboarding (couples, friends, family), local demo, anniversary counter, illustrated shared scene, quick moments, notes, normalized doodle canvas with colors/undo/clear, persistent history, daily dated answers, calendar countdowns, widget gallery/setup, native widget, privacy information and confirmed local data deletion. Layouts are constrained and scrollable, use safe areas and native labelled controls, and avoid unnecessary animation.

## Firebase backend

Firebase integration includes email/password authentication and recovery, verified-email pairing with expiring invitations, realtime moments and countdowns, private daily answer reveal, authenticated photo storage, generic partner notifications, data export, disconnection, and account deletion. Callable server functions validate writes and enforce membership; Firestore and Storage rules restrict reads to the space's members. Shared lists use separate documents so concurrent sends do not overwrite one another.

Project: `pairlight-sonu-20261009`. Email/Password Auth is enabled and Firestore rules are deployed. See [Firebase setup](docs/firebase-setup.md) for configuration, emulator testing, and deployment prerequisites. Run the connected Android build with `flutter run -d 1baa8028 --dart-define-from-file=firebase-config.android.debug.json`. Live partner sharing still requires Blaze billing, a Storage bucket, Functions deployment and release App Check configuration.

Local mode remains available without Firebase defines. It keeps existing demo data separate from cloud accounts. Cloud saves require a connection and never claim delivery when a callable fails. Shared content is protected by access rules; this is not end-to-end encryption. Android home screen widgets use generic previews for cloud content. Lock screen placement depends on device/launcher support. iOS FCM requires APNs configuration and macOS verification; this repository does not contain an iOS WidgetKit extension. Subscriptions and location sharing are not implemented.

## UI and motion

All screens share responsive spacing, readable typography, reusable cards, clear press feedback and one-shot page reveals. Navigation and save controls show immediate state changes, and settings provide reduced motion and haptics controls. Motion respects the system accessibility setting. The moments timeline uses lazy rendering and pagination. See [motion specification](docs/motion-spec.md) and the downloaded [Flutter motion skill](docs/vendor-skills/motion-and-haptics/SKILL.md).

## Validation

```powershell
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d 1baa8028
```

The device test creates clearly labelled test moments and a countdown in the local space. It does not delete existing device data.

## Design research

Applied the installed UI UX Pro Max Flutter skill after reviewing its upstream project and Flutter's official accessibility and architecture guidance. The design combines warm cream/peach surfaces, plum text, clear touch targets, a restrained night-sky illustration, and responsive layouts. Search output is in `design-system/pairlight/MASTER.md`; app-specific direction is recorded in `docs/design-decisions.md`.

Sources:
- https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- https://docs.flutter.dev/app-architecture/recommendations
- https://docs.flutter.dev/ui/accessibility
- https://docs.flutter.dev/ui/adaptive-responsive/best-practices

Android build note: Kotlin incremental compilation is disabled to avoid cross-drive C:/D: cache errors; Gradle workers, heap and JVM optimization are limited for this workstation. Data export copies JSON to the clipboard.

Server validation: `npm.cmd --prefix functions test`. Emulator integration: `firebase emulators:exec --project demo-pairlight --only "auth,firestore,functions,storage" "npm.cmd --prefix functions run test:integration"`. A lower-memory test path is documented in the setup guide. Notifications and APNs require real device checks after deployment.


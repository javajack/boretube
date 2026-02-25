# Boretube Mobile — Flutter App

## Project Overview
- **App name**: Boretube
- **Package**: com.rakesh.boretube_mobile
- **Purpose**: Parental control for Sony Bravia Google TV via CastV2 + DIAL protocols
- **Flutter SDK**: 3.27.4 (stable), Dart 3.6.2
- **State management**: Riverpod
- **Navigation**: GoRouter
- **Target platform**: Android (primary)

## Development Environment
- **Flutter**: `~/development/flutter/bin/flutter`
- **JDK**: `~/development/jdk-17.0.2` (JAVA_HOME)
- **Android SDK**: `~/Android/Sdk` (ANDROID_HOME)

### Quick start
```bash
bash scripts/run-android.sh           # debug mode
bash scripts/run-android.sh --release # release APK
```

## Architecture
Simple flat structure (not feature-first — this is a small, single-purpose app):

```
lib/
  main.dart              # Entry point
  app.dart               # MaterialApp.router + GoRouter + theme
  protocols/             # Low-level TV protocol clients
    castv2_client.dart   # CastV2 TLS + protobuf (port 8009)
    dial_client.dart     # DIAL HTTP (port 8008)
  proto/                 # Generated protobuf classes
  models/                # Data classes
  services/              # High-level TV operations
  providers/             # Riverpod providers
  screens/               # Full-page widgets
  widgets/               # Reusable widgets
```

## Protocols
- **CastV2** (port 8009): TLS + protobuf framing + JSON payloads. Controls volume, stops apps, gets status.
- **DIAL** (port 8008): HTTP DELETE to kill specific apps (YouTube, Netflix).

## Code Style
- `flutter analyze` must pass with zero issues
- Use `const` constructors where possible
- Prefer `final` over `var`
- Use trailing commas for widget trees
- Use `super.key` in constructors
- Max line length: 80 characters

## Build Commands
```bash
flutter analyze
flutter build apk --debug
flutter build apk --release
```

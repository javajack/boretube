import 'dart:convert';

import 'package:flutter/services.dart';

import '../adb/adb_connection.dart';

/// A package in a profile list, with a human note.
class ProfilePackage {
  final String pkg;
  final String comment;
  const ProfilePackage(this.pkg, [this.comment = '']);

  factory ProfilePackage.fromJson(Object? j) {
    if (j is String) return ProfilePackage(j);
    final m = j! as Map;
    return ProfilePackage(m['pkg'] as String, m['comment'] as String? ?? '');
  }
}

class StockYouTubeSpec {
  final String pkg;
  final List<String> companions;
  const StockYouTubeSpec(this.pkg, this.companions);
}

class LauncherSpec {
  final String pkg;
  final String homeActivity;
  final String a11yService;
  const LauncherSpec(this.pkg, this.homeActivity, this.a11yService);
}

/// The `getprop` values used to pick a profile.
class DeviceProps {
  final String manufacturer;
  final String device;
  final String buildId;
  const DeviceProps({
    required this.manufacturer,
    required this.device,
    required this.buildId,
  });

  static const command = 'getprop ro.product.manufacturer; '
      'getprop ro.product.device; getprop ro.build.id';

  /// Parses the three lines printed by [command].
  factory DeviceProps.parse(String out) {
    final l = out.split('\n').map((s) => s.trim()).toList();
    String at(int i) => i < l.length ? l[i] : '';
    return DeviceProps(manufacturer: at(0), device: at(1), buildId: at(2));
  }

  static Future<DeviceProps> read(AdbShell adb) async =>
      DeviceProps.parse((await adb.shell(command)).stdout);

  @override
  String toString() => '$manufacturer/$device/$buildId';
}

/// Per-device-family data: what to clean up, what never to touch, known
/// good versions and quirks. Loaded from `assets/profiles/*.json`.
class DeviceProfile {
  final String id;
  final String name;
  final bool readOnly;
  final String? matchManufacturer;
  final List<String> matchDevices;
  final List<String> matchBuilds;
  final List<ProfilePackage> cleanup;
  final List<ProfilePackage> extras;
  final Set<String> neverTouch;
  final Map<String, String> knownGood;
  final StockYouTubeSpec? stockYouTube;
  final LauncherSpec? launcher;
  final List<String> quirks;

  const DeviceProfile({
    required this.id,
    this.name = '',
    this.readOnly = false,
    this.matchManufacturer,
    this.matchDevices = const [],
    this.matchBuilds = const [],
    this.cleanup = const [],
    this.extras = const [],
    this.neverTouch = const {},
    this.knownGood = const {},
    this.stockYouTube,
    this.launcher,
    this.quirks = const [],
  });

  bool get isGeneric => matchManufacturer == null && matchDevices.isEmpty;

  bool hasQuirk(String name) =>
      quirks.any((q) => q == name || q.startsWith('$name:'));

  /// Manufacturer (case-insensitive) and device must match. Builds are
  /// checked separately by [buildTested].
  bool matches(DeviceProps p) {
    if (isGeneric) return true;
    final m = matchManufacturer;
    if (m != null && m.toLowerCase() != p.manufacturer.toLowerCase()) {
      return false;
    }
    return matchDevices.isEmpty || matchDevices.contains(p.device);
  }

  /// Whether the build was verified with this profile.
  bool buildTested(DeviceProps p) =>
      matchBuilds.isEmpty || matchBuilds.contains(p.buildId);

  factory DeviceProfile.fromJson(Map<String, dynamic> j) {
    final match = (j['match'] as Map?) ?? const {};
    final yt = j['stockYouTube'] as Map?;
    final la = j['launcher'] as Map?;
    List<String> strings(Object? v) =>
        [for (final s in (v as List?) ?? const []) s as String];
    return DeviceProfile(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      readOnly: j['readOnly'] as bool? ?? false,
      matchManufacturer: match['manufacturer'] as String?,
      matchDevices: strings(match['device']),
      matchBuilds: strings(match['build']),
      cleanup: [
        for (final p in (j['cleanup'] as List?) ?? const [])
          ProfilePackage.fromJson(p),
      ],
      extras: [
        for (final p in (j['extras'] as List?) ?? const [])
          ProfilePackage.fromJson(p),
      ],
      neverTouch: strings(j['neverTouch']).toSet(),
      knownGood: {
        for (final e in ((j['knownGood'] as Map?) ?? const {}).entries)
          e.key as String: e.value as String,
      },
      stockYouTube: yt == null
          ? null
          : StockYouTubeSpec(
              yt['pkg'] as String,
              strings(yt['companions']),
            ),
      launcher: la == null
          ? null
          : LauncherSpec(
              la['pkg'] as String,
              la['homeActivity'] as String,
              la['a11yService'] as String,
            ),
      quirks: strings(j['quirks']),
    );
  }

  factory DeviceProfile.fromJsonString(String s) =>
      DeviceProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Result of picking a profile for a TV.
class ProfileMatch {
  final DeviceProfile profile;
  final DeviceProps props;

  /// False when the device matched but its firmware build is untested.
  final bool buildTested;

  const ProfileMatch(this.profile, this.props, {required this.buildTested});
}

/// Loads the bundled profiles and picks one for a TV.
class ProfileRepository {
  static const assetPaths = [
    'assets/profiles/sony-bravia-vu3.json',
    'assets/profiles/generic.json',
  ];

  final List<DeviceProfile> profiles;
  const ProfileRepository(this.profiles);

  static Future<ProfileRepository> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return ProfileRepository([
      for (final p in assetPaths)
        DeviceProfile.fromJsonString(await b.loadString(p)),
    ]);
  }

  DeviceProfile get generic => profiles.firstWhere(
        (p) => p.isGeneric,
        orElse: () => const DeviceProfile(id: 'generic', readOnly: true),
      );

  /// First specific profile matching [props], else the generic one.
  ProfileMatch match(DeviceProps props) {
    for (final p in profiles) {
      if (!p.isGeneric && p.matches(props)) {
        return ProfileMatch(p, props, buildTested: p.buildTested(props));
      }
    }
    return ProfileMatch(generic, props, buildTested: false);
  }
}

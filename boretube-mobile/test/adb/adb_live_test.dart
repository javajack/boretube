// Opt-in, read-only test against a real TV:
//   BORETUBE_TV=192.168.1.3:5555 BORETUBE_ADBKEY=~/.android/adbkey \
//     flutter test test/adb/adb_live_test.dart
import 'dart:io';

import 'package:boretube_mobile/adb/adb_client.dart';
import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tv = Platform.environment['BORETUBE_TV'];
  final keyPath = Platform.environment['BORETUBE_ADBKEY'];

  test('connects, authenticates and runs read-only shell commands', () async {
    final parts = tv!.split(':');
    final client = AdbClient(
      host: parts[0],
      port: parts.length > 1 ? int.parse(parts[1]) : 5555,
      key: AdbKey.fromPem(File(keyPath!).readAsStringSync()),
    );
    await client.connect();
    expect(client.deviceBanner, startsWith('device::'));

    final model = await client.shell('getprop ro.product.model');
    expect(model.ok, isTrue);
    expect(model.stdout.trim(), isNotEmpty);

    final pkgs = await client.shell('pm list packages -d');
    expect(pkgs.ok, isTrue);
    expect(pkgs.stdout, contains('package:'));

    final fail = await client.shell('ls /nonexistent-boretube');
    expect(fail.ok, isFalse);

    // ignore: avoid_print
    print('banner=${client.deviceBanner}\nmodel=${model.stdout.trim()}\n'
        'disabled=${'package:'.allMatches(pkgs.stdout).length}');
    await client.close();
  },
      skip: tv == null || keyPath == null
          ? 'set BORETUBE_TV and '
              'BORETUBE_ADBKEY'
          : false);
}

import 'package:flutter_test/flutter_test.dart';

import 'package:boretube_mobile/models/whitelist_entry.dart';

void main() {
  group('WhitelistEntry', () {
    test('round-trip serialization', () {
      const original = WhitelistEntry(
        appId: 'CC1AD845',
        friendlyName: 'YouTube',
      );

      final stored = original.toStorageString();
      final restored =
          WhitelistEntry.fromStorageString(stored);

      expect(restored.appId, original.appId);
      expect(
        restored.friendlyName,
        original.friendlyName,
      );
    });

    test('equality based on appId only', () {
      const a = WhitelistEntry(
        appId: 'ABC',
        friendlyName: 'App One',
      );
      const b = WhitelistEntry(
        appId: 'ABC',
        friendlyName: 'Different Name',
      );
      const c = WhitelistEntry(
        appId: 'XYZ',
        friendlyName: 'App One',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode consistent with equality', () {
      const a = WhitelistEntry(
        appId: 'ABC',
        friendlyName: 'One',
      );
      const b = WhitelistEntry(
        appId: 'ABC',
        friendlyName: 'Two',
      );

      expect(a.hashCode, b.hashCode);
    });

    test('backdrop constant', () {
      expect(
        WhitelistEntry.backdrop.appId,
        'E8C28D3C',
      );
      expect(
        WhitelistEntry.backdrop.friendlyName,
        'Backdrop (Home Screen)',
      );
    });

    test(
      'fromStorageString missing friendly name '
      'defaults to Unknown',
      () {
        final entry = WhitelistEntry.fromStorageString(
          'APPID_ONLY',
        );
        expect(entry.appId, 'APPID_ONLY');
        expect(entry.friendlyName, 'Unknown');
      },
    );

    test(
      'fromStorageString preserves pipe in name',
      () {
        final entry = WhitelistEntry.fromStorageString(
          'ABC|Name|With|Pipes',
        );
        expect(entry.appId, 'ABC');
        expect(entry.friendlyName, 'Name|With|Pipes');
      },
    );

    test('works in Set and List.contains', () {
      const entry = WhitelistEntry(
        appId: 'TEST',
        friendlyName: 'Test App',
      );
      const same = WhitelistEntry(
        appId: 'TEST',
        friendlyName: 'Other',
      );

      final list = [entry];
      expect(list.any((e) => e.appId == same.appId), true);

      final set = {entry};
      expect(set.contains(same), true);
    });
  });
}

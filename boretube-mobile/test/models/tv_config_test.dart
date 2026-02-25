import 'package:flutter_test/flutter_test.dart';

import 'package:boretube_mobile/models/tv_config.dart';

void main() {
  group('TvConfig', () {
    test('defaultConfig has expected values', () {
      expect(TvConfig.defaultConfig.ip, '192.168.1.3');
      expect(
        TvConfig.defaultConfig.name,
        'Sony BRAVIA',
      );
      expect(TvConfig.defaultConfig.dialPort, 8008);
      expect(TvConfig.defaultConfig.castPort, 8009);
    });

    test('JSON round-trip preserves all fields', () {
      const original = TvConfig(
        ip: '10.0.0.5',
        name: 'Living Room TV',
        dialPort: 9999,
        castPort: 1234,
      );

      final json = original.toJson();
      final restored = TvConfig.fromJson(json);

      expect(restored.ip, original.ip);
      expect(restored.name, original.name);
      expect(restored.dialPort, original.dialPort);
      expect(restored.castPort, original.castPort);
    });

    test('fromJson defaults when keys missing', () {
      final config = TvConfig.fromJson({});

      expect(config.ip, '192.168.1.3');
      expect(config.name, '');
      expect(config.dialPort, 8008);
      expect(config.castPort, 8009);
    });

    test('copyWith replaces only specified fields', () {
      const original = TvConfig(
        ip: '1.2.3.4',
        name: 'TV',
        dialPort: 8008,
        castPort: 8009,
      );

      final updated = original.copyWith(ip: '5.6.7.8');

      expect(updated.ip, '5.6.7.8');
      expect(updated.name, 'TV');
      expect(updated.dialPort, 8008);
      expect(updated.castPort, 8009);
    });

    test('copyWith with all fields', () {
      const original = TvConfig.defaultConfig;
      final updated = original.copyWith(
        ip: '10.10.10.10',
        name: 'Bedroom',
        dialPort: 1111,
        castPort: 2222,
      );

      expect(updated.ip, '10.10.10.10');
      expect(updated.name, 'Bedroom');
      expect(updated.dialPort, 1111);
      expect(updated.castPort, 2222);
    });
  });
}

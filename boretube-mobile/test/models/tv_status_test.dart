import 'package:flutter_test/flutter_test.dart';

import 'package:boretube_mobile/models/tv_status.dart';

void main() {
  group('TvStatus.fromJson', () {
    test('parses complete response', () {
      final status = TvStatus.fromJson({
        'volume': 42,
        'muted': true,
        'app_id': 'CC1AD845',
        'app_name': 'YouTube',
        'idle': false,
      });

      expect(status.volume, 42);
      expect(status.muted, true);
      expect(status.appId, 'CC1AD845');
      expect(status.appName, 'YouTube');
      expect(status.isIdle, false);
    });

    test('defaults when all keys missing', () {
      final status = TvStatus.fromJson({});

      expect(status.volume, 0);
      expect(status.muted, false);
      expect(status.appId, '');
      expect(status.appName, '');
      expect(status.isIdle, true);
    });

    test('defaults when values are null', () {
      final status = TvStatus.fromJson({
        'volume': null,
        'muted': null,
        'app_id': null,
        'app_name': null,
        'idle': null,
      });

      expect(status.volume, 0);
      expect(status.muted, false);
      expect(status.appId, '');
      expect(status.appName, '');
      expect(status.isIdle, true);
    });

    test('coerces double volume to int', () {
      final status = TvStatus.fromJson({
        'volume': 15.7,
      });
      expect(status.volume, 15);
    });

    test('handles zero volume', () {
      final status = TvStatus.fromJson({'volume': 0});
      expect(status.volume, 0);
    });

    test('handles max volume', () {
      final status =
          TvStatus.fromJson({'volume': 100});
      expect(status.volume, 100);
    });

    test('empty constant is idle with zero volume', () {
      expect(TvStatus.empty.volume, 0);
      expect(TvStatus.empty.muted, false);
      expect(TvStatus.empty.appId, '');
      expect(TvStatus.empty.appName, '');
      expect(TvStatus.empty.isIdle, true);
    });
  });
}

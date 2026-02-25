import 'package:flutter_test/flutter_test.dart';

import 'package:boretube_mobile/protocols/dial_client.dart';

void main() {
  group('DialClient.parseVolumeResponse', () {
    test('parses speaker volume and mute', () {
      final result = DialClient.parseVolumeResponse({
        'result': [
          [
            {
              'target': 'speaker',
              'volume': 25,
              'mute': false,
              'maxVolume': 100,
              'minVolume': 0,
            },
            {
              'target': 'headphone',
              'volume': 15,
              'mute': true,
              'maxVolume': 100,
              'minVolume': 0,
            },
          ],
        ],
        'id': 33,
      });

      expect(result, isNotNull);
      expect(result!.volume, 25);
      expect(result.muted, false);
    });

    test('prefers speaker over headphone', () {
      // Speaker comes first in array iteration
      final result = DialClient.parseVolumeResponse({
        'result': [
          [
            {
              'target': 'speaker',
              'volume': 30,
              'mute': false,
            },
            {
              'target': 'headphone',
              'volume': 50,
              'mute': true,
            },
          ],
        ],
        'id': 33,
      });

      expect(result!.volume, 30);
      expect(result.muted, false);
    });

    test('falls back to headphone if no speaker', () {
      final result = DialClient.parseVolumeResponse({
        'result': [
          [
            {
              'target': 'headphone',
              'volume': 42,
              'mute': true,
            },
          ],
        ],
        'id': 33,
      });

      expect(result!.volume, 42);
      expect(result.muted, true);
    });

    test('returns null when result is null', () {
      final result = DialClient.parseVolumeResponse({
        'result': null,
        'id': 33,
      });
      expect(result, isNull);
    });

    test('returns null when result is empty', () {
      final result = DialClient.parseVolumeResponse({
        'result': [],
        'id': 33,
      });
      expect(result, isNull);
    });

    test(
      'returns null when no speaker/headphone target',
      () {
        final result =
            DialClient.parseVolumeResponse({
          'result': [
            [
              {
                'target': 'hdmi',
                'volume': 50,
                'mute': false,
              },
            ],
          ],
          'id': 33,
        });
        expect(result, isNull);
      },
    );

    test('returns null when volumes list is empty', () {
      final result = DialClient.parseVolumeResponse({
        'result': [
          <dynamic>[],
        ],
        'id': 33,
      });
      expect(result, isNull);
    });

    test('defaults volume to 0 when missing', () {
      final result = DialClient.parseVolumeResponse({
        'result': [
          [
            {
              'target': 'speaker',
              'mute': false,
            },
          ],
        ],
        'id': 33,
      });

      expect(result!.volume, 0);
    });

    test('defaults mute to false when missing', () {
      final result = DialClient.parseVolumeResponse({
        'result': [
          [
            {
              'target': 'speaker',
              'volume': 10,
            },
          ],
        ],
        'id': 33,
      });

      expect(result!.muted, false);
    });

    test(
      'returns null when result key missing',
      () {
        final result =
            DialClient.parseVolumeResponse({
          'id': 33,
        });
        expect(result, isNull);
      },
    );

    test('handles real Sony BRAVIA response', () {
      // Actual response shape from Sony BRAVIA TV
      final result = DialClient.parseVolumeResponse({
        'result': [
          [
            {
              'target': 'speaker',
              'volume': 4,
              'mute': false,
              'maxVolume': 100,
              'minVolume': 0,
            },
            {
              'target': 'headphone',
              'volume': 15,
              'mute': false,
              'maxVolume': 100,
              'minVolume': 0,
            },
          ],
        ],
        'id': 33,
      });

      expect(result!.volume, 4);
      expect(result.muted, false);
    });

    test('handles muted speaker', () {
      final result = DialClient.parseVolumeResponse({
        'result': [
          [
            {
              'target': 'speaker',
              'volume': 4,
              'mute': true,
              'maxVolume': 100,
              'minVolume': 0,
            },
          ],
        ],
        'id': 33,
      });

      expect(result!.volume, 4);
      expect(result.muted, true);
    });
  });
}

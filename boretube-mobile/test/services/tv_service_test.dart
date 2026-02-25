import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:boretube_mobile/protocols/castv2_client.dart';
import 'package:boretube_mobile/protocols/dial_client.dart';
import 'package:boretube_mobile/services/tv_service.dart';

class MockCastV2Client extends Mock
    implements CastV2Client {}

class MockDialClient extends Mock
    implements DialClient {}

void main() {
  late MockCastV2Client mockCast;
  late MockDialClient mockDial;
  late TvService service;

  setUp(() {
    mockCast = MockCastV2Client();
    mockDial = MockDialClient();

    // Default stubs for disconnect (always called
    // in finally blocks).
    when(() => mockCast.disconnect())
        .thenAnswer((_) async {});

    service = TvService(
      host: '192.168.1.3',
      dialClient: mockDial,
      castFactory: () => mockCast,
    );
  });

  group('getStatus', () {
    test(
      'returns null when CastV2 returns null '
      '(TV unreachable)',
      () async {
        when(() => mockCast.getStatus())
            .thenAnswer((_) async => null);
        when(() => mockDial.getHardwareVolume())
            .thenAnswer(
          (_) async => (volume: 25, muted: false),
        );

        final status = await service.getStatus();
        expect(status, isNull);
      },
    );

    test(
      'overrides CastV2 volume with hardware volume',
      () async {
        when(() => mockCast.getStatus())
            .thenAnswer((_) async => {
                  'volume': 0, // CastV2 always 0
                  'muted': false,
                  'app_id': 'CC1AD845',
                  'app_name': 'YouTube',
                  'idle': false,
                });
        when(() => mockDial.getHardwareVolume())
            .thenAnswer(
          (_) async => (volume: 42, muted: true),
        );

        final status = await service.getStatus();

        expect(status, isNotNull);
        expect(status!.volume, 42);
        expect(status.muted, true);
        // App info from CastV2 preserved
        expect(status.appId, 'CC1AD845');
        expect(status.appName, 'YouTube');
        expect(status.isIdle, false);
      },
    );

    test(
      'falls back to CastV2 volume when hardware '
      'volume unavailable',
      () async {
        when(() => mockCast.getStatus())
            .thenAnswer((_) async => {
                  'volume': 5,
                  'muted': false,
                  'app_id': '',
                  'app_name': '',
                  'idle': true,
                });
        when(() => mockDial.getHardwareVolume())
            .thenAnswer((_) async => null);

        final status = await service.getStatus();

        expect(status, isNotNull);
        expect(status!.volume, 5);
      },
    );

    test(
      'hardware volume timeout does not kill CastV2',
      () async {
        when(() => mockCast.getStatus())
            .thenAnswer((_) async => {
                  'volume': 0,
                  'muted': false,
                  'app_id': 'E8C28D3C',
                  'app_name': 'Backdrop',
                  'idle': true,
                });
        when(() => mockDial.getHardwareVolume())
            .thenThrow(Exception('timeout'));

        final status = await service.getStatus();

        // CastV2 status still returned despite
        // hardware volume failure.
        expect(status, isNotNull);
        expect(status!.appName, 'Backdrop');
        expect(status.volume, 0); // Fallback
      },
    );

    test(
      'returns null when CastV2 throws',
      () async {
        when(() => mockCast.getStatus())
            .thenThrow(Exception('connection refused'));
        when(() => mockDial.getHardwareVolume())
            .thenAnswer(
          (_) async => (volume: 10, muted: false),
        );

        final status = await service.getStatus();
        expect(status, isNull);
      },
    );

    test('always disconnects CastV2 client', () async {
      when(() => mockCast.getStatus())
          .thenThrow(Exception('fail'));
      when(() => mockDial.getHardwareVolume())
          .thenAnswer((_) async => null);

      await service.getStatus();

      verify(() => mockCast.disconnect()).called(1);
    });
  });

  group('setVolume', () {
    test(
      'uses Sony REST API when available',
      () async {
        when(() => mockDial.setHardwareVolume(15))
            .thenAnswer((_) async => true);

        final ok = await service.setVolume(15);

        expect(ok, true);
        verify(() => mockDial.setHardwareVolume(15))
            .called(1);
        // CastV2 should NOT be called
        verifyNever(
          () => mockCast.setVolume(any()),
        );
      },
    );

    test(
      'falls back to CastV2 when Sony API fails',
      () async {
        when(() => mockDial.setHardwareVolume(15))
            .thenAnswer((_) async => false);
        when(() => mockCast.setVolume(15))
            .thenAnswer((_) async => true);

        final ok = await service.setVolume(15);

        expect(ok, true);
        verify(() => mockCast.setVolume(15)).called(1);
      },
    );

    test(
      'falls back to CastV2 when Sony API throws',
      () async {
        when(() => mockDial.setHardwareVolume(15))
            .thenThrow(Exception('timeout'));
        when(() => mockCast.setVolume(15))
            .thenAnswer((_) async => true);

        final ok = await service.setVolume(15);

        expect(ok, true);
      },
    );

    test(
      'returns false when both APIs fail',
      () async {
        when(() => mockDial.setHardwareVolume(15))
            .thenAnswer((_) async => false);
        when(() => mockCast.setVolume(15))
            .thenThrow(Exception('fail'));

        final ok = await service.setVolume(15);

        expect(ok, false);
      },
    );
  });

  group('bore', () {
    test('calls CastV2 bore and DIAL killApps', () async {
      when(() => mockCast.bore())
          .thenAnswer((_) async => true);
      when(() => mockDial.killApps())
          .thenAnswer((_) async {});

      await service.bore();

      verify(() => mockCast.bore()).called(1);
      verify(() => mockDial.killApps()).called(1);
    });

    test(
      'does not throw when CastV2 bore fails',
      () async {
        when(() => mockCast.bore())
            .thenThrow(Exception('fail'));
        when(() => mockDial.killApps())
            .thenAnswer((_) async {});

        // Should not throw
        await service.bore();
      },
    );

    test(
      'does not throw when DIAL killApps fails',
      () async {
        when(() => mockCast.bore())
            .thenAnswer((_) async => true);
        when(() => mockDial.killApps())
            .thenThrow(Exception('fail'));

        await service.bore();
      },
    );
  });

  group('error resilience — never throws', () {
    test('mute returns false on error', () async {
      when(() => mockCast.mute())
          .thenThrow(Exception('fail'));

      final ok = await service.mute();
      expect(ok, false);
    });

    test('unmute returns false on error', () async {
      when(() => mockCast.unmute())
          .thenThrow(Exception('fail'));

      final ok = await service.unmute();
      expect(ok, false);
    });

    test('restore does not throw on error', () async {
      when(() => mockCast.unmute())
          .thenThrow(Exception('fail'));

      await service.restore();
    });

    test('killApp does not throw on error', () async {
      when(() => mockCast.stop())
          .thenThrow(Exception('fail'));
      when(() => mockDial.killApps())
          .thenThrow(Exception('fail'));

      await service.killApp();
    });

    test(
      'isReachable returns false on error',
      () async {
        when(() => mockDial.isReachable())
            .thenThrow(Exception('fail'));

        final ok = await service.isReachable();
        expect(ok, false);
      },
    );

    test(
      'getDeviceName returns null on error',
      () async {
        when(() => mockDial.getDeviceName())
            .thenThrow(Exception('fail'));

        final name = await service.getDeviceName();
        expect(name, isNull);
      },
    );
  });
}

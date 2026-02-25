import 'package:flutter_test/flutter_test.dart';

import 'package:boretube_mobile/models/log_entry.dart';

void main() {
  group('LogEntry', () {
    test('round-trip serialization', () {
      final original = LogEntry(
        timestamp: DateTime(2025, 6, 15, 12, 30, 45),
        message: 'YouTube (whitelisted)',
      );

      final stored = original.toStorageString();
      final restored =
          LogEntry.fromStorageString(stored);

      expect(
        restored.timestamp.millisecondsSinceEpoch,
        original.timestamp.millisecondsSinceEpoch,
      );
      expect(restored.message, original.message);
    });

    test('isStopped defaults to false', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        message: 'Home screen (idle)',
      );
      expect(entry.isStopped, false);
    });

    test(
      'fromStorageString detects STOPPED prefix',
      () {
        final entry = LogEntry.fromStorageString(
          '1718451045000|STOPPED: Netflix (ABC123)',
        );
        expect(entry.isStopped, true);
        expect(
          entry.message,
          'STOPPED: Netflix (ABC123)',
        );
      },
    );

    test(
      'fromStorageString non-STOPPED message',
      () {
        final entry = LogEntry.fromStorageString(
          '1718451045000|YouTube (whitelisted)',
        );
        expect(entry.isStopped, false);
      },
    );

    test('fromStorageString handles no pipe', () {
      final entry =
          LogEntry.fromStorageString('no pipe here');
      expect(entry.message, 'no pipe here');
    });

    test(
      'fromStorageString handles invalid timestamp',
      () {
        final entry =
            LogEntry.fromStorageString('abc|message');
        expect(entry.message, 'message');
        // Invalid timestamp defaults to epoch 0
        expect(
          entry.timestamp.millisecondsSinceEpoch,
          0,
        );
      },
    );

    test('message with pipe delimiter preserved', () {
      final original = LogEntry(
        timestamp: DateTime(2025, 1, 1),
        message: 'vol=50% | capped to 15%',
      );

      final stored = original.toStorageString();
      final restored =
          LogEntry.fromStorageString(stored);

      expect(
        restored.message,
        'vol=50% | capped to 15%',
      );
    });
  });
}

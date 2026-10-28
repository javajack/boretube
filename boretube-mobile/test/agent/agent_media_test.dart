import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'agent_client_test.dart' show contractRules, contractStatus;

/// `GET /v1/status` from a 1.1.0 agent (README example values).
final status110 = <String, dynamic>{
  ...contractStatus,
  'version': '1.1.0',
  'health': [
    {'id': 'youtube', 'status': 'ok', 'detail': 'Removed'},
    {'id': 'mediaAccess', 'status': 'warn', 'detail': 'dumpsys fallback'},
  ],
  'media': {
    'pkg': 'org.smarttube.stable',
    'title': 'Episode 4',
    'artist': 'Kids Channel • 2M views',
    'state': 'playing',
    'positionMs': 312000,
    'durationMs': 1260000,
    'remainingMs': 948000,
    'source': 'listener',
  },
  'endAfter': {
    'armed': true,
    'startedAt': 1793260800000,
    'capAt': 1793263500000,
    'title': 'Episode 4',
    'pkg': 'org.smarttube.stable',
    'breakMin': 60,
  },
  'shorts': {
    'mode': 'budget',
    'todayCount': 7,
    'lastDetectedAt': 1793260500000,
    'active': false,
    'perDay': 10,
  },
};

void main() {
  group('status 1.1.0', () {
    test('media, endAfter and shorts are typed', () {
      final s = AgentStatus.fromJson(status110);
      final m = s.media!;
      expect(m.pkg, 'org.smarttube.stable');
      expect(m.title, 'Episode 4');
      expect(m.artist, 'Kids Channel • 2M views');
      expect(m.state, MediaState.playing);
      expect(m.source, MediaSource.listener);
      expect(m.live, isTrue);
      expect(m.timed, isTrue);
      expect(m.left, const Duration(milliseconds: 948000));
      expect(m.progress, closeTo(312 / 1260, 1e-9));

      expect(s.endAfter.armed, isTrue);
      expect(s.endAfter.title, 'Episode 4');
      expect(s.endAfter.breakMin, 60);
      expect(
        s.endAfter.capAt,
        DateTime.fromMillisecondsSinceEpoch(1793263500000),
      );

      final sh = s.shorts!;
      expect(sh.mode, ShortsMode.budget);
      expect(sh.todayCount, 7);
      expect(sh.perDay, 10);
      expect(sh.active, isFalse);
      expect(s.mediaAccessMissing, isTrue);
    });

    test('round-trips to the same JSON', () {
      final s = AgentStatus.fromJson(status110);
      expect(jsonDecode(jsonEncode(s.toJson())), status110);
    });

    test('dumpsys fallback: no duration, so no time and no progress', () {
      final m = AgentMedia.fromJson(const {
        'pkg': 'org.smarttube.stable',
        'title': 'Something',
        'state': 'paused',
        'positionMs': 40000,
        'source': 'dumpsys',
      });
      expect(m.timed, isFalse);
      expect(m.left, isNull);
      expect(m.progress, isNull);
      expect(m.live, isTrue);
      expect(m.source, MediaSource.dumpsys);
    });

    test('an older agent has none of it, and nothing breaks', () {
      final s = AgentStatus.fromJson(contractStatus);
      expect(s.media, isNull);
      expect(s.shorts, isNull);
      expect(s.endAfter.armed, isFalse);
      expect(s.mediaAccessMissing, isFalse);
    });

    test('unknown media states and junk are lenient', () {
      final m = AgentMedia.fromJson(const {
        'pkg': 'x',
        'state': 'rewinding',
        'title': '',
        'durationMs': 0,
      });
      expect(m.state, MediaState.other);
      expect(m.live, isFalse);
      expect(m.title, isNull);
      expect(m.timed, isFalse);
    });
  });

  group('rules.shorts', () {
    final withShorts = <String, dynamic>{
      ...contractRules,
      'shorts': {'mode': 'budget', 'perDay': 10, 'note': 'from 1.2'},
      'futureField': {'a': 1},
    };

    test('typed, and round-trips with unknown fields', () {
      final r = AgentRules.fromJson(withShorts);
      expect(r.shorts!.mode, ShortsMode.budget);
      expect(r.shorts!.perDay, 10);
      expect(r.extra.containsKey('shorts'), isFalse);
      expect(jsonDecode(jsonEncode(r.toJson())), withShorts);
    });

    test('editing anything else never drops it', () {
      final r = AgentRules.fromJson(withShorts).copyWith(
        alwaysMute: true,
        volumeLimit: const VolumeLimit(maxPercent: 20, enabled: true),
      );
      final j = r.toJson();
      expect(j['shorts'], {'mode': 'budget', 'perDay': 10, 'note': 'from 1.2'});
      expect(j['futureField'], {'a': 1});
    });

    test('absent stays absent; clearShorts goes back to absent', () {
      final r = AgentRules.fromJson(contractRules);
      expect(r.shorts, isNull);
      expect(r.shortsRule.mode, ShortsMode.off);
      expect(r.toJson().containsKey('shorts'), isFalse);
      final on = r.copyWith(shorts: const ShortsRule(mode: ShortsMode.block));
      expect(on.toJson()['shorts'], {'mode': 'block', 'perDay': 5});
      expect(on.copyWith(clearShorts: true).toJson().containsKey('shorts'),
          isFalse);
    });

    test('a phone save sends shorts back to the TV', () async {
      http.Request? put;
      final c = AgentClient(
        host: '192.168.1.3',
        token: 't',
        httpClient: MockClient((req) async {
          if (req.method == 'PUT') put = req;
          return http.Response(
            req.method == 'PUT' ? req.body : jsonEncode(withShorts),
            200,
          );
        }),
      );
      final r = await c.rules();
      final saved = await c.putRules(r.copyWith(alwaysMute: true));
      expect(jsonDecode(put!.body)['shorts']['mode'], 'budget');
      expect(jsonDecode(put!.body)['shorts']['note'], 'from 1.2');
      expect(saved.shorts!.perDay, 10);
    });
  });

  group('actions', () {
    test('endAfter and cancelEndAfter on the wire', () {
      expect(const AgentAction.endAfter().toJson(), {
        'action': 'endAfter',
        'capMin': 45,
        'breakMin': 60,
      });
      expect(
        const AgentAction.endAfter(capMin: 45, breakMin: 130).toJson(),
        {'action': 'endAfter', 'capMin': 45, 'breakMin': 130},
      );
      expect(
        const AgentAction(AgentActionKind.cancelEndAfter).toJson(),
        {'action': 'cancelEndAfter'},
      );
      final back = AgentAction.fromJson(const {
        'action': 'endAfter',
        'capMin': 30,
        'breakMin': 20,
      });
      expect(back.kind, AgentActionKind.endAfter);
      expect(back.capMin, 30);
      expect(back.breakMin, 20);
    });
  });

  group('versions', () {
    test('dotted compare', () {
      expect(compareVersions('1.0.1', '1.1.0'), -1);
      expect(compareVersions('1.1.0', '1.1.0'), 0);
      expect(compareVersions('1.10.0', '1.9.3'), 1);
      expect(compareVersions('1.1', '1.1.0'), 0);
      expect(compareVersions('1.1.0-beta', '1.1.0'), 0);
    });

    test('an update is offered only for an older agent', () {
      const m = AgentManifest(
        versionName: '1.1.0',
        versionCode: 3,
        sha256: 'x',
      );
      expect(agentUpdateAvailable('1.0.1', m), isTrue);
      expect(agentUpdateAvailable('1.1.0', m), isFalse);
      expect(agentUpdateAvailable('1.2.0', m), isFalse);
      expect(agentUpdateAvailable('', m), isFalse);
    });
  });
}

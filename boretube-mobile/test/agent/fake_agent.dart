import 'dart:convert';
import 'dart:typed_data';

import 'package:boretube_mobile/adb/adb_connection.dart';
import 'package:boretube_mobile/adb/adb_identity.dart';
import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const kToken = 'f00dfeedf00dfeedf00dfeedf00dfeedf00dfeedf00dfeedf00dfeedf00dfeed';

/// A test APK of [size] bytes and a matching manifest.
AgentBundle fakeBundle({int size = 100 * 1024, String version = '1.0.0'}) {
  final apk = Uint8List.fromList(List.generate(size, (i) => (i * 31) & 0xff));
  return AgentBundle(
    AgentManifest(
      versionName: version,
      versionCode: 1,
      sha256: sha256.convert(apk).toString(),
    ),
    apk,
  );
}

/// A TV over ADB that understands the installer's commands.
class FakeAgentTv implements AdbShell {
  final log = <String>[];
  final files = <String, BytesBuilder>{};
  bool installed = false;
  bool disabled = false;
  bool running = false;
  String versionName = '1.0.0';
  int versionCode = 1;
  String? token = kToken;

  /// `cat token` fails this many times first (agent still starting).
  int tokenDelay = 0;

  /// Command prefixes that fail.
  final failing = <String>{};

  /// Corrupts pushed data (to test the post-copy checksum).
  bool corrupt = false;

  List<String> get writes => [
        for (final c in log)
          if (!c.startsWith('pidof') &&
              !c.startsWith('cat ') &&
              !c.startsWith('sha256sum') &&
              !c.startsWith('pm list') &&
              !c.startsWith("printf"))
            c,
      ];

  @override
  Future<AdbShellResult> shell(String c) async {
    log.add(c);
    if (failing.any(c.startsWith)) return const AdbShellResult('Error', 1);
    if (c == AgentInstaller.diagnoseCommand) {
      final line = 'package:$kAgentPackage\n';
      return AdbShellResult(
        '${installed ? line : ''}---\n'
        '${installed && disabled ? line : ''}---\n'
        '${installed && running ? '4242\n' : ''}---\n'
        '${installed ? '    versionCode=$versionCode minSdk=26\n'
            '    versionName=$versionName\n' : ''}',
        0,
      );
    }
    if (c.startsWith('rm -f ')) {
      files.remove(c.substring(6));
      return const AdbShellResult('', 0);
    }
    final push = RegExp(r"^printf %s '([^']*)' \| base64 -d >> (\S+)$")
        .firstMatch(c);
    if (push != null) {
      final bytes = base64Decode(push.group(1)!);
      if (corrupt) bytes[0] ^= 1;
      (files[push.group(2)!] ??= BytesBuilder()).add(bytes);
      return const AdbShellResult('', 0);
    }
    if (c.startsWith('sha256sum ')) {
      final path = c.substring(10);
      final f = files[path];
      if (f == null) return const AdbShellResult('No such file', 1);
      return AdbShellResult(
        '${sha256.convert(f.toBytes())}  $path\n',
        0,
      );
    }
    if (c.startsWith('pm install -r -g ')) {
      installed = true;
      disabled = false;
      return const AdbShellResult('Success\n', 0);
    }
    if (c.startsWith('appops set ') || c.startsWith('pm grant ')) {
      return const AdbShellResult('', 0);
    }
    if (c.startsWith('am start-foreground-service')) {
      if (!installed || disabled) {
        return const AdbShellResult('Error: not found', 255);
      }
      running = true;
      return const AdbShellResult('Starting service\n', 0);
    }
    if (c == 'pidof $kAgentPackage') {
      return running
          ? const AdbShellResult('4242\n', 0)
          : const AdbShellResult('', 1);
    }
    if (c == 'cat ${AgentInstaller.tokenPath}') {
      if (tokenDelay > 0 || token == null || !running) {
        tokenDelay--;
        return const AdbShellResult('No such file or directory', 1);
      }
      return AdbShellResult('$token\n', 0);
    }
    if (c == 'pm enable $kAgentPackage') {
      disabled = false;
      return const AdbShellResult('new state: enabled', 0);
    }
    if (c == AgentInstaller.uninstallCommand) {
      installed = false;
      running = false;
      return const AdbShellResult('Success\n', 0);
    }
    return AdbShellResult('unknown: $c', 127);
  }
}

/// The agent's HTTP side. [selfAdb] answers in turn (last one repeats).
class FakeAgentHttp {
  final FakeAgentTv tv;
  List<String> selfAdb = ['ok'];
  final requests = <http.Request>[];
  String version = '1.0.0';
  int _i = 0;

  FakeAgentHttp(this.tv);

  http.Client get client => MockClient((r) async {
        requests.add(r);
        if (!tv.running) {
          throw http.ClientException('Connection refused');
        }
        if (r.headers['Authorization'] != 'Bearer ${tv.token}') {
          return http.Response('{}', 401);
        }
        switch (r.url.path) {
          case '/v1/status':
            final s = selfAdb[_i.clamp(0, selfAdb.length - 1)];
            _i++;
            return http.Response(
              jsonEncode({
                'agentId': 'agent-1',
                'version': version,
                'selfAdb': s,
                'mode': 'normal',
              }),
              200,
            );
          default:
            return http.Response('{"ok":true}', 200);
        }
      });

  List<String> get paths => [for (final r in requests) r.url.path];
}

AgentInstaller installerFor(
  FakeAgentTv tv,
  FakeAgentHttp agent, {
  AgentBundle? bundle,
  bool missing = false,
  MemorySecretStore? secrets,
}) {
  final store = AgentTokenStore(secrets ?? MemorySecretStore());
  var t = DateTime(2026, 10, 28, 12);
  return AgentInstaller(
    adb: tv,
    tvId: 'tv1',
    tokens: store,
    clientFor: (token) => AgentClient(
      host: '192.168.1.3',
      token: token,
      httpClient: agent.client,
    ),
    loadBundle: () async {
      if (missing) throw const AgentBundleMissing();
      return bundle ?? fakeBundle();
    },
    profile: const {'id': 'sony-bravia-vu3', 'name': 'Sony BRAVIA VU3'},
    clock: () => t,
    delay: (d) async => t = t.add(d),
  );
}

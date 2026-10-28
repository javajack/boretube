import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'agent_models.dart';

export 'agent_models.dart';

/// Any failure talking to the agent.
class AgentException implements Exception {
  final String message;
  const AgentException(this.message);
  @override
  String toString() => 'AgentException: $message';
}

/// 401: the token is missing or wrong (re-read it over ADB).
class AgentAuthException extends AgentException {
  const AgentAuthException() : super('token rejected (401)');
}

/// 409 on `PUT /v1/rules`: the TV holds a newer document.
class AgentConflict extends AgentException {
  final AgentRules current;
  const AgentConflict(this.current) : super('rules changed on the TV (409)');
}

/// No answer (TV off, agent not running, timeout).
class AgentUnreachable extends AgentException {
  const AgentUnreachable(super.message);
}

/// Any other HTTP status.
class AgentHttpException extends AgentException {
  final int statusCode;
  final String body;
  AgentHttpException(this.statusCode, this.body)
      : super('HTTP $statusCode${body.isEmpty ? '' : ': $body'}');
}

/// HTTP/JSON client for the TV Guard agent on `:8790` (contract v1).
class AgentClient {
  static const defaultPort = 8790;
  static const statusTimeout = Duration(seconds: 2);
  static const writeTimeout = Duration(seconds: 5);

  final String host;
  final int port;
  final String token;
  final http.Client _http;
  final DateTime Function() _clock;

  AgentClient({
    required this.host,
    this.port = defaultPort,
    required this.token,
    http.Client? httpClient,
    DateTime Function()? clock,
  })  : _http = httpClient ?? http.Client(),
        _clock = clock ?? DateTime.now;

  Uri _uri(String path, [Map<String, String>? query]) => Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query,
      );

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'X-Phone-Time': '${_clock().millisecondsSinceEpoch}',
        'Accept': 'application/json',
      };

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration timeout = writeTimeout,
  }) async {
    final req = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw AgentUnreachable('no answer in ${timeout.inSeconds}s');
    } on SocketException catch (e) {
      throw AgentUnreachable(e.message);
    } on http.ClientException catch (e) {
      throw AgentUnreachable(e.message);
    }
    Object? json;
    if (res.body.isNotEmpty) {
      try {
        json = jsonDecode(res.body);
      } on FormatException {
        json = null;
      }
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const AgentAuthException();
    }
    if (res.statusCode == 409 && AgentRules.looksLike(json)) {
      throw AgentConflict(
        AgentRules.fromJson((json! as Map).cast<String, dynamic>()),
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AgentHttpException(res.statusCode, res.body);
    }
    return json;
  }

  static Map<String, dynamic> _asMap(Object? j) {
    if (j is Map) return j.cast<String, dynamic>();
    throw const AgentException('unexpected reply (not a JSON object)');
  }

  /// `GET /v1/status` (2 s timeout).
  Future<AgentStatus> status() async => AgentStatus.fromJson(
        _asMap(await _send('GET', '/v1/status', timeout: statusTimeout)),
      );

  /// `GET /v1/rules`.
  Future<AgentRules> rules() async =>
      AgentRules.fromJson(_asMap(await _send('GET', '/v1/rules')));

  /// `PUT /v1/rules` with the whole document; [rules].version must equal
  /// the TV's, else [AgentConflict]. Returns the saved document (the
  /// reply body, or a fresh GET when the reply isn't the document).
  Future<AgentRules> putRules(AgentRules rules) async {
    final j = await _send('PUT', '/v1/rules', body: rules.toJson());
    if (AgentRules.looksLike(j)) {
      return AgentRules.fromJson((j! as Map).cast<String, dynamic>());
    }
    return this.rules();
  }

  /// `POST /v1/action`.
  Future<AgentActionResult> action(AgentAction a) async =>
      AgentActionResult.fromJson(
        _asMap(await _send('POST', '/v1/action', body: a.toJson())),
      );

  /// `GET /v1/journal?since=<epochMs>`. Accepts a bare list or
  /// `{entries: [...]}`.
  Future<List<AgentJournalEntry>> journal({DateTime? since}) async {
    final j = await _send(
      'GET',
      '/v1/journal',
      query: {'since': '${since?.millisecondsSinceEpoch ?? 0}'},
    );
    final list = j is List
        ? j
        : j is Map && j['entries'] is List
            ? j['entries'] as List
            : const [];
    return [
      for (final e in list)
        if (e is Map) AgentJournalEntry.fromJson(e.cast<String, dynamic>()),
    ];
  }

  /// `POST /v1/mode`.
  Future<void> setMode(AgentMode mode) =>
      _send('POST', '/v1/mode', body: {'mode': mode.name});

  /// `POST /v1/approveBuild`.
  Future<void> approveBuild() => _send('POST', '/v1/approveBuild');

  /// `POST /v1/profile` with the device-profile JSON, plus the cleanup
  /// packages that are disabled now ([keepDisabled]) so the watchdog
  /// keeps them that way.
  Future<void> pushProfile(
    Map<String, dynamic> profile, {
    List<String>? keepDisabled,
  }) =>
      _send(
        'POST',
        '/v1/profile',
        body: {
          ...profile,
          if (keepDisabled != null) 'keepDisabled': keepDisabled,
        },
      );

  /// `GET /v1/watchdog`: a dry-run report.
  Future<WatchdogReport> watchdogReport() async =>
      WatchdogReport.fromJson(await _send('GET', '/v1/watchdog'));

  /// `POST /v1/watchdog`: run the watchdog now.
  Future<WatchdogReport> runWatchdog() async => WatchdogReport.fromJson(
        await _send(
          'POST',
          '/v1/watchdog',
          timeout: const Duration(seconds: 30),
        ),
      );

  /// `POST /v1/restore`. The agent journals each step and then pauses.
  /// It never uninstalls itself: its plan ends with a `removeAgent` step
  /// the phone runs over ADB. The phone's own RestoreRunner is the main
  /// path; this is a convenience (and [dryRun] a preview).
  Future<AgentActionResult> restore(
    RestoreTarget target, {
    bool dryRun = false,
    bool alsoRemoveLauncherHelper = false,
    bool journalSteps = true,
  }) async {
    final j = await _send(
      'POST',
      '/v1/restore',
      body: {
        'target': target.name,
        if (dryRun) 'dryRun': true,
        if (alsoRemoveLauncherHelper) 'alsoRemoveLauncherHelper': true,
        if (!journalSteps) 'journalSteps': false,
      },
      timeout: const Duration(seconds: 60),
    );
    return j is Map
        ? AgentActionResult.fromJson(j.cast<String, dynamic>())
        : const AgentActionResult(ok: true);
  }

  void close() => _http.close();
}

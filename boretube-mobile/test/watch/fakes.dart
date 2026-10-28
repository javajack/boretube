import 'package:boretube_mobile/watch/always_on_watch.dart';

/// Records what would have been posted; no platform channels.
class FakeAlertNotifier implements AlertNotifier {
  final shown = <({int id, String title, String body, String? payload})>[];
  bool? allowed;
  bool grant;
  int asks = 0;
  String? launch;
  void Function(String? payload)? onOpen;

  FakeAlertNotifier({this.allowed = true, this.grant = true});

  @override
  Future<void> init({void Function(String? payload)? onOpen}) async {
    this.onOpen = onOpen;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async =>
      shown.add((id: id, title: title, body: body, payload: payload));

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<bool?> enabled() async => allowed;

  @override
  Future<bool> requestPermission() async {
    asks++;
    allowed = grant;
    return grant;
  }
}

class FakeScheduler implements WatchScheduler {
  final calls = <String>[];

  @override
  Future<void> schedule({bool replace = false}) async =>
      calls.add(replace ? 'schedule(replace)' : 'schedule');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

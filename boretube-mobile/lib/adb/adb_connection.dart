import 'adb_client.dart';
import 'adb_key.dart';

export 'adb_client.dart' show AdbAuthPendingException, AdbShellResult;

/// Anything that can run a shell command on a TV. [TvOps] only needs this,
/// so tests can fake it without sockets.
abstract interface class AdbShell {
  Future<AdbShellResult> shell(String command);
}

/// One ADB transport connection. [AdbClient] is the real implementation;
/// tests inject fakes through [AdbConnectionFactory].
abstract interface class AdbConnection {
  bool get isConnected;

  /// Completes when the connection drops or is closed.
  Future<void> get closed;

  /// Connects and authenticates. Calls [onAwaitingApproval] once the public
  /// key has been sent and the TV shows "Allow USB debugging?".
  Future<void> connect({
    Duration timeout,
    Duration promptTimeout,
    void Function()? onAwaitingApproval,
  });

  Future<AdbShellResult> shell(
    String command, {
    Duration timeout,
  });

  Future<void> close();
}

typedef AdbConnectionFactory = AdbConnection Function(
  String host,
  int port,
  AdbKey key,
  String keyName,
);

AdbConnection defaultAdbConnectionFactory(
  String host,
  int port,
  AdbKey key,
  String keyName,
) =>
    AdbClient(host: host, port: port, key: key, keyName: keyName);

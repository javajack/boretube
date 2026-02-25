class LogEntry {
  final DateTime timestamp;
  final String message;
  final bool isStopped;

  const LogEntry({
    required this.timestamp,
    required this.message,
    this.isStopped = false,
  });

  String toStorageString() =>
      '${timestamp.millisecondsSinceEpoch}|$message';

  factory LogEntry.fromStorageString(String s) {
    final idx = s.indexOf('|');
    if (idx < 0) {
      return LogEntry(
        timestamp: DateTime.now(),
        message: s,
      );
    }
    final ts = int.tryParse(s.substring(0, idx)) ?? 0;
    final msg = s.substring(idx + 1);
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      message: msg,
      isStopped: msg.startsWith('STOPPED'),
    );
  }
}

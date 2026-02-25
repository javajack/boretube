class WhitelistEntry {
  final String appId;
  final String friendlyName;

  const WhitelistEntry({
    required this.appId,
    required this.friendlyName,
  });

  /// Backdrop (Home Screen) — always whitelisted, cannot be removed.
  static const WhitelistEntry backdrop = WhitelistEntry(
    appId: 'E8C28D3C',
    friendlyName: 'Backdrop (Home Screen)',
  );

  String toStorageString() => '$appId|$friendlyName';

  factory WhitelistEntry.fromStorageString(String s) {
    final idx = s.indexOf('|');
    if (idx < 0) {
      return WhitelistEntry(
        appId: s,
        friendlyName: 'Unknown',
      );
    }
    return WhitelistEntry(
      appId: s.substring(0, idx),
      friendlyName: s.substring(idx + 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhitelistEntry && appId == other.appId;

  @override
  int get hashCode => appId.hashCode;
}

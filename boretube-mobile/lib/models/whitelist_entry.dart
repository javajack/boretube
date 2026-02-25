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
    final parts = s.split('|');
    return WhitelistEntry(
      appId: parts[0],
      friendlyName: parts.length > 1 ? parts[1] : 'Unknown',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhitelistEntry && appId == other.appId;

  @override
  int get hashCode => appId.hashCode;
}

class TvStatus {
  final int volume;
  final bool muted;
  final String appId;
  final String appName;
  final bool isIdle;

  const TvStatus({
    required this.volume,
    required this.muted,
    required this.appId,
    required this.appName,
    required this.isIdle,
  });

  factory TvStatus.fromJson(Map<String, dynamic> json) {
    return TvStatus(
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      muted: json['muted'] as bool? ?? false,
      appId: json['app_id'] as String? ?? '',
      appName: json['app_name'] as String? ?? '',
      isIdle: json['idle'] as bool? ?? true,
    );
  }

  static const TvStatus empty = TvStatus(
    volume: 0,
    muted: false,
    appId: '',
    appName: '',
    isIdle: true,
  );
}

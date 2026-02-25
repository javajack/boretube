class TvConfig {
  final String ip;
  final String name;
  final int dialPort;
  final int castPort;

  const TvConfig({
    required this.ip,
    this.name = '',
    this.dialPort = 8008,
    this.castPort = 8009,
  });

  static const TvConfig defaultConfig = TvConfig(
    ip: '192.168.1.3',
    name: 'Sony BRAVIA',
    dialPort: 8008,
    castPort: 8009,
  );

  TvConfig copyWith({
    String? ip,
    String? name,
    int? dialPort,
    int? castPort,
  }) {
    return TvConfig(
      ip: ip ?? this.ip,
      name: name ?? this.name,
      dialPort: dialPort ?? this.dialPort,
      castPort: castPort ?? this.castPort,
    );
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'name': name,
        'dialPort': dialPort,
        'castPort': castPort,
      };

  factory TvConfig.fromJson(Map<String, dynamic> json) {
    return TvConfig(
      ip: json['ip'] as String? ?? '192.168.1.3',
      name: json['name'] as String? ?? '',
      dialPort: json['dialPort'] as int? ?? 8008,
      castPort: json['castPort'] as int? ?? 8009,
    );
  }
}

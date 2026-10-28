/// What a TV can do, found by probing (see capabilities.dart).
enum TvCapability { cast, dial, sonyRest, adb, agent }

/// A TV the app knows about, keyed by a stable [id] that survives IP
/// changes (agent id > ADB serial > Cast/UDN uuid > "ip:<addr>").
class Tv {
  final String id;
  final String name;
  final String manufacturer;
  final String model;
  final String ip;
  final int castPort;
  final int dialPort;
  final int adbPort;
  final int agentPort;

  /// ADB mDNS instance name, e.g. "adb-qaezcxxq07001865", when known.
  final String? adbSerial;

  /// Cast/DIAL UDN uuid, when known.
  final String? udn;

  final Set<TvCapability> capabilities;
  final DateTime? capabilitiesCheckedAt;
  final DateTime? lastSeen;

  const Tv({
    required this.id,
    required this.name,
    this.manufacturer = '',
    this.model = '',
    required this.ip,
    this.castPort = 8009,
    this.dialPort = 8008,
    this.adbPort = 5555,
    this.agentPort = 8790,
    this.adbSerial,
    this.udn,
    this.capabilities = const {},
    this.capabilitiesCheckedAt,
    this.lastSeen,
  });

  bool can(TvCapability c) => capabilities.contains(c);

  /// Best stable id from what is known about the TV.
  static String stableId({
    String? agentId,
    String? adbSerial,
    String? udn,
    required String ip,
  }) {
    if (agentId != null && agentId.isNotEmpty) return 'agent:$agentId';
    if (adbSerial != null && adbSerial.isNotEmpty) return 'adb:$adbSerial';
    if (udn != null && udn.isNotEmpty) return 'udn:$udn';
    return 'ip:$ip';
  }

  Tv copyWith({
    String? id,
    String? name,
    String? manufacturer,
    String? model,
    String? ip,
    int? castPort,
    int? dialPort,
    int? adbPort,
    int? agentPort,
    String? adbSerial,
    String? udn,
    Set<TvCapability>? capabilities,
    DateTime? capabilitiesCheckedAt,
    DateTime? lastSeen,
  }) =>
      Tv(
        id: id ?? this.id,
        name: name ?? this.name,
        manufacturer: manufacturer ?? this.manufacturer,
        model: model ?? this.model,
        ip: ip ?? this.ip,
        castPort: castPort ?? this.castPort,
        dialPort: dialPort ?? this.dialPort,
        adbPort: adbPort ?? this.adbPort,
        agentPort: agentPort ?? this.agentPort,
        adbSerial: adbSerial ?? this.adbSerial,
        udn: udn ?? this.udn,
        capabilities: capabilities ?? this.capabilities,
        capabilitiesCheckedAt:
            capabilitiesCheckedAt ?? this.capabilitiesCheckedAt,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
        'model': model,
        'ip': ip,
        'castPort': castPort,
        'dialPort': dialPort,
        'adbPort': adbPort,
        'agentPort': agentPort,
        'adbSerial': adbSerial,
        'udn': udn,
        'capabilities': capabilities.map((c) => c.name).toList(),
        'capabilitiesCheckedAt': capabilitiesCheckedAt?.toIso8601String(),
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory Tv.fromJson(Map<String, dynamic> j) => Tv(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'TV',
        manufacturer: j['manufacturer'] as String? ?? '',
        model: j['model'] as String? ?? '',
        ip: j['ip'] as String,
        castPort: j['castPort'] as int? ?? 8009,
        dialPort: j['dialPort'] as int? ?? 8008,
        adbPort: j['adbPort'] as int? ?? 5555,
        agentPort: j['agentPort'] as int? ?? 8790,
        adbSerial: j['adbSerial'] as String?,
        udn: j['udn'] as String?,
        capabilities: {
          for (final n in (j['capabilities'] as List?) ?? const [])
            for (final c in TvCapability.values)
              if (c.name == n) c,
        },
        capabilitiesCheckedAt:
            DateTime.tryParse(j['capabilitiesCheckedAt'] as String? ?? ''),
        lastSeen: DateTime.tryParse(j['lastSeen'] as String? ?? ''),
      );
}

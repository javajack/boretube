/// Where a discovery hit came from.
enum DiscoverySource { mdns, ssdp, sweep }

/// One raw discovery hit, before identification and merging.
class DiscoveredDevice {
  final String ip;
  final DiscoverySource source;

  /// Cast friendly name (mDNS TXT `fn=`).
  final String? castName;

  /// Cast model name (mDNS TXT `md=`).
  final String? castModel;

  /// Cast device uuid in UDN form (dashed), from mDNS TXT `id=`.
  final String? castUuid;

  /// ADB mDNS instance name, e.g. `adb-qaezcxxq07001865`.
  final String? adbSerial;

  /// TV Guard agent id (`_boretube._tcp` TXT `id=`).
  final String? agentId;

  /// Service ports seen, keyed by service type such as `_googlecast._tcp`.
  final Map<String, int> ports;

  const DiscoveredDevice({
    required this.ip,
    required this.source,
    this.castName,
    this.castModel,
    this.castUuid,
    this.adbSerial,
    this.agentId,
    this.ports = const {},
  });

  @override
  String toString() => 'DiscoveredDevice($ip via ${source.name}'
      '${castName != null ? ' "$castName"' : ''}'
      '${adbSerial != null ? ' adb=$adbSerial' : ''}'
      '${castUuid != null ? ' uuid=$castUuid' : ''}'
      '${agentId != null ? ' agent=$agentId' : ''} $ports)';
}

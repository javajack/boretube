import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tv/tv.dart';
import '../ui/tokens.dart';

final _ipPattern = RegExp(
  r'^((25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(25[0-5]|2[0-4]\d|1?\d?\d)$',
);

bool isValidIp(String s) => _ipPattern.hasMatch(s.trim());

/// Manual TV entry / edit: name, IP and ports. Returns the edited TV.
Future<Tv?> showTvAddressDialog(BuildContext context, {Tv? initial}) {
  return showDialog<Tv>(
    context: context,
    builder: (context) => _TvAddressDialog(initial: initial),
  );
}

class _TvAddressDialog extends StatefulWidget {
  final Tv? initial;
  const _TvAddressDialog({this.initial});

  @override
  State<_TvAddressDialog> createState() => _TvAddressDialogState();
}

class _TvAddressDialogState extends State<_TvAddressDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _ip = TextEditingController(text: widget.initial?.ip ?? '');
  late final _cast =
      TextEditingController(text: '${widget.initial?.castPort ?? 8009}');
  late final _dial =
      TextEditingController(text: '${widget.initial?.dialPort ?? 8008}');
  late final _adb =
      TextEditingController(text: '${widget.initial?.adbPort ?? 5555}');
  bool _advanced = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _ip, _cast, _dial, _adb]) {
      c.dispose();
    }
    super.dispose();
  }

  int _port(TextEditingController c, int fallback) {
    final v = int.tryParse(c.text.trim());
    return v == null || v < 1 || v > 65535 ? fallback : v;
  }

  void _save() {
    final ip = _ip.text.trim();
    if (!isValidIp(ip)) {
      setState(() => _error = 'Enter an address like 192.168.1.3');
      return;
    }
    final name = _name.text.trim();
    final base = widget.initial ??
        Tv(id: 'ip:$ip', name: name.isEmpty ? 'TV' : name, ip: ip);
    Navigator.pop(
      context,
      base.copyWith(
        name: name.isEmpty ? base.name : name,
        ip: ip,
        castPort: _port(_cast, 8009),
        dialPort: _port(_dial, 8008),
        adbPort: _port(_adb, 5555),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(widget.initial == null ? 'Enter TV address' : 'Edit TV'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('tv-ip'),
              controller: _ip,
              autofocus: widget.initial == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'IP address',
                hintText: '192.168.1.3',
                prefixIcon: const Icon(Icons.router_outlined),
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Living Room TV',
                prefixIcon: Icon(Icons.tv_outlined),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _advanced = !_advanced),
                icon: Icon(
                  _advanced
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: const Text('Ports'),
              ),
            ),
            if (_advanced)
              Row(
                children: [
                  for (final (label, c) in [
                    ('Cast', _cast),
                    ('DIAL', _dial),
                    ('ADB', _adb),
                  ]) ...[
                    if (label != 'Cast') const SizedBox(width: Gap.sm),
                    Expanded(
                      child: TextField(
                        controller: c,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        decoration: InputDecoration(labelText: label),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

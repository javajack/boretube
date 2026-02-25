import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/tv_config.dart';
import '../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends ConsumerState<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _nameController;
  late TextEditingController _dialPortController;
  late TextEditingController _castPortController;
  bool _scanning = false;
  String? _scanResult;

  @override
  void initState() {
    super.initState();
    final config = ref.read(tvConfigProvider);
    _ipController = TextEditingController(text: config.ip);
    _nameController = TextEditingController(text: config.name);
    _dialPortController = TextEditingController(
      text: config.dialPort.toString(),
    );
    _castPortController = TextEditingController(
      text: config.castPort.toString(),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _nameController.dispose();
    _dialPortController.dispose();
    _castPortController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = TvConfig(
      ip: _ipController.text.trim(),
      name: _nameController.text.trim(),
      dialPort:
          int.tryParse(_dialPortController.text) ?? 8008,
      castPort:
          int.tryParse(_castPortController.text) ?? 8009,
    );
    await ref.read(tvConfigProvider.notifier).update(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      context.go('/');
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanResult = null;
    });
    try {
      final tvService = ref.read(tvServiceProvider);
      final name = await tvService.getDeviceName();
      if (name != null) {
        _nameController.text = name;
        setState(() => _scanResult = 'Found: $name');
      } else {
        setState(
          () => _scanResult = 'No device found at this IP',
        );
      }
    } catch (_) {
      setState(() => _scanResult = 'Scan failed');
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirstLaunch =
        !ref.read(tvConfigProvider.notifier).isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TV Settings'),
        automaticallyImplyLeading: !isFirstLaunch,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstLaunch) ...[
              const Text(
                'Welcome to Boretube',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your Sony BRAVIA TV IP address '
                'to get started.',
                style: TextStyle(color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'TV IP Address',
                hintText: '192.168.1.3',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'TV Name (optional)',
                hintText: 'Sony BRAVIA',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tv),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dialPortController,
                    decoration: const InputDecoration(
                      labelText: 'DIAL Port',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _castPortController,
                    decoration: const InputDecoration(
                      labelText: 'Cast Port',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _scanning
                      ? 'Scanning...'
                      : 'Scan / Verify Connection',
                ),
              ),
            ),
            if (_scanResult != null) ...[
              const SizedBox(height: 8),
              Text(
                _scanResult!,
                style: TextStyle(
                  color: _scanResult!.startsWith('Found')
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

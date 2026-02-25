import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/log_entry.dart';
import '../models/tv_status.dart';
import '../providers/providers.dart';

/// Lock mode — mutually exclusive.
enum _LockMode { none, apps, volume }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _LockMode _mode = _LockMode.none;
  final _intervalCtrl =
      TextEditingController(text: '10');
  final _maxVolCtrl =
      TextEditingController(text: '15');
  final _durationCtrl =
      TextEditingController(text: '60');

  final List<LogEntry> _feedEntries = [];
  int _remaining = 0;
  bool _lockActive = false;

  StreamSubscription<LogEntry>? _logSub;
  StreamSubscription<int>? _remainingSub;
  StreamSubscription<bool>? _activeSub;

  @override
  void initState() {
    super.initState();
    final ls = ref.read(lockServiceProvider);
    _lockActive = ls.isActive;
    _remaining = ls.lastRemaining;
    _feedEntries.addAll(ls.log);

    _logSub = ls.logStream.listen((entry) {
      if (mounted) {
        setState(() => _feedEntries.add(entry));
      }
    });
    _remainingSub = ls.remainingStream.listen((r) {
      if (mounted) setState(() => _remaining = r);
    });
    _activeSub = ls.activeStream.listen((active) {
      if (mounted) {
        setState(() => _lockActive = active);
      }
    });
  }

  @override
  void dispose() {
    _intervalCtrl.dispose();
    _maxVolCtrl.dispose();
    _durationCtrl.dispose();
    _logSub?.cancel();
    _remainingSub?.cancel();
    _activeSub?.cancel();
    super.dispose();
  }

  Future<void> _startLock() async {
    if (_mode == _LockMode.none) return;

    final config = ref.read(tvConfigProvider);
    final whitelist = ref.read(whitelistProvider);
    final ls = ref.read(lockServiceProvider);

    final interval =
        (int.tryParse(_intervalCtrl.text) ?? 10)
            .clamp(5, 300);
    final maxVol =
        (int.tryParse(_maxVolCtrl.text) ?? 15)
            .clamp(1, 100);
    final duration =
        (int.tryParse(_durationCtrl.text) ?? 60)
            .clamp(1, 1440);

    setState(() => _feedEntries.clear());

    await ls.start(
      host: config.ip,
      castPort: config.castPort,
      dialPort: config.dialPort,
      lockApps: _mode == _LockMode.apps,
      lockVolume: _mode == _LockMode.volume,
      maxVolume: maxVol,
      intervalSeconds: interval,
      durationMinutes: duration,
      whitelist: whitelist,
    );
  }

  Future<void> _stopLock() async {
    await ref.read(lockServiceProvider).stop();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(tvStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boretube'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status line ──
          _buildStatusLine(statusAsync),

          // ── Controls ──
          _buildControls(),

          // ── START / STOP ──
          _buildActionButton(),

          // ── Divider with countdown ──
          _buildDivider(),

          // ── Live feed ──
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  // ── Status line ──

  Widget _buildStatusLine(
    AsyncValue<TvStatus> statusAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: statusAsync.when(
        loading: () => _statusRow(
          false,
          'Connecting...',
          0,
          false,
        ),
        error: (_, __) => _statusRow(
          false,
          'TV offline',
          0,
          false,
        ),
        data: (s) => _statusRow(
          true,
          s.isIdle ? 'Home screen' : s.appName,
          s.volume,
          s.muted,
        ),
      ),
    );
  }

  Widget _statusRow(
    bool ok,
    String app,
    int vol,
    bool muted,
  ) {
    final color = ok ? Colors.green : Colors.red;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ok ? 'Connected' : 'Offline',
          style: TextStyle(color: color, fontSize: 13),
        ),
        const Spacer(),
        Text(
          app,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$vol%',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
        ),
        if (muted) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.volume_off,
            size: 16,
            color: Colors.red.shade400,
          ),
        ],
      ],
    );
  }

  // ── Controls card ──

  Widget _buildControls() {
    final disabled = _lockActive;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── No Lock ──
            _modeRadio(
              mode: _LockMode.none,
              icon: Icons.lock_open,
              label: 'No Lock',
              subtitle: 'TV is unrestricted',
              disabled: disabled,
            ),

            const Divider(height: 16),

            // ── Lock Apps ──
            _modeRadio(
              mode: _LockMode.apps,
              icon: Icons.block,
              label: 'Lock Apps',
              subtitle:
                  'Only whitelisted apps allowed',
              disabled: disabled,
            ),

            // Lock Apps options (visible when
            // selected, even if lock is running)
            if (_mode == _LockMode.apps) ...[
              const SizedBox(height: 8),
              _lockAppsOptions(disabled),
            ],

            const Divider(height: 16),

            // ── Lock Volume ──
            _modeRadio(
              mode: _LockMode.volume,
              icon: Icons.volume_down,
              label: 'Lock Volume',
              subtitle: 'Cap max volume',
              disabled: disabled,
            ),

            // Lock Volume options
            if (_mode == _LockMode.volume) ...[
              const SizedBox(height: 8),
              _lockVolumeOptions(disabled),
            ],

            // ── Duration (for both lock modes) ──
            if (_mode != _LockMode.none) ...[
              const Divider(height: 16),
              _durationRow(disabled),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeRadio({
    required _LockMode mode,
    required IconData icon,
    required String label,
    required String subtitle,
    required bool disabled,
  }) {
    final selected = _mode == mode;
    return InkWell(
      onTap: disabled
          ? null
          : () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Radio<_LockMode>(
                value: mode,
                groupValue: _mode,
                onChanged: disabled
                    ? null
                    : (v) => setState(
                          () => _mode =
                              v ?? _LockMode.none,
                        ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              icon,
              size: 20,
              color: selected
                  ? Colors.white
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: disabled
                          ? Colors.grey.shade600
                          : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockAppsOptions(bool disabled) {
    return Padding(
      padding: const EdgeInsets.only(left: 44),
      child: Row(
        children: [
          Text(
            'Check every',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 8),
          _numInput(_intervalCtrl, 48, disabled),
          Text(
            ' sec',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () =>
                context.push('/whitelist'),
            icon: const Icon(Icons.list, size: 18),
            label: const Text('Whitelist'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              textStyle:
                  const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockVolumeOptions(bool disabled) {
    final dim = TextStyle(
      fontSize: 14,
      color: Colors.grey.shade400,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 44),
      child: Column(
        children: [
          Row(
            children: [
              Text('Max volume', style: dim),
              const SizedBox(width: 8),
              _numInput(_maxVolCtrl, 48, disabled),
              Text(' %', style: dim),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Check every', style: dim),
              const SizedBox(width: 8),
              _numInput(
                _intervalCtrl,
                48,
                disabled,
              ),
              Text(' sec', style: dim),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durationRow(bool disabled) {
    return Padding(
      padding: const EdgeInsets.only(left: 44),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Text(
            'Duration',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 8),
          _numInput(_durationCtrl, 56, disabled),
          Text(
            ' min',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numInput(
    TextEditingController ctrl,
    double width,
    bool disabled,
  ) {
    return SizedBox(
      width: width,
      height: 32,
      child: TextField(
        controller: ctrl,
        enabled: !disabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          filled: true,
          fillColor: Colors.white
              .withValues(alpha: 0.05),
        ),
      ),
    );
  }

  // ── START / STOP button ──

  Widget _buildActionButton() {
    final isNone = _mode == _LockMode.none;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _lockActive
              ? _stopLock
              : (isNone ? null : _startLock),
          icon: Icon(
            _lockActive ? Icons.stop : Icons.lock,
          ),
          label: Text(
            _lockActive ? 'STOP LOCK' : 'START LOCK',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _lockActive
                ? Colors.green.shade700
                : Colors.red.shade700,
            disabledBackgroundColor:
                Colors.grey.shade800,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  // ── Divider with countdown ──

  Widget _buildDivider() {
    final remText = _lockActive && _remaining > 0
        ? _formatRemaining(_remaining)
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: Text(
              remText.isNotEmpty
                  ? 'Live Feed \u2014 $remText left'
                  : 'Live Feed',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  // ── Live feed ──

  Widget _buildFeed() {
    if (_feedEntries.isEmpty) {
      return Center(
        child: Text(
          _lockActive
              ? 'Waiting for first check...'
              : 'Start a lock to see activity',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      itemCount: _feedEntries.length,
      itemBuilder: (context, index) {
        final entry = _feedEntries[
            _feedEntries.length - 1 - index];
        final h = entry.timestamp.hour
            .toString()
            .padLeft(2, '0');
        final m = entry.timestamp.minute
            .toString()
            .padLeft(2, '0');
        final s = entry.timestamp.second
            .toString()
            .padLeft(2, '0');

        Color textColor;
        if (entry.isStopped) {
          textColor = Colors.red;
        } else if (entry.message.contains(
          'whitelisted',
        )) {
          textColor = Colors.green;
        } else {
          textColor = Colors.grey.shade500;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            '[$h:$m:$s] ${entry.message}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: textColor,
            ),
          ),
        );
      },
    );
  }

  String _formatRemaining(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }
}

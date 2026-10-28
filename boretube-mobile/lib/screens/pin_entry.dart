import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/pin_store.dart';
import '../ui/tokens.dart';

/// Result of submitting a PIN: null = accepted, otherwise the error text.
typedef PinSubmit = Future<String?> Function(String pin);

/// Dots + large keypad + shake on error. Used for unlock, first-run
/// setup and PIN changes.
class PinEntry extends StatefulWidget {
  final String title;
  final String? subtitle;
  final PinSubmit onSubmit;

  /// Extra button under the keypad (e.g. "Use fingerprint").
  final Widget? footer;

  /// Error to show (with a shake) when the entry first appears.
  final String? initialError;

  const PinEntry({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.footer,
    this.initialError,
  });

  @override
  State<PinEntry> createState() => PinEntryState();
}

class PinEntryState extends State<PinEntry>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
    if (_error != null) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Clears the digits (e.g. when the parent screen changes step).
  void reset() => setState(() {
        _pin = '';
        _error = null;
      });

  void _digit(String d) {
    if (_busy || _pin.length >= PinStore.maxLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_pin.length < PinStore.minLength) {
      _fail('Use ${PinStore.minLength}–${PinStore.maxLength} digits');
      return;
    }
    setState(() => _busy = true);
    final err = await widget.onSubmit(_pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) _fail(err);
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = message;
      _pin = '';
    });
    _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final slots = math.max(PinStore.minLength, _pin.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: Gap.sm),
          Text(
            widget.subtitle!,
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: Gap.xl),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * 14 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            key: const Key('pin-dots'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < slots; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? (_error != null ? scheme.error : scheme.primary)
                        : Colors.transparent,
                    border: Border.all(
                      color: i < _pin.length
                          ? Colors.transparent
                          : scheme.outline,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        SizedBox(
          height: 22,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              _error ?? '',
              key: ValueKey(_error),
              style: text.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        _Keypad(
          onDigit: _digit,
          onBack: _back,
          onSubmit: _submit,
          busy: _busy,
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: Gap.lg),
          widget.footer!,
        ],
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool busy;

  const _Keypad({
    required this.onDigit,
    required this.onBack,
    required this.onSubmit,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String d) => _Key(
          label: d,
          semantics: d,
          onTap: () => onDigit(d),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Key(
              icon: Icons.backspace_outlined,
              semantics: 'Delete',
              onTap: onBack,
              subtle: true,
            ),
            key('0'),
            _Key(
              icon: busy ? null : Icons.arrow_forward_rounded,
              semantics: 'Enter',
              onTap: onSubmit,
              filled: true,
              child: busy
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: scheme.onPrimary,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String semantics;
  final VoidCallback onTap;
  final bool filled;
  final bool subtle;
  final Widget? child;

  const _Key({
    this.label,
    this.icon,
    required this.semantics,
    required this.onTap,
    this.filled = false,
    this.subtle = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = filled
        ? scheme.primary
        : subtle
            ? Colors.transparent
            : scheme.surfaceContainer;
    final fg = filled ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.all(Gap.sm),
      child: Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            key: Key('pin-key-$semantics'),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: child ??
                    (label != null
                        ? Text(
                            label!,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: fg,
                            ),
                          )
                        : Icon(icon, color: fg, size: 26)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-step "choose, then confirm" PIN flow.
class PinSetup extends StatefulWidget {
  final Future<void> Function(String pin) onDone;
  final String title;

  const PinSetup({
    super.key,
    required this.onDone,
    this.title = 'Choose a parent PIN',
  });

  @override
  State<PinSetup> createState() => _PinSetupState();
}

class _PinSetupState extends State<PinSetup> {
  String? _first;
  String? _mismatch;

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: PinEntry(
        key: ValueKey('$confirming$_mismatch'),
        initialError: confirming ? null : _mismatch,
        title: confirming ? 'Enter it again' : widget.title,
        subtitle: confirming
            ? 'Just to be sure.'
            : '4–6 digits. Kids shouldn\'t know it.',
        onSubmit: (pin) async {
          if (!confirming) {
            setState(() {
              _first = pin;
              _mismatch = null;
            });
            return null;
          }
          if (pin != _first) {
            setState(() {
              _first = null;
              _mismatch = 'PINs didn\'t match. Start again.';
            });
            return null;
          }
          await widget.onDone(pin);
          return null;
        },
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/pin_store.dart';
import '../ui/components.dart';
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
    duration: Motion.sheet,
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
    final bt = context.bt;
    final slots = math.max(PinStore.minLength, _pin.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: Gap.f8),
          Text(
            widget.subtitle!,
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: Gap.f21),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            // Three damped swings, no bounce past rest.
            final t = Motion.enter.transform(_shake.value);
            final dx = math.sin(t * math.pi * 6) * Gap.f13 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            key: const Key('pin-dots'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < slots; i++)
                AnimatedContainer(
                  duration: Motion.of(context, Motion.flip),
                  curve: Motion.enter,
                  margin: const EdgeInsets.symmetric(horizontal: Gap.f13 / 2),
                  width: Gap.f13,
                  height: Gap.f13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? (_error != null ? bt.berryFill : bt.ink)
                        : Colors.transparent,
                    border: Border.all(
                      color: i < _pin.length
                          ? Colors.transparent
                          : bt.borderStrong,
                      width: Sizes.hairline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.f13),
        SizedBox(
          height: TypeSize.body * TypeSize.bodyLeading,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.flip),
            child: Text(
              _error ?? '',
              key: ValueKey(_error),
              style: text.bodyMedium?.copyWith(
                color: bt.berryFill,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.f21),
        _Keypad(
          onDigit: _digit,
          onBack: _back,
          onSubmit: _submit,
          busy: _busy,
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: Gap.f21),
          widget.footer!,
        ],
      ],
    );
  }
}

/// A 3 × 4 keypad on the φ grid: 89 keys, 13 apart.
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
    final bt = context.bt;
    Widget key(String d) => _Key(
          label: d,
          semantics: d,
          onTap: () => onDigit(d),
        );
    Widget row(List<Widget> keys) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) const SizedBox(width: Gap.f13),
              keys[i],
            ],
          ],
        );
    final rows = [
      for (final r in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        row([for (final d in r) key(d)]),
      row([
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
              ? SizedBox.square(
                  dimension: Sizes.iconControl,
                  child: CircularProgressIndicator(
                    strokeWidth: Sizes.focus,
                    color: bt.onInkFill,
                  ),
                )
              : null,
        ),
      ]),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Gap.f13),
          rows[i],
        ],
      ],
    );
  }
}

/// One key: a quiet tonal circle (no outline), ink for Enter.
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
    final bt = context.bt;
    final bg = filled
        ? bt.inkFill
        : subtle
            ? Colors.transparent
            : bt.wash;
    final fg = filled ? bt.onInkFill : bt.ink;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('pin-key-$semantics'),
            onTap: onTap,
            child: SizedBox.square(
              dimension: _keySize,
              child: Center(
                child: child ??
                    (label != null
                        ? Text(
                            label!,
                            style: Fonts.bricolage(
                              TypeSize.title,
                              weight: FontWeight.w700,
                              color: fg,
                              height: TypeSize.tightLeading,
                              tabularFigures: true,
                            ),
                          )
                        : Icon(icon, color: fg, size: Sizes.iconControl)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// φ × a list row: 89 when the screen has room for three keys and two
/// gaps inside the gutters.
const _keySize = Sizes.band;

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
      duration: Motion.of(context, Motion.flip),
      child: PinEntry(
        key: ValueKey('$confirming$_mismatch'),
        initialError: confirming ? null : _mismatch,
        title: confirming ? 'Enter it again' : widget.title,
        subtitle: confirming
            ? 'Just to be sure.'
            : '4–6 digits. So only grown-ups can change the TV.',
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

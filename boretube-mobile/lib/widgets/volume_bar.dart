import 'package:flutter/material.dart';

class VolumeBar extends StatelessWidget {
  final int volume;
  final bool muted;

  const VolumeBar({
    super.key,
    required this.volume,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final filledBlocks = volume ~/ 10;
    final emptyBlocks = 10 - filledBlocks;
    final bar =
        '${'█' * filledBlocks}${'░' * emptyBlocks}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          bar,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            color: muted ? Colors.red : Colors.green,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$volume%',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
        if (muted) ...[
          const SizedBox(width: 6),
          Text(
            'MUTED',
            style: TextStyle(
              color: Colors.red.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

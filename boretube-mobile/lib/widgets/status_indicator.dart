import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool connected;

  const StatusIndicator({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? Colors.green : Colors.red,
            boxShadow: [
              BoxShadow(
                color: (connected ? Colors.green : Colors.red)
                    .withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          connected ? 'Connected' : 'Unreachable',
          style: TextStyle(
            color: connected ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

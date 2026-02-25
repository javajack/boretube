import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool large;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: large ? 72 : 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: large ? 28 : 22),
        label: Text(
          label,
          style: TextStyle(fontSize: large ? 18 : 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

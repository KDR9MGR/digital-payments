import 'package:flutter/material.dart';

class IconBoxButton extends StatelessWidget {
  const IconBoxButton({
    super.key,
    required this.icon,
    this.onPressed,
  });
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

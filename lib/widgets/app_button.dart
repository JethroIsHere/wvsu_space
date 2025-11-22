import 'package:flutter/material.dart';

// Small wrapper around `ElevatedButton` that applies the app's primary style which is
// dark blue or navy.
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  const AppButton(
      {super.key, required this.onPressed, required this.child, this.style});

  @override
  Widget build(BuildContext context) {
    final defaultStyle = ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );

    return ElevatedButton(
      onPressed: onPressed,
      style: style ?? defaultStyle,
      child: child,
    );
  }
}

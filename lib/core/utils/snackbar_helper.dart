import 'package:flutter/material.dart';

class SnackBarHelper {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    SnackBarAction? action,
    bool showCloseIcon = true,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        showCloseIcon: showCloseIcon,
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.only(left: 20, right: 1000, bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: action,
      ),
    );
  }
}

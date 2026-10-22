import 'package:flutter/material.dart';

/// Shows a short message that fades away on its own, replacing any message
/// still showing. One with an action, such as Undo, stays a little longer.
void showToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final action = actionLabel == null
      ? null
      : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {});
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      // Flutter keeps snackbars with an action until dismissed by default.
      persist: false,
      duration: Duration(seconds: action == null ? 3 : 5),
    ));
}

import 'package:flutter/material.dart';
import 'package:swoosh/core/utils/view_insets.dart';

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      margin: ViewInsets.snackBarMargin(context),
    ),
  );
}

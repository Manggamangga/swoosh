import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void pushAfterSheetDismiss(GoRouter router, String location) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    router.push(location);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/theme/app_theme.dart';
import 'package:swoosh/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.account_balance,
            title: 'No accounts yet',
            subtitle: 'Add your first account',
          ),
        ),
      ),
    );

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.text('Add your first account'), findsOneWidget);
  });
}

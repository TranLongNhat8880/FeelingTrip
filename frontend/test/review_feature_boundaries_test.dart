import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/auth/views/terms_screen.dart';

void main() {
  test('retired emergency UI and contact management files are absent', () {
    for (final path in [
      'lib/features/review/views/sos_screen.dart',
      'lib/features/review/views/sos_history_screen.dart',
      'lib/features/review/views/emergency_contacts_screen.dart',
      'lib/features/review/viewmodels/sos_viewmodel.dart',
      'lib/features/review/viewmodels/sos_history_viewmodel.dart',
      'lib/features/review/viewmodels/emergency_contacts_viewmodel.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: '$path must be removed');
    }
  });

  testWidgets('terms no longer advertise removed alert functionality', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const TermsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SOS'), findsNothing);
    expect(find.text('Lịch trình AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

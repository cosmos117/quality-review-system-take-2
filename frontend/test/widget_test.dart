import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quality_review/main.dart';
import 'package:quality_review/pages/login.dart';

void main() {
  testWidgets('shows the login page when no user is signed in', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}

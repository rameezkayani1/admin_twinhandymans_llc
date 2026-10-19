import 'package:admin_twinhandymans_llc/main.dart';
import 'package:admin_twinhandymans_llc/pages/login/login_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Twins Handyman Admin opens login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TwinsAdminApp());

    await tester.pumpAndSettle();

    // Verify that the login page is displayed.
    expect(find.byType(LoginPage), findsOneWidget);
  });
}

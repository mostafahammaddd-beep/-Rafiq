import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_app/main.dart';

void main() {
  testWidgets('welcome screen shows the app name', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RafiqApp()));

    expect(find.text('رَفِيق'), findsWidgets);
    expect(find.text('اختبار الواجهة'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:homework_ai/main.dart';

void main() {
  testWidgets('app starts on the main navigation shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HomeworkAI());
    await tester.pumpAndSettle();

    expect(find.text('Homework AI'), findsWidgets);
    expect(find.text('Scan Homework'), findsOneWidget);
    expect(find.text('Upload Image'), findsOneWidget);
  });
}

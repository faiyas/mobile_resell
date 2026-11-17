import 'package:flutter_test/flutter_test.dart';
import 'package:recell_1103/main.dart';

void main() {
  testWidgets('1103 RECELL smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RecellApp());
    expect(find.text('1103 RECELL'), findsOneWidget);
  });
}

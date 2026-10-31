import 'package:flutter_test/flutter_test.dart';
import 'package:mila/app.dart';

void main() {
  testWidgets('Mila app shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MilaApp());
    await tester.pumpAndSettle();

    expect(find.text('mila'), findsOneWidget);
    expect(find.text('Συνομιλία'), findsOneWidget);
  });
}

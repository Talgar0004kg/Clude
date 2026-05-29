import 'package:flutter_test/flutter_test.dart';

import 'package:kyrgyz_tili/main.dart';

void main() {
  testWidgets('Приложение запускается и показывает бренд «Кел-Кел»',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KelKelApp());
    await tester.pump();
    expect(find.text('Кел-Кел'), findsOneWidget);
  });
}

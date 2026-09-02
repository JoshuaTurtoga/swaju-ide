import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:swaju_ide/main.dart';

void main() {
  testWidgets('SwajuIdeApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SwajuIdeApp()),
    );

    // Verify the toolbar title appears.
    expect(find.text('Swaju IDE'), findsOneWidget);
  });
}

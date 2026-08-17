import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yopet/app.dart';

void main() {
  testWidgets('splash shows yopet branding', (tester) async {
    // Hermetic: YopetApp does not call Supabase.initialize (that's
    // only in main.dart, which the test does not run).
    await tester.pumpWidget(const ProviderScope(child: YopetApp()));
    expect(find.text('yopet'), findsOneWidget);
  });
}

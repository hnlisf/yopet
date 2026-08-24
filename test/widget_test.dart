import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yopet/splash_screen.dart';

void main() {
  testWidgets('splash shows yopet branding', (tester) async {
    // Pump the splash widget directly. Earlier F2 pumped `YopetApp`,
    // but the F3 router (with auth-state-based redirect) sends
    // signed-out users to /sign-in, so the app-level pump no longer
    // surfaces the splash for a unit test. The splash widget itself
    // is what we want to verify here.
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.text('yopet'), findsOneWidget);
  });
}

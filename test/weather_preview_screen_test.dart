import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/weather/weather_preview_screen.dart';

void main() {
  testWidgets('data-free weather preview switches the visible atmosphere label', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WeatherPreviewScreen()));

    expect(find.text('F11 · 天气氛围试阅'), findsOneWidget);
    expect(find.text('晴朗 · 24°'), findsOneWidget);

    final partlyCloudyChip = tester.widget<ChoiceChip>(
      find.byType(ChoiceChip).at(1),
    );
    partlyCloudyChip.onSelected!(true);
    await tester.pump();

    expect(find.text('少云 · 24°'), findsOneWidget);
  });
}

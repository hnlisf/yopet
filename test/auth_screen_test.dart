import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/auth/auth_screen.dart';

void main() {
  testWidgets('welcomes a returning player and offers a clear entry action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    expect(find.text('yopet'), findsOneWidget);
    expect(find.text('回到你的\n安静水域'), findsOneWidget);
    expect(find.text('进入鱼缸'), findsOneWidget);
    expect(find.byTooltip('显示密码'), findsOneWidget);
  });

  testWidgets('register mode reveals confirmation and a dedicated CTA', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();

    expect(find.text('确认密码'), findsOneWidget);
    expect(find.text('创建我的鱼缸'), findsOneWidget);
  });

  testWidgets('pending confirmation keeps the email and offers resend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PendingEmailConfirmationNotice(
          email: 'fish@example.com',
          busy: false,
          onResend: () {},
        ),
      ),
    );

    expect(find.text('请先确认 fish@example.com'), findsOneWidget);
    expect(find.text('重新发送确认邮件'), findsOneWidget);
  });
}

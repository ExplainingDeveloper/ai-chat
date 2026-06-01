import 'package:flutter/material.dart';
import 'package:flutter_ai_chat/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the chat list screen shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('채팅 목록'), findsOneWidget);
    expect(find.text('프로젝트 아이디어 정리'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}

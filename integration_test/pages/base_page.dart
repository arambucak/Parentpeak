import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class BasePage {
  final WidgetTester tester;
  BasePage(this.tester);

  Future<void> tapByKey(String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> enterText(String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pumpAndSettle();
  }

  bool isVisible(String key) {
    return find.byKey(ValueKey(key)).evaluate().isNotEmpty;
  }

  Future<void> waitForSettle() async {
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

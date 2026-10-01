import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/models/ai_memory.dart';
import 'package:parentpeak/ui/ai_memory_settings_screen.dart';

class _FakeMemoryService extends AiMemoryService {
  _FakeMemoryService()
      : super(apiClient: null);

  bool enabled = true;
  final child = const AiChildProfile(
    id: 'child-1',
    userId: 'user-1',
    name: 'Lina',
    memoryItems: [
      AiMemoryItem(
        id: 'memory-1',
        childId: 'child-1',
        category: 'medical_clarification',
        key: 'Urologisch abgeklärt',
        value: 'Ohne auffälligen Befund',
        status: 'confirmed',
      ),
    ],
  );

  @override
  Future<AiMemorySettings> getSettings() async =>
      AiMemorySettings(enabled: enabled);

  @override
  Future<AiMemorySettings> setEnabled(bool value) async {
    enabled = value;
    return AiMemorySettings(enabled: value);
  }

  @override
  Future<List<AiChildProfile>> getChildren() async => [child];

  @override
  Future<List<AiMemoryItem>> getMemory(String childId) async => child.memoryItems;
}

void main() {
  testWidgets('shows opt-in, transparency text, and child memory', (tester) async {
    final service = _FakeMemoryService();
    await tester.pumpWidget(
      MaterialApp(home: AiMemorySettingsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('KI-Gedächtnis aktivieren'), findsOneWidget);
    expect(
      find.text(
        'Diese Daten werden ausschließlich genutzt, um die KI-Beratung für deine Familie persönlicher zu machen.',
      ),
      findsOneWidget,
    );
    expect(find.text('Lina'), findsOneWidget);
  });

  testWidgets('toggles the memory opt-in', (tester) async {
    final service = _FakeMemoryService();
    await tester.pumpWidget(
      MaterialApp(home: AiMemorySettingsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(service.enabled, isFalse);
  });
}

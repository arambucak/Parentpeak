import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

class _TranslationKeys extends RecursiveAstVisitor<void> {
  _TranslationKeys(this.catalogKeys);

  final Set<String> catalogKeys;
  final keys = <String>{};

  void _readKey(Expression expression) {
    if (expression is StringLiteral && expression.stringValue != null) {
      keys.add(expression.stringValue!);
    } else if (expression is ConditionalExpression) {
      _readKey(expression.thenExpression);
      _readKey(expression.elseExpression);
    } else if (expression is SwitchExpression) {
      for (final branch in expression.cases) {
        _readKey(branch.expression);
      }
    } else if (expression is BinaryExpression &&
        expression.operator.lexeme == '??') {
      _readKey(expression.rightOperand);
    }
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // Also cover keys stored in maps, records, fields and named arguments.
    if (catalogKeys.contains(node.value)) keys.add(node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final arguments = node.argumentList.arguments;
    final index = name == 'getString' ? 1 : 0;
    if (const {'tr', 't', 'tFormat', '_t', '_tr', 'getString'}.contains(name) &&
        arguments.length > index) {
      _readKey(arguments[index].argumentExpression);
    }
    super.visitMethodInvocation(node);
  }
}

Map<String, Set<String>> _legacyKeys() {
  final unit = parseString(
    content: File('lib/l10n/app_localizations.dart').readAsStringSync(),
  ).unit;
  final result = <String, Set<String>>{};
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    for (final field in declaration.body.members.whereType<FieldDeclaration>()) {
    for (final variable in field.fields.variables) {
      if (variable.name.lexeme != '_localizedValues') continue;
      final root = variable.initializer as SetOrMapLiteral;
      for (final locale in root.elements.whereType<MapLiteralEntry>()) {
        final code = (locale.key as StringLiteral).stringValue!;
        result[code] = {
          for (final entry in (locale.value as SetOrMapLiteral).elements.whereType<MapLiteralEntry>())
            (entry.key as StringLiteral).stringValue!,
        };
      }
    }
    }
  }
  return result;
}

void main() {
  test('key scanner covers branches and keys passed through data', () {
    final visitor = _TranslationKeys({'stored_key'});
    parseString(content: '''
void example() {
  final labels = {'label': 'stored_key'};
  context.tr(ready ? 'ready_key' : 'waiting_key');
  context.tr(switch (mode) { true => 'on_key', _ => 'off_key' });
  l10n.t(labels[mode] ?? 'fallback_key');
  context.tr('missing_key', values: {'name': 'not_a_key'});
  AppStringsManager.getString(language, 'source_key');
}
''').unit.accept(visitor);
    expect(visitor.keys, {
      'stored_key',
      'ready_key',
      'waiting_key',
      'on_key',
      'off_key',
      'fallback_key',
      'missing_key',
      'source_key',
    });
  });

  test('translation calls and catalog key references in lib have de and en sources', () {
    final keys = <String>{};
    final legacy = _legacyKeys();
    expect(legacy['de'], isNotEmpty);
    expect(legacy['en'], isNotEmpty);
    final catalogKeys = {
      for (final catalog in AppStringsManager.allStrings.values) ...catalog.keys,
      for (final catalog in legacy.values) ...catalog,
    };
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.contains('${Platform.pathSeparator}l10n${Platform.pathSeparator}')) {
        continue;
      }
      final visitor = _TranslationKeys(catalogKeys);
      parseString(content: file.readAsStringSync(), path: file.path).unit.accept(visitor);
      keys.addAll(visitor.keys);
    }
    expect(keys.length, greaterThan(500));
    for (final language in ['de', 'en']) {
      final primary = AppStringsManager.allStrings[language]!.keys;
      final available = {
        ...primary,
        for (final key in primary)
          key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match[1]!.toUpperCase()),
        ...legacy[language]!,
      };
      final missing = keys.difference(available).toList()..sort();
      expect(missing, isEmpty, reason: '$language source keys missing: $missing');
    }
  });
}

import 'package:parentpeak/widgets/ala_rengin_flag_painter.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:flutter/material.dart';

class SimpleLanguageTest extends StatefulWidget {
  const SimpleLanguageTest({super.key});

  @override
  State<SimpleLanguageTest> createState() => _SimpleLanguageTestState();
}

class _SimpleLanguageTestState extends State<SimpleLanguageTest> {
  String _selectedLanguage = 'de';

  final List<AppLanguage> languages = AppLanguages.supported;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language Test')),
      body: Column(
        children: [
          Text('Total Languages: ${languages.length}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text('Selected: $_selectedLanguage'),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = lang.code == _selectedLanguage;
                return ListTile(
                  leading: (lang.code == 'ku' || lang.code == 'ckb')
                      ? const AlaRenginFlag(width: 32, height: 20)
                      : Text(lang.flag, style: const TextStyle(fontSize: 28)),
                  title: Text(lang.nativeName),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  selected: isSelected,
                  onTap: () {
                    setState(() => _selectedLanguage = lang.code);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

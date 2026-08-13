import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackupQrScanScreen extends StatefulWidget {
  const BackupQrScanScreen({super.key});

  @override
  State<BackupQrScanScreen> createState() => _BackupQrScanScreenState();
}

class _BackupQrScanScreenState extends State<BackupQrScanScreen> {
  bool _hasResult = false;
  Timer? _sessionTimeout;
  static const Duration _chunkTimeout = Duration(seconds: 30);
  String? _chunkId;
  int? _expectedTotal;
  int _nextExpectedIndex = 1;
  String? _statusMessage;
  final Map<int, String> _chunks = {};
  final TextEditingController _backupController = TextEditingController();

  @override
  void dispose() {
    _sessionTimeout?.cancel();
    _backupController.dispose();
    super.dispose();
  }

  void _handleRaw(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['_ppChunk'] == true) {
        _handleChunk(decoded);
        return;
      }
    } catch (e) {
      debugPrint('BackupQrScanScreen._handleRaw(): treating payload as plain backup JSON: $e');
      // Fallback: plain backup JSON in one QR.
    }

    _hasResult = true;
    Navigator.pop(context, raw);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _setStatus('Zwischenablage ist leer.');
      return;
    }
    setState(() {
      _backupController.text = text;
      _statusMessage = null;
    });
  }

  void _importBackup() {
    final raw = _backupController.text.trim();
    if (raw.isEmpty) {
      _setStatus('Bitte Backup-JSON einfuegen.');
      return;
    }
    _handleRaw(raw);
  }

  void _handleChunk(Map<String, dynamic> chunk) {
    final chunkId = chunk['chunkId'] as String?;
    final index = (chunk['index'] as num?)?.toInt();
    final total = (chunk['total'] as num?)?.toInt();
    final payload = chunk['payload'] as String?;
    if (chunkId == null || index == null || total == null || payload == null) {
      _setStatus('Ungueltiger QR-Teil erkannt.');
      return;
    }

    if (total <= 0 || total > 200) {
      _setStatus('Ungueltige Gesamtanzahl der QR-Teile.');
      return;
    }
    if (index <= 0 || index > total) {
      _setStatus('Ungueltiger Teilindex im QR-Code.');
      return;
    }

    if (_chunkId == null) {
      _chunkId = chunkId;
      _expectedTotal = total;
      _nextExpectedIndex = 1;
    }

    if (_chunkId != chunkId || _expectedTotal != total) {
      _setStatus('Anderer Backup-Satz erkannt. Bitte "Neu starten" druecken.');
      return;
    }

    _startOrRefreshTimeout();

    if (_chunks.containsKey(index)) {
      _setStatus('Teil $index wurde bereits gescannt.');
      return;
    }

    if (index != _nextExpectedIndex) {
      _setStatus('Falsche Reihenfolge. Bitte Teil $_nextExpectedIndex scannen.');
      return;
    }

    setState(() {
      _chunks[index] = payload;
      _nextExpectedIndex += 1;
      _statusMessage = null;
    });
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();

    if (_chunks.length == _expectedTotal) {
      _sessionTimeout?.cancel();
      final buffer = StringBuffer();
      for (var i = 1; i <= _expectedTotal!; i++) {
        final part = _chunks[i];
        if (part == null) {
          _setStatus('Ein Teil fehlt. Bitte erneut scannen.');
          return;
        }
        buffer.write(part);
      }
      _hasResult = true;
      HapticFeedback.heavyImpact();
      Navigator.pop(context, buffer.toString());
    }
  }

  void _resetChunks() {
    _sessionTimeout?.cancel();
    setState(() {
      _chunkId = null;
      _expectedTotal = null;
      _nextExpectedIndex = 1;
      _statusMessage = null;
      _chunks.clear();
    });
  }

  void _startOrRefreshTimeout() {
    _sessionTimeout?.cancel();
    _sessionTimeout = Timer(_chunkTimeout, () {
      if (!mounted || _hasResult) {
        return;
      }
      setState(() {
        _chunkId = null;
        _expectedTotal = null;
        _nextExpectedIndex = 1;
        _chunks.clear();
        _statusMessage =
            'Zeitüberschreitung: Scan wurde zur Sicherheit zurückgesetzt.';
      });
    });
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup QR scannen')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Der Backup-Scanner ist auf diesem iOS-Simulator nicht verfügbar.\n\n'
                    'Fuege den Backup-Text hier ein, um die Wiederherstellung fortzusetzen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _backupController,
                minLines: 8,
                maxLines: 14,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Backup-JSON oder QR-Inhalt',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Einfuegen'),
                  ),
                  FilledButton.icon(
                    onPressed: _importBackup,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import starten'),
                  ),
                  TextButton(
                    onPressed: _resetChunks,
                    child: const Text('Zurücksetzen'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_expectedTotal != null)
                Text(
                  'QR-Teile erkannt: ${_chunks.length}/$_expectedTotal · als naechstes: $_nextExpectedIndex',
                  textAlign: TextAlign.center,
                ),
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

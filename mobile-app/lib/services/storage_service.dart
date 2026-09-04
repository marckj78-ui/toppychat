import 'dart:io';

import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/chat_message.dart';

/// Salva e legge le conversazioni come file di testo semplice in
/// Download/ToppyChat/<numero>.txt sul telefono. Ogni riga e' un messaggio,
/// nel formato:
///
///   [2026-09-04 10:15:32] Io: ciao come va
///   [2026-09-04 10:16:01] +391234567890: bene grazie
///
/// Nessun database, nessun server: e' tutto leggibile con un qualsiasi
/// editor di testo o file manager, direttamente nella cartella Download
/// del telefono.
class StorageService {
  static final DateFormat _tsFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final RegExp _lineRegex = RegExp(r'^\[(.+?)\] (.+?): (.*)$');

  /// Chiede i permessi necessari per scrivere nella cartella Download
  /// pubblica. Su Android 11+ serve il permesso "Gestione di tutti i file",
  /// che l'utente concede una volta dalle impostazioni di sistema.
  Future<bool> ensurePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    // Fallback per versioni di Android piu' vecchie (<= 10) dove basta
    // il permesso classico di scrittura.
    final legacyStatus = await Permission.storage.request();
    return legacyStatus.isGranted;
  }

  Directory _appDownloadDir() {
    return Directory('/storage/emulated/0/Download/ToppyChat');
  }

  String _fileNameFor(String number) {
    final safe = number.replaceAll(RegExp(r'[^0-9+]'), '_');
    return '$safe.txt';
  }

  File _fileFor(String number) {
    final dir = _appDownloadDir();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/${_fileNameFor(number)}');
  }

  String _encodeLine(ChatMessage message) {
    final ts = _tsFormat.format(message.timestamp);
    final label = message.mine ? 'Io' : message.from;
    final safeText = message.text.replaceAll('\n', ' ');
    return '[$ts] $label: $safeText';
  }

  ChatMessage? _decodeLine(
    String line, {
    required String contactNumber,
    required String ownNumber,
  }) {
    final match = _lineRegex.firstMatch(line);
    if (match == null) return null;
    final tsStr = match.group(1)!;
    final label = match.group(2)!;
    final text = match.group(3)!;
    final mine = label == 'Io';
    DateTime ts;
    try {
      ts = _tsFormat.parse(tsStr);
    } catch (_) {
      ts = DateTime.now();
    }
    return ChatMessage(
      id: '',
      from: mine ? ownNumber : contactNumber,
      to: mine ? contactNumber : ownNumber,
      text: text,
      timestamp: ts,
      mine: mine,
    );
  }

  /// Aggiunge un messaggio in fondo al file della conversazione con
  /// [contactNumber].
  Future<void> appendMessage(String contactNumber, ChatMessage message) async {
    final granted = await ensurePermission();
    if (!granted) {
      throw StateError(
        'Permesso di scrittura su Download non concesso. '
        'Vai nelle impostazioni del telefono e abilita "Tutti i file" per ToppyChat.',
      );
    }
    final file = _fileFor(contactNumber);
    await file.writeAsString(
      '${_encodeLine(message)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Legge tutta la conversazione salvata con [contactNumber].
  Future<List<ChatMessage>> readConversation(
    String contactNumber, {
    required String ownNumber,
  }) async {
    final granted = await ensurePermission();
    if (!granted) return [];
    final file = _fileFor(contactNumber);
    if (!file.existsSync()) return [];
    final content = await file.readAsString();
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
    final messages = <ChatMessage>[];
    for (final line in lines) {
      final msg = _decodeLine(
        line,
        contactNumber: contactNumber,
        ownNumber: ownNumber,
      );
      if (msg != null) messages.add(msg);
    }
    return messages;
  }

  /// Ultima riga della conversazione, utile per l'anteprima nella lista
  /// contatti. Ritorna null se non c'e' ancora nessuna conversazione.
  Future<String?> lastLinePreview(String contactNumber) async {
    final file = _fileFor(contactNumber);
    if (!file.existsSync()) return null;
    final content = await file.readAsString();
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return null;
    return lines.last;
  }
}

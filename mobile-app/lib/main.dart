import 'package:flutter/material.dart';

import 'services/chat_controller.dart';
import 'services/relay_service.dart';
import 'services/settings_service.dart';
import 'screens/contacts_screen.dart';
import 'screens/setup_screen.dart';

void main() {
  runApp(const ToppyChatApp());
}

class ToppyChatApp extends StatelessWidget {
  const ToppyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToppyChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const _StartupGate(),
    );
  }
}

/// Decide se mostrare il setup iniziale o andare direttamente alla lista
/// contatti, in base a cosa e' gia' salvato sul telefono.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _settings = SettingsService();
  bool _checked = false;
  bool _setupComplete = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final complete = await _settings.isSetupComplete();
    if (complete) {
      final url = await _settings.getRelayUrl() ?? '';
      final token = await _settings.getRelayToken() ?? '';
      final number = await _settings.getOwnNumber() ?? '';
      RelayService.instance.connect(url: url, token: token, ownNumber: number);
      ChatController.instance.startListening();
    }
    if (!mounted) return;
    setState(() {
      _setupComplete = complete;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _setupComplete ? const ContactsScreen() : const SetupScreen();
  }
}

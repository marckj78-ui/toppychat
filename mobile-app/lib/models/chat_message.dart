/// Un singolo messaggio di una conversazione.
class ChatMessage {
  final String id;
  final String from; // numero mittente
  final String to; // numero destinatario
  final String text;
  final DateTime timestamp;
  final bool mine; // true se inviato da questo dispositivo

  const ChatMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.text,
    required this.timestamp,
    required this.mine,
  });
}

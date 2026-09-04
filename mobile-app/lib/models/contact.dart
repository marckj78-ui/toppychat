
/// Un numero di telefono autorizzato a chattare con te.
class Contact {
  final String number; // es. +391234567890
  final String name; // nome mostrato in app

  const Contact({required this.number, required this.name});

  Map<String, dynamic> toJson() => {'number': number, 'name': name};

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        number: json['number'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

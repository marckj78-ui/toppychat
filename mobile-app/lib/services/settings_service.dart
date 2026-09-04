import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';

/// Gestisce le impostazioni salvate localmente sul telefono:
/// numero proprio, indirizzo del relay, token e whitelist dei contatti.
///
/// Non contiene nessun messaggio: quelli vivono solo nei file di testo
/// (vedi StorageService).
class SettingsService {
  static const _kOwnNumber = 'own_number';
  static const _kRelayUrl = 'relay_url';
  static const _kRelayToken = 'relay_token';
  static const _kContacts = 'contacts';

  Future<String?> getOwnNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kOwnNumber);
  }

  Future<void> setOwnNumber(String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOwnNumber, number);
  }

  Future<String?> getRelayUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRelayUrl);
  }

  Future<void> setRelayUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRelayUrl, url);
  }

  Future<String?> getRelayToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRelayToken);
  }

  Future<void> setRelayToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRelayToken, token);
  }

  Future<bool> isSetupComplete() async {
    final number = await getOwnNumber();
    final url = await getRelayUrl();
    return number != null && number.isNotEmpty && url != null && url.isNotEmpty;
  }

  Future<List<Contact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kContacts);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveContacts(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_kContacts, raw);
  }

  Future<void> addContact(Contact contact) async {
    final contacts = await getContacts();
    if (contacts.any((c) => c.number == contact.number)) return;
    contacts.add(contact);
    await saveContacts(contacts);
  }

  Future<void> removeContact(String number) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.number == number);
    await saveContacts(contacts);
  }
}

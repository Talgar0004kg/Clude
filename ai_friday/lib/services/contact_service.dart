import 'package:contacts_service/contacts_service.dart' as cs;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact.dart';
import '../utils/logger.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  List<Contact> _contacts = [];
  bool _loaded = false;

  final Map<String, String> _aliases = {
    'мама': 'мама',
    'папа': 'папа',
    'жена': 'жена',
    'муж': 'муж',
    'друг': 'друг',
    'подруга': 'подруга',
  };

  Future<void> load() async {
    if (_loaded || kIsWeb) return;
    final status = await Permission.contacts.request();
    if (!status.isGranted) return;

    try {
      final raw = await cs.ContactsService.getContacts(withThumbnails: false);
      _contacts = raw
          .where((c) => c.phones != null && c.phones!.isNotEmpty)
          .map((c) => Contact(
                id: c.identifier ?? '',
                displayName: c.displayName ?? '',
                phones: c.phones!.map((p) => p.value ?? '').where((p) => p.isNotEmpty).toList(),
              ))
          .toList();
      _loaded = true;
      AppLogger.info('Loaded ${_contacts.length} contacts');
    } catch (e) {
      AppLogger.error('Failed to load contacts', e);
    }
  }

  Contact? findByName(String name) {
    if (_contacts.isEmpty) return null;
    final lower = name.toLowerCase().trim();

    // Exact match
    final exact = _contacts.where((c) => c.displayName.toLowerCase() == lower).firstOrNull;
    if (exact != null) return exact;

    // Contains match
    final contains = _contacts.where((c) => c.displayName.toLowerCase().contains(lower)).firstOrNull;
    if (contains != null) return contains;

    // Fuzzy match (Levenshtein)
    Contact? best;
    int bestDist = 3;
    for (final c in _contacts) {
      final dist = _levenshtein(lower, c.displayName.toLowerCase());
      if (dist < bestDist) {
        bestDist = dist;
        best = c;
      }
      // Also check first word of name
      final firstWord = c.displayName.split(' ').first.toLowerCase();
      final distFirst = _levenshtein(lower, firstWord);
      if (distFirst < bestDist) {
        bestDist = distFirst;
        best = c;
      }
    }
    return best;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final dp = List.generate(a.length + 1, (i) => List.generate(b.length + 1, (j) => 0));
    for (int i = 0; i <= a.length; i++) { dp[i][0] = i; }
    for (int j = 0; j <= b.length; j++) { dp[0][j] = j; }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[a.length][b.length];
  }

  void addAlias(String alias, String contactName) {
    _aliases[alias.toLowerCase()] = contactName;
  }

  List<Contact> get all => List.unmodifiable(_contacts);
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  LocalStorageService(this.preferences);
  final SharedPreferences preferences;
  Map<String, dynamic> read() {
    final raw = preferences.getString('pairlight_state');
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Map<String, dynamic> state) async {
    if (!await preferences.setString('pairlight_state', jsonEncode(state))) {
      throw StateError('Could not save your changes. Please try again.');
    }
  }
}

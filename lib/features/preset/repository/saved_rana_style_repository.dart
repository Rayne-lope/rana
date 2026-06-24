import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/preset/model/saved_rana_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository interface for locally saved Rana Styles.
abstract interface class SavedRanaStyleRepository {
  /// Loads saved styles.
  Future<List<SavedRanaStyle>> loadAll();

  /// Persists or replaces a saved style.
  Future<void> save(SavedRanaStyle style);

  /// Deletes a saved style by id.
  Future<void> delete(String id);
}

/// SharedPreferences-backed saved style repository.
class SharedPreferencesSavedRanaStyleRepository
    implements SavedRanaStyleRepository {
  /// Main constructor.
  const SharedPreferencesSavedRanaStyleRepository();

  static const String _storageKey = 'rana.saved_styles.v1';

  @override
  Future<List<SavedRanaStyle>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _decodeStyles(prefs.getString(_storageKey));
    } on MissingPluginException {
      return const [];
    } on Object catch (e, stackTrace) {
      AppLogger.e(
        'SavedRanaStyleRepository',
        'Failed to load saved styles',
        e,
        stackTrace,
      );
      return const [];
    }
  }

  @override
  Future<void> save(SavedRanaStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    final styles = await loadAll();
    final next = <SavedRanaStyle>[
      for (final existing in styles)
        if (existing.id != style.id) existing,
      style,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    await prefs.setString(_storageKey, json.encode(_encodeStyles(next)));
  }

  @override
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final styles = await loadAll();
    final next = [
      for (final style in styles)
        if (style.id != id) style,
    ];

    await prefs.setString(_storageKey, json.encode(_encodeStyles(next)));
  }

  List<SavedRanaStyle> _decodeStyles(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final dynamic decoded = json.decode(raw);
    if (decoded is! List<dynamic>) {
      return const [];
    }

    final styles = <SavedRanaStyle>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        styles.add(SavedRanaStyle.fromJson(item));
      }
    }
    return styles;
  }

  List<Map<String, dynamic>> _encodeStyles(List<SavedRanaStyle> styles) => [
    for (final style in styles) style.toJson(),
  ];
}

/// Provider exposing the local saved style repository.
final savedRanaStyleRepositoryProvider = Provider<SavedRanaStyleRepository>(
  (ref) => const SharedPreferencesSavedRanaStyleRepository(),
);

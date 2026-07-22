import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository interface for persisting film rolls locally.
abstract interface class FilmRollRepository {
  /// Loads the currently active roll, or null if there is none.
  Future<FilmRoll?> loadActive();

  /// Loads archived completed rolls, newest first.
  Future<List<FilmRoll>> loadAll();

  /// Saves (inserts or updates) a roll.
  Future<void> save(FilmRoll roll);

  /// Deletes a roll by [id].
  Future<void> delete(String id);
}

/// [SharedPreferences]-backed implementation of [FilmRollRepository].
///
/// Storage keys:
///   `rana.film_roll.active`  — single JSON object for the active roll.
///   `rana.film_rolls.v2`     — JSON array of completed rolls.
class SharedPreferencesFilmRollRepository implements FilmRollRepository {
  /// Main constructor.
  const SharedPreferencesFilmRollRepository();

  static const _activeKey = 'rana.film_roll.active';
  static const _historyKey = 'rana.film_rolls.v2';
  static const _legacyHistoryKey = 'rana.film_rolls.v1';

  @override
  Future<FilmRoll?> loadActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeKey);
      if (raw == null || raw.isEmpty) return null;
      final dynamic decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return FilmRoll.fromJson(decoded);
    } on MissingPluginException {
      return null;
    } on Object catch (e, stack) {
      AppLogger.e('FilmRollRepository', 'Failed to loadActive', e, stack);
      rethrow;
    }
  }

  @override
  Future<List<FilmRoll>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_historyKey) ?? prefs.getString(_legacyHistoryKey);
      if (raw == null || raw.isEmpty) return const [];
      final dynamic decoded = json.decode(raw);
      if (decoded is! List<dynamic>) return const [];
      final rolls = <FilmRoll>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final roll = FilmRoll.fromJson(item);
          // Older development builds persisted abandoned rolls. They are no
          // longer groupable after the user confirmed that abandon hides a
          // roll while preserving the underlying photos.
          if (roll.status == FilmRollStatus.completed) {
            rolls.add(roll);
          }
        }
      }
      // Newest first.
      rolls.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return rolls;
    } on MissingPluginException {
      return const [];
    } on Object catch (e, stack) {
      AppLogger.e('FilmRollRepository', 'Failed to loadAll', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> save(FilmRoll roll) async {
    final prefs = await SharedPreferences.getInstance();

    if (roll.status == FilmRollStatus.active) {
      // Store as active roll.
      final saved = await prefs.setString(
        _activeKey,
        json.encode(roll.toJson()),
      );
      if (!saved) {
        throw StateError('SharedPreferences rejected the active Film Roll.');
      }
    } else {
      // Upsert the archive before clearing the active key. SharedPreferences
      // cannot update both keys transactionally; this order is deliberately
      // conservative. If the second write fails, a restart can still recover
      // the active roll rather than losing an already-saved frame grouping.
      final history = await loadAll();
      final next = <FilmRoll>[
        for (final existing in history)
          if (existing.id != roll.id) existing,
        roll,
      ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final saved = await prefs.setString(
        _historyKey,
        json.encode(next.map((r) => r.toJson()).toList()),
      );
      if (!saved) {
        throw StateError('SharedPreferences rejected the Film Roll archive.');
      }

      // Clear active only after the completed roll is durably archived.
      final activeRaw = prefs.getString(_activeKey);
      if (activeRaw != null) {
        final dynamic activeDecoded = json.decode(activeRaw);
        if (activeDecoded is Map<String, dynamic> &&
            activeDecoded['id'] == roll.id) {
          final removed = await prefs.remove(_activeKey);
          if (!removed) {
            throw StateError('Could not clear the active Film Roll.');
          }
        }
      }
    }
  }

  @override
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove from active if matching.
    final activeRaw = prefs.getString(_activeKey);
    if (activeRaw != null) {
      final dynamic activeDecoded = json.decode(activeRaw);
      if (activeDecoded is Map<String, dynamic> && activeDecoded['id'] == id) {
        final removed = await prefs.remove(_activeKey);
        if (!removed) {
          throw StateError('Could not remove the active Film Roll.');
        }
        return;
      }
    }

    // Remove from history.
    final history = await loadAll();
    final next = [
      for (final roll in history)
        if (roll.id != id) roll,
    ];
    final saved = await prefs.setString(
      _historyKey,
      json.encode(next.map((r) => r.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('SharedPreferences rejected the Film Roll archive.');
    }
  }
}

/// Provider exposing the [FilmRollRepository] implementation.
final filmRollRepositoryProvider = Provider<FilmRollRepository>(
  (ref) => const SharedPreferencesFilmRollRepository(),
);

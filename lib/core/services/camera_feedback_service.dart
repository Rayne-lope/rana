import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:rana/core/utils/app_logger.dart';

/// Centralized service managing analog camera audio effects and haptic feedback.
class CameraFeedbackService {
  CameraFeedbackService._internal();

  static final CameraFeedbackService instance = CameraFeedbackService._internal();

  AudioPlayer? _player;
  bool _audioInitAttempted = false;

  bool _isBindingInitialized() {
    try {
      return ServicesBinding.instance != null;
    } catch (_) {
      return false;
    }
  }

  AudioPlayer? _getAudioPlayer() {
    if (_player != null) return _player;
    if (_audioInitAttempted || !_isBindingInitialized()) return null;
    _audioInitAttempted = true;
    try {
      final player = AudioPlayer();
      player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.assistanceSonification,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
          ),
        ),
      ).catchError((_) {});
      _player = player;
      return player;
    } on Object catch (e) {
      AppLogger.w('CameraFeedbackService', 'AudioPlayer unavailable in current environment: $e');
      return null;
    }
  }

  /// Plays the SLR shutter click sound and triggers medium haptic feedback.
  Future<void> playShutter({
    bool playSound = true,
    bool playHaptic = true,
  }) async {
    if (playHaptic && _isBindingInitialized()) {
      try {
        HapticFeedback.mediumImpact().catchError((_) {});
      } on Object catch (_) {}
    }
    if (playSound) {
      final player = _getAudioPlayer();
      if (player != null) {
        try {
          await player.stop().catchError((_) {});
          await player.play(AssetSource('sounds/shutter_click.wav')).catchError((_) {});
        } on Object catch (e, stack) {
          AppLogger.e('CameraFeedbackService', 'Failed playing shutter sound', e, stack);
        }
      }
    }
  }

  /// Plays the tactile dial tick sound and triggers light selection haptic.
  Future<void> playDialTick({
    bool playSound = true,
    bool playHaptic = true,
  }) async {
    if (playHaptic && _isBindingInitialized()) {
      try {
        HapticFeedback.selectionClick().catchError((_) {});
      } on Object catch (_) {}
    }
    if (playSound) {
      final player = _getAudioPlayer();
      if (player != null) {
        try {
          await player.stop().catchError((_) {});
          await player.play(AssetSource('sounds/dial_tick.wav')).catchError((_) {});
        } on Object catch (e, stack) {
          AppLogger.e('CameraFeedbackService', 'Failed playing dial tick sound', e, stack);
        }
      }
    }
  }

  /// Plays the film roll winding sound.
  Future<void> playFilmWind({
    bool playSound = true,
    bool playHaptic = true,
  }) async {
    if (playHaptic && _isBindingInitialized()) {
      try {
        HapticFeedback.selectionClick().catchError((_) {});
      } on Object catch (_) {}
    }
    if (playSound) {
      final player = _getAudioPlayer();
      if (player != null) {
        try {
          await player.stop().catchError((_) {});
          await player.play(AssetSource('sounds/film_wind.wav')).catchError((_) {});
        } on Object catch (e, stack) {
          AppLogger.e('CameraFeedbackService', 'Failed playing film wind sound', e, stack);
        }
      }
    }
  }

  /// Plays the film roll completion sound and triggers heavy haptic impact.
  Future<void> playRollComplete({
    bool playSound = true,
    bool playHaptic = true,
  }) async {
    if (playHaptic && _isBindingInitialized()) {
      try {
        HapticFeedback.heavyImpact().catchError((_) {});
      } on Object catch (_) {}
    }
    if (playSound) {
      final player = _getAudioPlayer();
      if (player != null) {
        try {
          await player.stop().catchError((_) {});
          await player.play(AssetSource('sounds/roll_complete.wav')).catchError((_) {});
        } on Object catch (e, stack) {
          AppLogger.e('CameraFeedbackService', 'Failed playing roll complete sound', e, stack);
        }
      }
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _audioInitAttempted = false;
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const minHintThresholdSeconds = 30;
const maxHintThresholdSeconds = 120;
const defaultHintThresholdSeconds = 60;

int clampHintThreshold(int seconds) {
  return seconds.clamp(minHintThresholdSeconds, maxHintThresholdSeconds);
}

@immutable
class AppSettings {
  const AppSettings({
    this.darkTheme = false,
    this.reducedMotion = false,
    this.hintThresholdSeconds = defaultHintThresholdSeconds,
  });

  final bool darkTheme;
  final bool reducedMotion;
  final int hintThresholdSeconds;

  AppSettings copyWith({
    bool? darkTheme,
    bool? reducedMotion,
    int? hintThresholdSeconds,
  }) {
    return AppSettings(
      darkTheme: darkTheme ?? this.darkTheme,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      hintThresholdSeconds: hintThresholdSeconds ?? this.hintThresholdSeconds,
    );
  }
}

class SettingsController extends ChangeNotifier {
  static const darkThemeKey = 'settings_dark_theme';
  static const reducedMotionKey = 'settings_reduced_motion';
  static const hintThresholdKey = 'settings_hint_threshold_seconds';

  AppSettings _settings = const AppSettings();
  bool _unavailable = false;

  AppSettings get settings => _settings;

  /// True when the last read or write failed, so the values on screen are
  /// only in memory.
  bool get preferencesUnavailable => _unavailable;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _settings = AppSettings(
        darkTheme: preferences.getBool(darkThemeKey) ?? false,
        reducedMotion: preferences.getBool(reducedMotionKey) ?? false,
        hintThresholdSeconds: clampHintThreshold(
          preferences.getInt(hintThresholdKey) ?? defaultHintThresholdSeconds,
        ),
      );
      _unavailable = false;
    } catch (_) {
      _settings = const AppSettings();
      _unavailable = true;
    }
    notifyListeners();
  }

  Future<void> setDarkTheme(bool value) {
    return _apply(_settings.copyWith(darkTheme: value), (preferences) {
      return preferences.setBool(darkThemeKey, value);
    });
  }

  Future<void> setReducedMotion(bool value) {
    return _apply(_settings.copyWith(reducedMotion: value), (preferences) {
      return preferences.setBool(reducedMotionKey, value);
    });
  }

  Future<void> setHintThreshold(int seconds) {
    final clamped = clampHintThreshold(seconds);

    return _apply(_settings.copyWith(hintThresholdSeconds: clamped), (
      preferences,
    ) {
      return preferences.setInt(hintThresholdKey, clamped);
    });
  }

  // The new value is applied in memory first so the UI never waits on disk,
  // then written; a failed write only flips the unavailable flag.
  Future<void> _apply(
    AppSettings next,
    Future<bool> Function(SharedPreferences) write,
  ) async {
    _settings = next;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await write(preferences);
      if (!_unavailable) {
        return;
      }
      _unavailable = false;
    } catch (_) {
      _unavailable = true;
    }
    notifyListeners();
  }
}

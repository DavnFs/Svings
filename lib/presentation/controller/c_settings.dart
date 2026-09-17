import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage seams, injectable for tests. Production uses the real plugins;
/// widget tests inject fakes so no platform channel is ever touched.
class SettingsStore {
  Future<SharedPreferences> getPrefs() => SharedPreferences.getInstance();
  final _storage = const FlutterSecureStorage();
  Future<String?> readKey(String key) => _storage.read(key: key);
  Future<void> writeKey(String key, String value) => _storage.write(key: key, value: value);
  Future<void> deleteKey(String key) => _storage.delete(key: key);
}

/// Single settings state: the one source of truth for theme and Gmail/LLM
/// config. Screens read via `Get.find<CSettings>()` — never a duplicated
/// local copy (same reasoning as the MainTab index fix).
///
/// Split storage on purpose:
/// - `SharedPreferences` (non-sensitive): theme, decimals, LLM
///   provider/model, last-sync timestamp, 429 counter.
/// - `FlutterSecureStorage` (credentials): Groq API key only. Never prefs,
///   never logs.
class CSettings extends GetxController {
  static const _kTheme = 'settings.theme_mode'; // 'system' | 'light' | 'dark'
  static const _kDecimals = 'settings.show_decimals';
  static const _kProvider = 'settings.llm_provider'; // 'groq'
  static const _kModel = 'settings.llm_model';
  static const _kLastSync = 'settings.last_sync_ms';
  static const _kRateHits = 'settings.llm_429_hits';

  static const _kApiKey = 'settings.groq_api_key';
  static const defaultModel = 'llama-3.1-8b-instant';

  /// Free-tier Groq models worth offering. 8b-instant first: highest daily
  /// quota, and extraction is a small job that needs no large model.
  static const groqModels = [
    'llama-3.1-8b-instant',
    'llama-3.3-70b-versatile',
    'mixtral-8x7b-32768',
  ];

  final _prefs = Rxn<SharedPreferences>();
  final SettingsStore _store;

  CSettings({SettingsStore? store}) : _store = store ?? SettingsStore();

  final _themeMode = ThemeMode.system.obs;
  ThemeMode get themeMode => _themeMode.value;

  final _showDecimals = true.obs;
  bool get showDecimals => _showDecimals.value;

  final _llmProvider = 'groq'.obs;
  String get llmProvider => _llmProvider.value;

  final _llmModel = defaultModel.obs;
  String get llmModel => _llmModel.value;

  /// Masked for display only — `•••abcd`. The real key never leaves secure
  /// storage except into the HTTP call.
  final _apiKeyTail = ''.obs;
  String get apiKeyTail => _apiKeyTail.value;
  bool get hasApiKey => _apiKeyTail.value.isNotEmpty;

  final _lastSync = Rxn<DateTime>();
  DateTime? get lastSync => _lastSync.value;

  final _rateHits = 0.obs;

  /// Consecutive 429s from the LLM provider. Shown as a warning so a stalled
  /// sync is explained instead of silently failing.
  int get rateHits => _rateHits.value;
  bool get rateLimited => _rateHits.value >= 3;

  bool get loaded => _prefs.value != null;

  Future<void> load() async {
    final prefs = await _store.getPrefs();
    _prefs.value = prefs;
    _themeMode.value = switch (prefs.getString(_kTheme)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _showDecimals.value = prefs.getBool(_kDecimals) ?? true;
    _appLock.value = prefs.getBool(_kAppLock) ?? false;
    _lockOnResume.value = prefs.getBool(_kLockOnResume) ?? true;
    _llmProvider.value = prefs.getString(_kProvider) ?? 'groq';
    _llmModel.value = prefs.getString(_kModel) ?? defaultModel;
    final ms = prefs.getInt(_kLastSync);
    _lastSync.value = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    _rateHits.value = prefs.getInt(_kRateHits) ?? 0;
    final key = await _store.readKey(_kApiKey);
    _apiKeyTail.value = key == null || key.length < 4 ? '' : key.substring(key.length - 4);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode.value = mode;
    await _prefs.value?.setString(_kTheme, mode.name);
  }

  Future<void> setShowDecimals(bool v) async {
    _showDecimals.value = v;
    await _prefs.value?.setBool(_kDecimals, v);
  }

  Future<void> setLlmModel(String model) async {
    _llmModel.value = model;
    await _prefs.value?.setString(_kModel, model);
  }

  /// App lock (Security section). Biometric unlock is gated behind device
  /// capability at the call site — this toggle only records intent.
  /// PIN storage is deliberately OUT of scope for this pass (needs its own
  /// secure-storage + lock-screen flow); the toggle is presented as biometric
  /// only until that flow exists.
  static const _kAppLock = 'settings.app_lock';
  static const _kLockOnResume = 'settings.lock_on_resume';

  final _appLock = false.obs;
  bool get appLock => _appLock.value;

  final _lockOnResume = true.obs;
  bool get lockOnResume => _lockOnResume.value;

  Future<void> setAppLock(bool v) async {
    _appLock.value = v;
    await _prefs.value?.setBool(_kAppLock, v);
  }

  Future<void> setLockOnResume(bool v) async {
    _lockOnResume.value = v;
    await _prefs.value?.setBool(_kLockOnResume, v);
  }

  /// Stores the key in the platform keychain/keystore. Never in prefs, never
  /// logged — only the last 4 chars are kept in memory for the masked label.
  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _store.deleteKey(_kApiKey);
      _apiKeyTail.value = '';
    } else {
      await _store.writeKey(_kApiKey, trimmed);
      _apiKeyTail.value = trimmed.substring(trimmed.length - 4);
    }
  }

  Future<String?> readApiKey() => _store.readKey(_kApiKey);
  Future<void> clearApiKey() => setApiKey('');

  Future<void> recordSync(DateTime when) async {
    _lastSync.value = when;
    await _prefs.value?.setInt(_kLastSync, when.millisecondsSinceEpoch);
  }

  Future<void> recordRateHit() async {
    _rateHits.value++;
    await _prefs.value?.setInt(_kRateHits, _rateHits.value);
  }

  Future<void> clearRateHits() async {
    _rateHits.value = 0;
    await _prefs.value?.setInt(_kRateHits, 0);
  }
}

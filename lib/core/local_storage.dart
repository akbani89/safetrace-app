import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  final _secure = const FlutterSecureStorage();

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<void> saveSession({
    required String adid,
    required String token,
  }) async {
    await _secure.write(key: AppConstants.adidKey, value: adid);
    await _secure.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getAdid() async {
    return await _secure.read(key: AppConstants.adidKey);
  }

  Future<String?> getToken() async {
    return await _secure.read(key: AppConstants.tokenKey);
  }

  Future<bool> hasSession() async {
    final adid = await getAdid();
    return adid != null && adid.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _secure.deleteAll();
  }

  // ─── Recovery Code ─────────────────────────────────────────────────────────

  Future<bool> hasSeenRecoveryCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.recoveryCodeKey) ?? false;
  }

  Future<void> markRecoveryCodeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.recoveryCodeKey, true);
  }

  // ─── Onboarding ────────────────────────────────────────────────────────────

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_seen') ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
  }
}

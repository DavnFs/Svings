import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cause_money_record/data/model/user.dart';
import 'package:cause_money_record/data/source/source_user.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';

/// Lightweight session helper — caches the public profile locally so the
/// app can boot into the home screen without an extra roundtrip, while
/// still relying on Supabase as the source of truth.
class Session {
  static const _key = 'user_profile';
  static SharedPreferences? _pref;

  static Future<SharedPreferences> get _instance async {
    _pref ??= await SharedPreferences.getInstance();
    return _pref!;
  }

  /// Persist the profile to local storage and update the GetX controller.
  static Future<bool> saveUser(User user) async {
    final pref = await _instance;
    final ok = await pref.setString(_key, jsonEncode(user.toJson()));
    if (ok && Get.isRegistered<CUser>()) {
      Get.find<CUser>().setData(user);
    }
    return ok;
  }

  /// Try the local cache first; if missing, attempt a remote fetch.
  static Future<User> getUser() async {
    final pref = await _instance;
    final cached = pref.getString(_key);
    if (cached != null) {
      final user = User.fromProfileJson(jsonDecode(cached));
      if (Get.isRegistered<CUser>()) Get.find<CUser>().setData(user);
      return user;
    }
    final remote = await SourceUser.currentUser();
    final user = remote ?? User.empty();
    if (Get.isRegistered<CUser>()) Get.find<CUser>().setData(user);
    if (user.idUser != null) await saveUser(user);
    return user;
  }

  static Future<bool> clearUser() async {
    final pref = await _instance;
    final ok = await pref.remove(_key);
    if (Get.isRegistered<CUser>()) Get.find<CUser>().setData(User.empty());
    return ok;
  }
}

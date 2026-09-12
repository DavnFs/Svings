import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Result wrapper for auth operations.
class AuthResult {
  final bool success;
  final String? error;
  final User? user;
  const AuthResult.success(this.user) : success = true, error = null;
  const AuthResult.failure(this.error)
      : success = false,
        user = null;
}

/// Authentication via Supabase Auth.
///
/// All public methods return `AuthResult` so callers can switch on
/// `success` / `error` without dealing with exceptions in the UI layer.
class SourceUser {
  static supa.SupabaseClient get _client => SupabaseConfig.client;

  /// Sign in with email + password.
  static Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        return const AuthResult.failure('Login gagal — periksa email dan password');
      }
      final user = await _fetchProfile(response.user!.id);
      return AuthResult.success(user);
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    } catch (e) {
      return AuthResult.failure('Tidak dapat terhubung ke server: $e');
    }
  }

  /// Register a new user with email + password + full name.
  static Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name}, // stored in raw_user_meta_data
      );
      if (response.user == null) {
        return const AuthResult.failure('Registrasi gagal');
      }
      final user = await _fetchProfile(response.user!.id);
      return AuthResult.success(user);
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    } catch (e) {
      return AuthResult.failure('Tidak dapat terhubung ke server: $e');
    }
  }

  /// Sign out the current user.
  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Get the current session's user (or null if not signed in).
  static Future<User?> currentUser() async {
    final auth = _client.auth.currentUser;
    if (auth == null) return null;
    return _fetchProfile(auth.id);
  }

  /// Fetch the profile row from `public.profiles`.
  static Future<User> _fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return User.fromProfileJson(data);
  }

  static String _mapAuthError(supa.AuthException e) {
    switch (e.message.toLowerCase()) {
      case var m when m.contains('invalid login') || m.contains('invalid credentials'):
        return 'Email atau password salah';
      case var m when m.contains('email already') || m.contains('already registered'):
        return 'Email sudah terdaftar';
      case var m when m.contains('password') && m.contains('short'):
        return 'Password terlalu pendek (min 6 karakter)';
      case var m when m.contains('network'):
        return 'Tidak ada koneksi internet';
      default:
        return e.message;
    }
  }
}

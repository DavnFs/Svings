import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase client + env loading.
///
/// Before running the app, copy `.env.example` to `.env` in the project
/// root and fill in your `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
class SupabaseConfig {
  SupabaseConfig._();

  static SupabaseClient get client => Supabase.instance.client;

  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  /// The dashboard still labels this "anon key"; supabase_flutter renamed the
  /// parameter to `publishableKey`. Same value, so the env var keeps its name.
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Call once from `main()` before `runApp()`.
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Supabase URL or anon key is missing. '
        'Copy .env.example to .env and fill in your credentials.',
      );
    }
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  /// Returns the current authenticated user, or null if signed out.
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;
  static String? get currentUserEmail => currentUser?.email;
}

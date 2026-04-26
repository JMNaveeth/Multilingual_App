import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static const String _supabaseUrlFromDefine = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _supabaseAnonKeyFromDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String get supabaseUrl {
    if (_supabaseUrlFromDefine.isNotEmpty) {
      return _supabaseUrlFromDefine;
    }
    return dotenv.env['SUPABASE_URL']?.trim() ?? '';
  }

  static String get supabaseAnonKey {
    if (_supabaseAnonKeyFromDefine.isNotEmpty) {
      return _supabaseAnonKeyFromDefine;
    }
    return dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
  }

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;
}

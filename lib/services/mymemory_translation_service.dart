import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MyMemoryTranslationService {
  // In-memory cache to prevent redundant API calls
  static final Map<String, String> _cache = {};
  
  // Max cache size to prevent memory leaks
  static const int _maxCacheSize = 250;

  /// Translates text using the MyMemory API.
  /// Falls back gracefully to original text on failure.
  static Future<String> translateText(
    String text, {
    required String from,
    required String to,
  }) async {
    if (text.isEmpty) return text;

    // Standardize language codes (e.g. en_US -> en)
    final fromLang = _cleanLanguageCode(from);
    final toLang = _cleanLanguageCode(to);

    // If source and target languages are the same, no translation is needed
    if (fromLang != 'auto' && fromLang == toLang) {
      return text;
    }

    final cacheKey = '$fromLang|$toLang|${text.trim()}';
    if (_cache.containsKey(cacheKey)) {
      if (kDebugMode) {
        print('🌐 [MyMemory Cache Hit] "$text" -> "${_cache[cacheKey]}"');
      }
      return _cache[cacheKey]!;
    }

    try {
      final queryText = Uri.encodeComponent(text.trim());
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=$queryText&langpair=$fromLang|$toLang',
      );

      if (kDebugMode) {
        print('🌐 [MyMemory API Call] Translating from $fromLang to $toLang');
      }

      final response = await http.get(url).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['responseData'] != null) {
          final translatedText = data['responseData']['translatedText'] as String;
          if (translatedText.isNotEmpty) {
            // Manage cache size
            if (_cache.length >= _maxCacheSize) {
              _cache.remove(_cache.keys.first);
            }
            _cache[cacheKey] = translatedText;
            return translatedText;
          }
        }
      }
      
      if (kDebugMode) {
        print('⚠️ [MyMemory API Error] Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MyMemory Translation Exception] $e');
      }
    }

    // Graceful fallback to original text on failure or rate-limits
    return text;
  }

  /// Extracts standard 2-letter language code (e.g., 'en-US' or 'en_US' -> 'en')
  static String _cleanLanguageCode(String code) {
    final cleanCode = code.trim().toLowerCase();
    if (cleanCode == 'auto' || cleanCode == 'autodetect') {
      return 'auto';
    }
    
    // Split by dash or underscore and return the first segment
    if (cleanCode.contains('-')) {
      return cleanCode.split('-')[0];
    }
    if (cleanCode.contains('_')) {
      return cleanCode.split('_')[0];
    }
    return cleanCode;
  }
  
  /// Clears the translation cache.
  static void clearCache() {
    _cache.clear();
  }
}

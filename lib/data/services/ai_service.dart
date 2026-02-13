import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';

/// Authentication mode for the AI service.
enum AiAuthMode { none, oauth, apiKey }

/// Service wrapper for the Gemini REST API.
///
/// Supports two authentication modes:
/// - **OAuth** (default): Google Sign-In → OAuth2 access token → Bearer header
/// - **API Key** (fallback): manual key → `?key=` query param
///
/// Uses Dio for HTTP + SSE streaming. No `google_generative_ai` dependency.
class AiService {
  static const String _boxName = 'ai_settings';
  static const String _apiKeyField = 'gemini_api_key';
  static const String _authModeField = 'auth_mode';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  // FORCE Gemini 2.5 Flash Lite as requested
  static const String _model = 'gemini-2.5-flash-lite';

  final Dio _dio = Dio();

  /// Google Sign-In instance — scoped to Generative Language API.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/generative-language'],
  );

  String? _accessToken;
  String? _apiKey;
  AiAuthMode _authMode = AiAuthMode.none;
  GoogleSignInAccount? _currentUser;

  // ── Getters ──────────────────────────────────────────────────

  AiAuthMode get authMode => _authMode;
  String? get userName => _currentUser?.displayName;
  String? get userEmail => _currentUser?.email;
  String? get userPhotoUrl => _currentUser?.photoUrl;

  bool get isConfigured =>
      (_authMode == AiAuthMode.oauth && _accessToken != null) ||
      (_authMode == AiAuthMode.apiKey && _apiKey != null && _apiKey!.isNotEmpty);

  // ── Initialization ───────────────────────────────────────────

  /// Call once at startup — restores persisted auth mode & silent sign-in.
  Future<void> init() async {
    final box = await _openBox();
    final modeStr = box.get(_authModeField) as String?;
    final savedKey = box.get(_apiKeyField) as String?;

    if (modeStr == 'oauth') {
      // Try silent sign-in to restore session
      try {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          final auth = await account.authentication;
          _accessToken = auth.accessToken;
          _currentUser = account;
          _authMode = AiAuthMode.oauth;
        }
      } catch (e) {
        debugPrint('Silent sign-in failed: $e');
      }
    } else if (modeStr == 'apiKey' && savedKey != null && savedKey.isNotEmpty) {
      _apiKey = savedKey;
      _authMode = AiAuthMode.apiKey;
    }
  }

  // ── OAuth ────────────────────────────────────────────────────

  /// Interactive Google Sign-In flow.
  /// Returns null on success, or an error message on failure.
  ///
  /// On Windows Desktop: if the browser doesn't open, the consent URL
  /// is printed to the debug console as a safety net.
  Future<String?> signInWithGoogle() async {
    // On Windows/Linux, google_sign_in plugin is not available —
    // return early with a user-friendly message instead of crashing.
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux);

    if (isDesktop) {
      return 'Google Sign-In is not supported on desktop platforms.\n'
          'Please use an API Key instead (paste it in the field below).';
    }

    try {
      // Try silent sign-in first (may restore a previous session)
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) return 'Sign-in was cancelled.';

      final auth = await account.authentication;
      _accessToken = auth.accessToken;
      _currentUser = account;
      _authMode = AiAuthMode.oauth;

      final box = await _openBox();
      await box.put(_authModeField, 'oauth');
      return null; // success
    } catch (e) {
      final msg = e.toString();
      debugPrint('Google Sign-In error: $msg');

      // Platform-specific guidance
      if (isDesktop) {
        if (msg.contains('PlatformException') || msg.contains('MissingPluginException')) {
           return 'Google Sign-In not supported on this desktop execution.\n'
               'Please use an API Key instead.';
        }
        return 'Google Sign-In failed on desktop.\n'
            'Please check your browser or use an API Key.';
      }
      return 'Sign-in failed: $msg';
    }
  }

  /// Sign out and clear OAuth state.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _accessToken = null;
    _currentUser = null;
    _authMode = AiAuthMode.none;

    final box = await _openBox();
    await box.delete(_authModeField);
  }

  // ── API Key (fallback) ───────────────────────────────────────

  Future<String?> getApiKey() async {
    final box = await _openBox();
    return box.get(_apiKeyField) as String?;
  }

  Future<void> setApiKey(String key) async {
    final box = await _openBox();
    await box.put(_apiKeyField, key);
    await box.put(_authModeField, 'apiKey');
    _apiKey = key;
    _authMode = AiAuthMode.apiKey;
  }

  // ── Gemini REST Calls ────────────────────────────────────────

  /// Streams a page summary from Gemini.
  Stream<String> summarizePage(String pageText) {
    if (pageText.trim().isEmpty) {
      return Stream.value(
          'No text found on this page. Try a page with readable text.');
    }

    final prompt =
        'Summarize the following page of a PDF document in a clear, concise manner. '
        'Use bullet points for key takeaways. Keep it under 200 words.\n\n'
        '---\n$pageText\n---';

    return _streamGenerate(prompt);
  }

  /// Streams an answer to a user question about page content.
  Stream<String> askQuestion(String pageText, String question) {
    final prompt =
        'You are a helpful reading assistant. The user is reading a PDF and has a question '
        'about the following page content:\n\n'
        '---\n$pageText\n---\n\n'
        'User question: $question\n\n'
        'Answer concisely and helpfully.';

    return _streamGenerate(prompt);
  }

  /// Core streaming call to Gemini REST API using SSE.
  Stream<String> _streamGenerate(String prompt) async* {
    if (!isConfigured) {
      yield 'Error: Not authenticated. Please sign in or enter an API key.';
      return;
    }

    // Build URL based on auth mode
    String url = '$_baseUrl/$_model:streamGenerateContent?alt=sse';
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
    };

    if (_authMode == AiAuthMode.oauth) {
      // Refresh token if needed
      if (_currentUser != null) {
        try {
           final auth = await _currentUser!.authentication;
           _accessToken = auth.accessToken;
        } catch (_) {
           // Token refresh failed
        }
      }
      headers['Authorization'] = 'Bearer $_accessToken';
    } else {
      url += '&key=$_apiKey';
    }

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    };

    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data!.stream;
      final lineBuffer = StringBuffer();

      await for (final chunk in stream) {
        final text = utf8.decode(chunk);
        lineBuffer.write(text);

        // Parse SSE lines
        final raw = lineBuffer.toString();
        final lines = raw.split('\n');

        // Keep the last incomplete line in the buffer
        lineBuffer.clear();
        if (!raw.endsWith('\n')) {
          lineBuffer.write(lines.removeLast());
        }

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
            try {
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              final candidates = map['candidates'] as List<dynamic>?;
              if (candidates != null && candidates.isNotEmpty) {
                final content =
                    candidates[0]['content'] as Map<String, dynamic>?;
                if (content != null) {
                  final parts = content['parts'] as List<dynamic>?;
                  if (parts != null && parts.isNotEmpty) {
                    final t = parts[0]['text'] as String?;
                    if (t != null) yield t;
                  }
                }
              }
            } catch (_) {
              // skip malformed JSON
            }
          }
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        yield 'Error: Authentication failed. Please sign in again or check your API key.';
      } else if (e.response?.statusCode == 404) {
        yield 'Error: Model not found (404). Check API endpoint/model name.';
      } else {
        yield 'Error: ${e.message ?? 'Request failed'}';
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/data/services/ai_service.dart';

/// State for the AI sidebar.
class AiState {
  final bool isConfigured;
  final bool isLoading;
  final String response;
  final String? error;
  final AiAuthMode authMode;
  final String? userName;
  final String? userPhotoUrl;

  const AiState({
    this.isConfigured = false,
    this.isLoading = false,
    this.response = '',
    this.error,
    this.authMode = AiAuthMode.none,
    this.userName,
    this.userPhotoUrl,
  });

  AiState copyWith({
    bool? isConfigured,
    bool? isLoading,
    String? response,
    String? error,
    bool clearError = false,
    AiAuthMode? authMode,
    String? userName,
    String? userPhotoUrl,
    bool clearUser = false,
  }) {
    return AiState(
      isConfigured: isConfigured ?? this.isConfigured,
      isLoading: isLoading ?? this.isLoading,
      response: response ?? this.response,
      error: clearError ? null : (error ?? this.error),
      authMode: authMode ?? this.authMode,
      userName: clearUser ? null : (userName ?? this.userName),
      userPhotoUrl: clearUser ? null : (userPhotoUrl ?? this.userPhotoUrl),
    );
  }
}

class AiNotifier extends StateNotifier<AiState> {
  final AiService _service;

  AiNotifier(this._service) : super(const AiState()) {
    _init();
  }

  Future<void> _init() async {
    await _service.init();
    _syncState();
  }

  void _syncState() {
    state = state.copyWith(
      isConfigured: _service.isConfigured,
      authMode: _service.authMode,
      userName: _service.userName,
      userPhotoUrl: _service.userPhotoUrl,
    );
  }

  /// OAuth: Sign in with Google.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final error = await _service.signInWithGoogle();
      if (error != null) {
        state = state.copyWith(isLoading: false, error: error);
        return;
      }
      _syncState();
      
      // Force UI rebuild if successful
      // FIX: Ensure we transition to the API view if we have a user, 
      // even if the token check in isConfigured is strict.
      if (_service.isConfigured || _service.userName != null) {
        state = state.copyWith(isConfigured: true); 
      }
    } catch (e) {
      // Handle platform-specific errors (like MissingPluginException on Windows)
      final msg = e.toString();
      if (msg.contains('MissingPluginException') ||
          msg.contains('PlatformException')) {
        state = state.copyWith(
          error: 'Google Sign-In not supported on this platform.\n'
              'Please use an API Key.',
        );
      } else {
        state = state.copyWith(
          error: 'Sign-in error: $msg',
          isLoading: false, // Ensure loading clears on error
        );
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// OAuth: Sign out.
  Future<void> signOut() async {
    await _service.signOut();
    state = state.copyWith(
      isConfigured: false,
      authMode: AiAuthMode.none,
      response: '',
      clearError: true,
      clearUser: true,
    );
  }

  /// API Key fallback.
  Future<void> setApiKey(String key) async {
    await _service.setApiKey(key);
    _syncState();
  }

  /// Summarizes page text.
  Future<void> summarize(String pageText) async {
    state = state.copyWith(isLoading: true, response: '', clearError: true);
    try {
      final buffer = StringBuffer();
      await for (final chunk in _service.summarizePage(pageText)) {
        buffer.write(chunk);
        state = state.copyWith(response: buffer.toString());
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Asks a question about page text.
  Future<void> ask(String pageText, String question) async {
    state = state.copyWith(isLoading: true, response: '', clearError: true);
    try {
      final buffer = StringBuffer();
      await for (final chunk in _service.askQuestion(pageText, question)) {
        buffer.write(chunk);
        state = state.copyWith(response: buffer.toString());
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void clearResponse() {
    state = state.copyWith(response: '', clearError: true);
  }
}

final aiServiceProvider = Provider<AiService>((ref) => AiService());

final aiProvider = StateNotifierProvider<AiNotifier, AiState>((ref) {
  return AiNotifier(ref.watch(aiServiceProvider));
});

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/data/services/ai_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:monkread/presentation/providers/ai_provider.dart';

/// Slide-in sidebar for AI-powered page analysis.
///
/// Default: Google Sign-In (OAuth). Fallback: manual API key.
class AiSidebar extends ConsumerStatefulWidget {
  final Future<String> Function() onExtractPageText;
  final VoidCallback onClose;

  const AiSidebar({
    super.key,
    required this.onExtractPageText,
    required this.onClose,
  });

  @override
  ConsumerState<AiSidebar> createState() => _AiSidebarState();
}

class _AiSidebarState extends ConsumerState<AiSidebar> {
  final _apiKeyController = TextEditingController();
  final _questionController = TextEditingController();
  bool _showApiKeyField = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiProvider);
    final theme = Theme.of(context);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(aiState, theme),
          const Divider(height: 1),
          Expanded(
            child: aiState.isConfigured
                ? _buildAiPanel(aiState, theme)
                : _buildSetupPanel(aiState, theme),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildHeader(AiState aiState, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // User avatar or sparkle icon
          if (aiState.authMode == AiAuthMode.oauth &&
              aiState.userPhotoUrl != null)
            CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(aiState.userPhotoUrl!),
            )
          else
            Icon(Icons.auto_awesome,
                color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              aiState.authMode == AiAuthMode.oauth && aiState.userName != null
                  ? aiState.userName!
                  : 'AI Assistant',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Settings / sign-out
          if (aiState.isConfigured)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) {
                if (value == 'signout') {
                  ref.read(aiProvider.notifier).signOut();
                } else if (value == 'apikey') {
                  setState(() => _showApiKeyField = true);
                }
              },
              itemBuilder: (context) => [
                if (aiState.authMode == AiAuthMode.oauth)
                  const PopupMenuItem(
                    value: 'signout',
                    child: Text('Sign Out'),
                  ),
                const PopupMenuItem(
                  value: 'apikey',
                  child: Text('Change API Key'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ── Setup Panel (not configured) ─────────────────────────────

  Widget _buildSetupPanel(AiState aiState, ThemeData theme) {
    // Check if we are on a desktop platform (Windows/Linux)
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.auto_awesome_rounded,
              size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            isDesktop ? 'Setup AI Assistant' : 'AI Reading Assistant',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Summarize pages and ask questions\npowered by Google Gemini',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ── Primary Action ──
          if (isDesktop) ...[
            // Desktop: Show "Get API Key" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(
                    Uri.parse('https://aistudio.google.com/app/apikey')),
                icon: const Icon(Icons.vpn_key, size: 18),
                label: const Text('Get Free API Key'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Enter Key Below'),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            _buildApiKeyInput(theme),
          ] else ...[
            // Mobile/Web: Show Google Sign-In
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    aiState.isLoading ? null : _handleGoogleSignIn,
                icon: aiState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login, size: 18),
                label: Text(aiState.isLoading
                    ? 'Signing in…'
                    : 'Sign in with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 16),

            // Secondary: API Key Toggle
            GestureDetector(
              onTap: () => setState(() => _showApiKeyField = !_showApiKeyField),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key, size: 14,
                      color: theme.colorScheme.onSurface.withAlpha(153)),
                  const SizedBox(width: 4),
                  Text(
                    'Use API Key instead',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),

            if (_showApiKeyField) ...[
              const SizedBox(height: 12),
              _buildApiKeyInput(theme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildApiKeyInput(ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            hintText: 'AIza...',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          obscureText: true,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final key = _apiKeyController.text.trim();
              if (key.isNotEmpty) {
                ref.read(aiProvider.notifier).setApiKey(key);
                _apiKeyController.clear();
                setState(() => _showApiKeyField = false);
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save Key'),
          ),
        ),
      ],
    );
  }

  // ── AI Panel (configured) ────────────────────────────────────

  Widget _buildAiPanel(AiState aiState, ThemeData theme) {
    return Column(
      children: [
        if (_showApiKeyField) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildApiKeyInput(theme),
          ),
          const Divider(height: 1),
        ],

        // Actions
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: aiState.isLoading ? null : _handleSummarize,
                  icon: aiState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.summarize, size: 16),
                  label: Text(
                      aiState.isLoading ? 'Analyzing…' : 'Summarize Page'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        hintText: 'Ask about this page…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      style: theme.textTheme.bodySmall,
                      onSubmitted: (_) => _handleAsk(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: aiState.isLoading ? null : _handleAsk,
                    icon: const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Response
        Expanded(child: _buildResponseArea(aiState, theme)),
      ],
    );
  }

  Widget _buildResponseArea(AiState aiState, ThemeData theme) {
    if (aiState.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 8),
            Text(
              aiState.error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (aiState.response.isEmpty && !aiState.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tap "Summarize Page" or ask a question\nto get AI-powered insights.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(127),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            aiState.response,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (aiState.isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  // ── Handlers ─────────────────────────────────────────────────

  void _handleGoogleSignIn() {
    ref.read(aiProvider.notifier).signInWithGoogle();
  }

  Future<void> _handleSummarize() async {
    final pageText = await widget.onExtractPageText();
    ref.read(aiProvider.notifier).summarize(pageText);
  }

  Future<void> _handleAsk() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    final pageText = await widget.onExtractPageText();
    ref.read(aiProvider.notifier).ask(pageText, question);
    _questionController.clear();
  }
}

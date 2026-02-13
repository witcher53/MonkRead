import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls whether the drawing toolbar is visible on screen.
class ToolbarVisibilityNotifier extends StateNotifier<bool> {
  ToolbarVisibilityNotifier() : super(true);

  void toggle() => state = !state;
  void show() => state = true;
  void hide() => state = false;
}

final toolbarVisibilityProvider =
    StateNotifierProvider<ToolbarVisibilityNotifier, bool>((ref) {
  return ToolbarVisibilityNotifier();
});

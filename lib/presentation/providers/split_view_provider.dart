import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/domain/entities/drawing_state.dart';

/// Controls split-screen layout state.
class SplitViewState {
  final SplitViewMode mode;

  /// Width ratio of the left (primary) panel. 0.0–1.0.
  final double splitRatio;

  /// File path for the secondary PDF in dual-view mode.
  final String? secondaryFilePath;

  const SplitViewState({
    this.mode = SplitViewMode.none,
    this.splitRatio = 0.5,
    this.secondaryFilePath,
  });

  SplitViewState copyWith({
    SplitViewMode? mode,
    double? splitRatio,
    String? secondaryFilePath,
    bool clearSecondary = false,
  }) {
    return SplitViewState(
      mode: mode ?? this.mode,
      splitRatio: splitRatio ?? this.splitRatio,
      secondaryFilePath:
          clearSecondary ? null : (secondaryFilePath ?? this.secondaryFilePath),
    );
  }
}

class SplitViewNotifier extends StateNotifier<SplitViewState> {
  SplitViewNotifier() : super(const SplitViewState());

  void toggleDualPdf() {
    if (state.mode == SplitViewMode.dualPdf) {
      state = state.copyWith(mode: SplitViewMode.none, clearSecondary: true);
    } else {
      state = state.copyWith(mode: SplitViewMode.dualPdf);
    }
  }

  void toggleSidecar() {
    if (state.mode == SplitViewMode.sidecar) {
      state = state.copyWith(mode: SplitViewMode.none);
    } else {
      state = state.copyWith(mode: SplitViewMode.sidecar);
    }
  }

  void closeSplitView() {
    state = state.copyWith(mode: SplitViewMode.none, clearSecondary: true);
  }

  void setSplitRatio(double ratio) {
    state = state.copyWith(splitRatio: ratio.clamp(0.2, 0.8));
  }

  void setSecondaryFile(String filePath) {
    state = state.copyWith(secondaryFilePath: filePath);
  }
}

final splitViewProvider =
    StateNotifierProvider<SplitViewNotifier, SplitViewState>((ref) {
  return SplitViewNotifier();
});

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waktu_tugas/app/theme.dart';

void main() {
  test('normal text and control boundaries meet their contrast roles', () {
    double contrast(Color foreground, Color background) {
      final a = foreground.computeLuminance(),
          b = background.computeLuminance();
      return ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
    }

    for (final background in [
      AppColors.canvas,
      AppColors.surface,
      AppColors.surfaceMuted,
    ]) {
      for (final text in [
        AppColors.ink,
        AppColors.inkSecondary,
        AppColors.inkMuted,
      ]) {
        expect(contrast(text, background), greaterThanOrEqualTo(4.5));
      }
      expect(
        contrast(AppColors.borderStrong, background),
        greaterThanOrEqualTo(3),
      );
    }
    for (final pair in [
      (AppColors.surface, AppColors.primary),
      (AppColors.ink, AppColors.lime),
      (AppColors.lime, AppColors.forest),
      (AppColors.onForest, AppColors.forest),
      (AppColors.surface, AppColors.forest),
      (AppColors.primaryDark, AppColors.primarySoft),
      (AppColors.success, AppColors.successSoft),
      (AppColors.warningInk, AppColors.warningSoft),
      (AppColors.error, AppColors.errorSoft),
    ]) {
      expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  });
}

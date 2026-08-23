import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/app_colors.dart';

void main() {
  test('primaryHex is the CSS notation of primary', () {
    expect(AppColors.primaryHex, '#0061C2');
  });

  test('derived tints keep primary\'s RGB', () {
    for (final c in [AppColors.primarySelected, AppColors.primaryIndicator]) {
      expect(c.toARGB32() & 0xFFFFFF, AppColors.primary.toARGB32() & 0xFFFFFF);
    }
  });
}

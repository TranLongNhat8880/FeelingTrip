// ================================================================================
// CÁC GIÁ TRỊ KÍCH THƯỚC DÙNG CHUNG
// ================================================================================
// Padding, margin, border radius, font size,...
// Dùng để đảm bảo giao diện đồng nhất toàn app.
//
// Cách dùng:
//   padding: EdgeInsets.all(AppSizes.paddingM)
//   borderRadius: BorderRadius.circular(AppSizes.radiusM)
// ================================================================================

class AppSizes {
  AppSizes._();

  // === Padding & Margin ===
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // === Border Radius ===
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusRound = 100.0;

  // === Icon Size ===
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;

  // === Spacing (khoảng cách giữa các phần tử) ===
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
}

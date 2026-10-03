// ================================================================================
// ĐƯỜNG DẪN TÀI NGUYÊN (Assets)
// ================================================================================
// Chứa đường dẫn đến ảnh, icon, animation trong thư mục assets/
//
// Cách dùng:
//   Image.asset(AppAssets.logo)
//   Image.asset(AppAssets.placeholderTrip)
// ================================================================================

class AppAssets {
  AppAssets._();

  // === Images ===
  static const String logo = 'assets/images/logo.png';
  static const String placeholderTrip = 'assets/images/placeholder_trip.png';
  static const String placeholderAvatar =
      'assets/images/placeholder_avatar.png';
  static const String emptyState = 'assets/images/empty_state.png';

  // === Icons (nếu dùng icon custom) ===
  // static const String iconTrip = 'assets/icons/ic_trip.svg';
}

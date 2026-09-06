import 'package:intl/intl.dart';

// ================================================================================
// HÀM TIỆN ÍCH DÙNG CHUNG
// ================================================================================
// Format ngày, tiền, validate email,...
//
// Cách dùng:
//   AppUtils.formatDate(DateTime.now())     → "06/09/2026"
//   AppUtils.formatCurrency(1500000)        → "1.500.000 ₫"
//   AppUtils.isValidEmail("abc@gmail.com")  → true
// ================================================================================

class AppUtils {
  AppUtils._();

  /// Format ngày: 06/09/2026
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format ngày + giờ: 06/09/2026 14:30
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  /// Format tiền Việt: 1.500.000 ₫
  static String formatCurrency(num amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} ₫';
  }

  /// Validate email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate mật khẩu (tối thiểu 6 ký tự)
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Tính số ngày giữa 2 ngày
  static int daysBetween(DateTime from, DateTime to) {
    return to.difference(from).inDays;
  }

  /// Rút gọn text dài (ví dụ: "Đà Nẵng - Hội An - Huế..." → "Đà Nẵng - Hội An...")
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

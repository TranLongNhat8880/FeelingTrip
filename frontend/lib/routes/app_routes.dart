import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/admin/views/admin_screen.dart';
import '../features/auth/views/auth_gate.dart';
import '../features/auth/views/register_screen.dart';
import '../features/auth/views/terms_screen.dart';
import '../features/companion/views/companion_feed_screen.dart';
import '../features/companion/views/companion_requests_screen.dart';
import '../features/companion/views/create_companion_post_screen.dart';
import '../features/map/views/admin_place_management_screen.dart';
import '../features/map/views/place_list_screen.dart';
import '../features/trip/views/trip_list_screen.dart';
import '../shared/gallery/ui_kit_gallery_screen.dart';
import '../shared/widgets/feature_placeholder_screen.dart';

// ================================================================================
// QUẢN LÝ ROUTES TẬP TRUNG
// ================================================================================
// Mọi tên route và mapping đều nằm ở đây.
// Khi thêm màn hình mới:
//   1. Thêm tên route static const
//   2. Thêm mapping trong Map<String, WidgetBuilder> routes
//   3. Import screen ở đầu file
// ================================================================================

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String terms = '/terms';
  static const String tripList = '/trips';
  static const String tripDetail = '/trips/detail';
  static const String createTrip = '/trips/create';
  static const String profile = '/profile';
  static const String uiKit = '/ui-kit';
  static const String places = '/places';
  static const String adminPlaces = '/admin/places';
  static const String admin = '/admin';

  // Companion routes
  static const String companionFeed = '/companions';
  static const String companions = '/companions';
  static const String companionRequests = '/companions/requests';
  static const String createCompanionPost = '/companions/create';

  // Smart utilities
  static const String aiPlanner = '/ai-planner';
  static const String expenses = '/expenses';

  // Mapping route → screen
  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const AuthGate(),
    login: (context) => const AuthGate(),
    register: (context) => const RegisterScreen(),
    terms: (context) => const TermsScreen(),
    tripList: (context) => const TripListScreen(),
    companionFeed: (context) => const CompanionFeedScreen(),
    companionRequests: (context) => const CompanionRequestsScreen(),
    createCompanionPost: (context) => const CreateCompanionPostScreen(),
    places: (context) => const PlaceListScreen(),
    aiPlanner: (context) => const FeaturePlaceholderScreen(
      title: 'AI Travel Planner',
      featureName: 'Lên lịch trình thông minh cùng AI',
      description:
          'Hệ thống gợi ý lộ trình, dự toán ngân sách và tối ưu điểm đến du lịch cá nhân hóa bằng Google Gemini AI.',
      owner: 'Nhóm AI',
      icon: Icons.auto_awesome_rounded,
    ),
    expenses: (context) => const FeaturePlaceholderScreen(
      title: 'Sổ quỹ & Chia tiền',
      featureName: 'Quản lý chi tiêu & Split Bill',
      description:
          'Tự động tối ưu hóa công nợ nhóm (Min Cash Flow) và tạo mã VietQR thanh toán tức thì.',
      owner: 'Long Nhật',
      icon: Icons.account_balance_wallet_rounded,
    ),
    if (kDebugMode) admin: (context) => const AdminScreen(),
    if (kDebugMode)
      adminPlaces: (context) => const AdminPlaceManagementScreen(),
    if (kDebugMode) uiKit: (context) => const UiKitGalleryScreen(),
  };
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/auth/views/auth_gate.dart';
import '../features/auth/views/register_screen.dart';
import '../features/auth/views/terms_screen.dart';
import '../features/map/views/admin_place_management_screen.dart';
import '../features/map/views/place_list_screen.dart';
import '../shared/gallery/ui_kit_gallery_screen.dart';

// import '../features/trip/views/trip_detail_screen.dart';
// import '../features/trip/views/create_trip_screen.dart';
// import '../features/profile/views/profile_screen.dart';

import '../features/companion/views/companion_feed_screen.dart';
import '../features/companion/views/companion_requests_screen.dart';
import '../features/companion/views/create_companion_post_screen.dart';

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
  // Tên route (dùng trong Navigator)
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

  // Companion routes
  static const String companionFeed = '/companions';
  static const String companionRequests = '/companions/requests';
  static const String createCompanionPost = '/companions/create';

  // Mapping route → screen
  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const AuthGate(),
    login: (context) => const AuthGate(),
    register: (context) => const RegisterScreen(),
    terms: (context) => const TermsScreen(),
    tripList: (context) => const AuthGate(),
    companionFeed: (context) => const CompanionFeedScreen(),
    companionRequests: (context) => const CompanionRequestsScreen(),
    createCompanionPost: (context) => const CreateCompanionPostScreen(),
    places: (context) => const PlaceListScreen(),
    if (kDebugMode)
      adminPlaces: (context) => const AdminPlaceManagementScreen(),
    if (kDebugMode) uiKit: (context) => const UiKitGalleryScreen(),
  };
}

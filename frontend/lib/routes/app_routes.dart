import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/admin/views/admin_screen.dart';
import '../features/auth/views/auth_gate.dart';
import '../features/auth/views/register_screen.dart';
import '../features/auth/views/terms_screen.dart';
import '../features/companion/views/companion_feed_screen.dart';
import '../features/companion/views/companion_requests_screen.dart';
import '../features/companion/views/create_companion_post_screen.dart';
import '../features/itinerary/repositories/itinerary_repository.dart';
import '../features/itinerary/views/itinerary_screen.dart';
import '../features/itinerary/views/public_itineraries_screen.dart';
import '../features/map/views/place_list_screen.dart';
import '../features/profile/views/profile_screen.dart';
import '../features/trip/models/trip_model.dart';
import '../features/trip/repositories/trip_repository.dart';
import '../features/trip/views/trip_detail_screen.dart';
import '../features/trip/views/trip_form_screen.dart';
import '../features/trip/views/trip_invitations_screen.dart';
import '../features/trip/views/trip_list_screen.dart';
import '../shared/gallery/ui_kit_gallery_screen.dart';
import '../shared/widgets/feature_placeholder_screen.dart';

// ================================================================================
// QUẢN LÝ ROUTES TẬP TRUNG
// ================================================================================

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String terms = '/terms';
  static const String tripList = '/trips';
  static const String tripDetail = '/trips/detail';
  static const String createTrip = '/trips/create';
  static const String tripInvitations = '/trips/invitations';
  static const String itinerary = '/itineraries';
  static const String publicItineraries = '/itineraries/public';
  static const String profile = '/profile';
  static const String uiKit = '/ui-kit';
  static const String places = '/places';
  static const String admin = '/admin';

  // Companion routes
  static const String companionFeed = '/companions';
  static const String companions = '/companions';
  static const String companionRequests = '/companions/requests';
  static const String createCompanionPost = '/companions/create';

  // Smart utilities
  static const String aiPlanner = '/ai-planner';
  static const String expenses = '/expenses';

  // Static routes (không cần truyền arguments)
  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const AuthGate(),
    login: (context) => const AuthGate(),
    register: (context) => const RegisterScreen(),
    terms: (context) => const TermsScreen(),
    tripList: (context) => const TripListScreen(),
    publicItineraries: (context) => const PublicItinerariesScreen(),
    tripInvitations: (context) => const TripInvitationsScreen(),
    companionFeed: (context) => const CompanionFeedScreen(),
    companionRequests: (context) => const CompanionRequestsScreen(),
    places: (context) => const PlaceListScreen(),
    profile: (context) => const ProfileScreen(),
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
    if (kDebugMode) uiKit: (context) => const UiKitGalleryScreen(),
  };

  /// Xử lý các routes có truyền tham số động (arguments) hoặc fallback
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case tripDetail:
        {
          final args = settings.arguments;
          String? tripId;
          TripRepository? repository;
          if (args is String) {
            tripId = args;
          } else if (args is TripModel) {
            tripId = args.id;
          } else if (args is Map) {
            tripId = args['tripId'] as String? ?? args['id'] as String?;
            repository = args['repository'] as TripRepository?;
          }
          if (tripId == null || tripId.isEmpty) {
            return _errorRoute('Thiếu mã chuyến đi (tripId).');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) =>
                TripDetailScreen(tripId: tripId!, repository: repository),
          );
        }

      case itinerary:
        {
          final args = settings.arguments;
          String? tripId;
          String? destination;
          ItineraryRepository? repository;
          if (args is String) {
            tripId = args;
          } else if (args is Map) {
            tripId = args['tripId'] as String? ?? args['id'] as String?;
            destination = args['destination'] as String?;
            repository = args['repository'] as ItineraryRepository?;
          }
          if (tripId == null || tripId.isEmpty) {
            return _errorRoute(
              'Thiếu mã chuyến đi (tripId) để xem lịch trình.',
            );
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ItineraryScreen(
              tripId: tripId!,
              destination: destination ?? '',
              repository: repository,
            ),
          );
        }

      case createTrip:
        {
          final args = settings.arguments;
          TripModel? trip;
          TripRepository? repository;
          if (args is TripModel) {
            trip = args;
          } else if (args is Map) {
            trip = args['trip'] as TripModel?;
            repository = args['repository'] as TripRepository?;
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => TripFormScreen(trip: trip, repository: repository),
          );
        }

      case tripInvitations:
        {
          final args = settings.arguments;
          TripRepository? repository;
          if (args is TripRepository) {
            repository = args;
          } else if (args is Map) {
            repository = args['repository'] as TripRepository?;
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => TripInvitationsScreen(repository: repository),
          );
        }

      case publicItineraries:
        {
          final args = settings.arguments;
          String? destination;
          ItineraryRepository? repository;
          if (args is String) {
            destination = args;
          } else if (args is Map) {
            destination = args['destination'] as String?;
            repository = args['repository'] as ItineraryRepository?;
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PublicItinerariesScreen(
              initialDestination: destination,
              repository: repository,
            ),
          );
        }

      case createCompanionPost:
        {
          final args = settings.arguments;
          String? tripId;
          String? tripName;
          String? tripDestination;
          if (args is Map) {
            tripId = args['tripId'] as String?;
            tripName = args['tripName'] as String?;
            tripDestination = args['tripDestination'] as String?;
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => CreateCompanionPostScreen(
              tripId: tripId,
              tripName: tripName,
              tripDestination: tripDestination,
            ),
          );
        }

      default:
        return null;
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Lỗi điều hướng')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

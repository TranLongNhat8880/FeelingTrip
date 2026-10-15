import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/auth/views/terms_screen.dart';
import 'package:feeling_trip/features/review/views/emergency_contacts_screen.dart';
import 'package:feeling_trip/features/trip/models/trip_model.dart';
import 'package:feeling_trip/features/trip/repositories/mock_trip_repository.dart';
import 'package:feeling_trip/features/trip/views/trip_detail_screen.dart';

class OngoingTrip extends MockTripRepository {
  @override
  Future<TripModel> getTripById(String id) async => TripModel(
    id: id,
    name: 'Chuyến đang diễn ra',
    destination: 'Hà Nội',
    startDate: DateTime(2026, 10, 14),
    endDate: DateTime(2026, 10, 17),
    estimatedBudget: 0,
    privacyType: 'PUBLIC',
    status: 'ONGOING',
    membershipStatus: 'ACTIVE',
  );
}

void main() {
  testWidgets('ongoing trip no longer offers the retired emergency alert', (
    tester,
  ) async {
    final auth = AuthViewModel();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      AuthScope(
        auth: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: TripDetailScreen(tripId: 'trip', repository: OngoingTrip()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chuyến đang diễn ra'), findsNWidgets(2));
    expect(find.text('SOS'), findsNothing);
    expect(find.byIcon(Icons.sos), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('emergency contacts management remains usable independently', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final previous = ApiClient.client;
    final mock = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/reviews/emergency-contacts'));
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 'contact', 'fullName': 'Người thân', 'phone': '0912345678'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    ApiClient.client = mock;
    addTearDown(() {
      ApiClient.client = previous;
      mock.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const EmergencyContactsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Người thân'), findsOneWidget);
    expect(find.text('Thêm liên hệ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('terms no longer advertise removed alert functionality', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const TermsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SOS'), findsNothing);
    expect(find.text('Lịch trình AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

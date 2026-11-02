import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/network/storage_helper.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/auth/repositories/api_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client originalClient;
  late AuthViewModel auth;
  final user = {
    'id': 'google-user',
    'email': 'test@gmail.com',
    'fullName': 'Google Test',
    'isVerified': false,
    'verificationStatus': 'UNVERIFIED',
  };
  http.Response success() => http.Response(
    jsonEncode({
      'success': true,
      'data': {'token': 'app-session-token', 'user': user},
    }),
    200,
  );
  http.Response needsTerms() => http.Response(
    jsonEncode({
      'success': false,
      'code': 'GOOGLE_TERMS_REQUIRED',
      'message': 'Đồng ý điều khoản',
    }),
    409,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalClient = ApiClient.client;
    auth = AuthViewModel(repository: ApiAuthRepository());
  });
  tearDown(() {
    auth.dispose();
    ApiClient.client = originalClient;
  });

  test(
    'Google sign-in exchanges ID token for app session and retains unverified eKYC',
    () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/google'));
        expect(jsonDecode(request.body), {'idToken': 'provider-token'});
        return success();
      });
      expect(
        await auth.googleLogin(
          'provider-token',
          acceptTerms: () async => fail('Existing user does not need terms'),
          termsVersion: '1.0',
        ),
        true,
      );
      expect(auth.user!.id, 'google-user');
      expect(auth.user!.hasVerifiedEkyc, false);
      expect(await StorageHelper.getToken(), 'app-session-token');
    },
  );

  test(
    'new account retries only after explicit consent, without sending a forged profile',
    () async {
      var requests = 0;
      var asked = 0;
      ApiClient.client = MockClient((request) async {
        requests++;
        final body = jsonDecode(request.body);
        expect(body.containsKey('email'), false);
        expect(body.containsKey('role'), false);
        if (requests == 1) return needsTerms();
        expect(body, {
          'idToken': 'provider-token',
          'termsAccepted': true,
          'termsVersion': '1.0',
        });
        return success();
      });
      expect(
        await auth.googleLogin(
          'provider-token',
          acceptTerms: () async {
            asked++;
            return true;
          },
          termsVersion: '1.0',
        ),
        true,
      );
      expect(requests, 2);
      expect(asked, 1);
    },
  );

  test(
    'declining terms leaves no session and performs no registration retry',
    () async {
      var requests = 0;
      ApiClient.client = MockClient((_) async {
        requests++;
        return needsTerms();
      });
      expect(
        await auth.googleLogin(
          'provider-token',
          acceptTerms: () async => false,
          termsVersion: '1.0',
        ),
        false,
      );
      expect(requests, 1);
      expect(auth.isLoggedIn, false);
      expect(auth.isLoading, false);
      expect(await StorageHelper.getToken(), null);
    },
  );

  test(
    'provider/server rejection is shown and never creates a local session',
    () async {
      ApiClient.client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Tài khoản đã bị khóa',
            'code': 'ACCOUNT_BANNED',
          }),
          403,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      expect(
        await auth.googleLogin(
          'provider-token',
          acceptTerms: () async => true,
          termsVersion: '1.0',
        ),
        false,
      );
      expect(auth.errorMessage, 'Tài khoản đã bị khóa');
      expect(auth.isLoggedIn, false);
      expect(await StorageHelper.getToken(), null);
    },
  );

  test(
    'second login attempt cannot overlap a pending Google sign-in',
    () async {
      var requests = 0;
      ApiClient.client = MockClient((_) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return success();
      });
      final first = auth.googleLogin(
        'provider-token',
        acceptTerms: () async => true,
        termsVersion: '1.0',
      );
      expect(
        await auth.googleLogin(
          'another-token',
          acceptTerms: () async => true,
          termsVersion: '1.0',
        ),
        false,
      );
      expect(await first, true);
      expect(requests, 1);
    },
  );
}

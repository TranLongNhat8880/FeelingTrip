import 'package:feeling_trip/features/map/repositories/place_search_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(dotenv.clean);

  testWidgets('loads the .env asset at app startup', (tester) async {
    await dotenv.load(fileName: '.env');

    expect(dotenv.isInitialized, isTrue);
    expect(dotenv.env.containsKey('GEOAPIFY_API_KEY'), isTrue);
  });

  test('reads the map key from dotenv without a dart-define', () {
    dotenv.loadFromString(envString: 'GEOAPIFY_API_KEY=test-client-key');

    expect(PlaceSearchRepository().isConfigured, isTrue);
  });

  test('an empty map key disables map search with a useful message', () async {
    dotenv.loadFromString(envString: 'GEOAPIFY_API_KEY=');
    final repository = PlaceSearchRepository();

    expect(repository.isConfigured, isFalse);
    await expectLater(
      repository.searchPlaces('Ha Noi'),
      throwsA(
        isA<PlaceSearchException>().having(
          (error) => error.message,
          'message',
          contains('frontend/.env'),
        ),
      ),
    );
  });

  test('a missing map key is treated as unconfigured', () {
    dotenv.loadFromString(envString: 'OTHER_CONFIG=test');

    expect(PlaceSearchRepository().isConfigured, isFalse);
  });
}

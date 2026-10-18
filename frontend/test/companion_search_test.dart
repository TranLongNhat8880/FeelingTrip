import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/features/companion/views/companion_search_screen.dart';

void main() {
  test('destination suggestions match accents, case and short prefixes', () {
    final names = suggestCompanionDestinations(' HA ', const []);
    expect(names, containsAll(['Hà Nội', 'Hà Nam', 'Hạ Long']));
    expect(
      suggestCompanionDestinations('hà n', const []),
      containsAll(['Hà Nội', 'Hà Nam']),
    );
    expect(
      suggestCompanionDestinations('da nang', const []),
      contains('Đà Nẵng'),
    );
    expect(
      suggestCompanionDestinations('khong-co-diem-den', const []),
      isEmpty,
    );
  });
  test(
    'destinations from posts are included and accent variants are deduplicated',
    () {
      final names = suggestCompanionDestinations('ha', [
        'Hà Nội',
        'Ha Noi',
        'Hang Múa',
      ]);
      expect(
        names.where((n) => normalizeDestination(n) == 'ha noi'),
        hasLength(1),
      );
      expect(names, contains('Hang Múa'));
      expect(names.length, lessThanOrEqualTo(8));
    },
  );
}

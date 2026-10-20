import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/features/profile/models/cccd_qr_model.dart';

void main() {
  group('CccdQrModel Tests', () {
    test('Parses standard 7-part CCCD QR code with old ID', () {
      const raw =
          '001201012345|013589123|NGUYEN VAN A|15082001|Nam|Số 10 Phố Huế, Hoàn Kiếm, Hà Nội|10112021';
      final model = CccdQrModel.parse(raw);

      expect(model, isNotNull);
      expect(model!.cccdNumber, '001201012345');
      expect(model.oldIdNumber, '013589123');
      expect(model.fullName, 'NGUYEN VAN A');
      expect(model.formattedDob, '15/08/2001');
      expect(model.gender, 'Nam');
      expect(model.address, 'Số 10 Phố Huế, Hoàn Kiếm, Hà Nội');
      expect(model.formattedIssueDate, '10/11/2021');
    });

    test('Parses CCCD QR code with empty old ID and Vietnamese UTF-8 names', () {
      const raw =
          '079099001234||TRẦN LONG NHẬT|20102002|Nam|123 Nguyễn Văn Cừ, Quận 5, TP.HCM|15042021';
      final model = CccdQrModel.parse(raw);

      expect(model, isNotNull);
      expect(model!.cccdNumber, '079099001234');
      expect(model.oldIdNumber, isNull);
      expect(model.fullName, 'TRẦN LONG NHẬT');
      expect(model.formattedDob, '20/10/2002');
      expect(model.gender, 'Nam');
      expect(model.address, '123 Nguyễn Văn Cừ, Quận 5, TP.HCM');
      expect(model.formattedIssueDate, '15/04/2021');
    });

    test('Parses 6-part CCCD QR code without issue date', () {
      const raw = '038095012345||LÊ THỊ BÍCH HÀ|05121995|Nữ|Thái Bình';
      final model = CccdQrModel.parse(raw);

      expect(model, isNotNull);
      expect(model!.cccdNumber, '038095012345');
      expect(model.oldIdNumber, isNull);
      expect(model.fullName, 'LÊ THỊ BÍCH HÀ');
      expect(model.formattedDob, '05/12/1995');
      expect(model.gender, 'Nữ');
      expect(model.address, 'Thái Bình');
      expect(model.formattedIssueDate, '');
    });

    test('Rejects invalid format with fewer than 6 parts', () {
      expect(CccdQrModel.parse('001201012345|NGUYEN VAN A'), isNull);
      expect(CccdQrModel.parse('https://example.com/qr-code'), isNull);
      expect(CccdQrModel.parse(''), isNull);
    });

    test('Rejects invalid CCCD numbers with letters or incorrect length', () {
      expect(
        CccdQrModel.parse('00120101ABCD||NGUYEN VAN A|15082001|Nam|Hà Nội|10112021'),
        isNull,
      );
      expect(
        CccdQrModel.parse('12345||NGUYEN VAN A|15082001|Nam|Hà Nội|10112021'),
        isNull,
      );
    });
  });
}

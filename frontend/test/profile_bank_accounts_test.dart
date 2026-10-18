import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/profile/models/bank_account_model.dart';
import 'package:feeling_trip/features/profile/models/profile_form_data.dart';
import 'package:feeling_trip/features/profile/models/profile_model.dart';
import 'package:feeling_trip/features/profile/repositories/profile_repository.dart';
import 'package:feeling_trip/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:feeling_trip/features/profile/views/bank_account_form_sheet.dart';
import 'package:feeling_trip/features/profile/views/bank_accounts_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

BankAccountModel account(String id, bool linked) => BankAccountModel(
  id: id,
  bankName: 'Test bank',
  accountNumber: '123456789',
  accountHolderName: 'NGUYEN VAN A',
  isLinked: linked,
  isDefault: linked,
);

class BankRepository extends Fake implements ProfileRepository {
  ProfileModel profile = ProfileModel.fromJson({
    'id': 'test-user',
    'email': 'test@example.invalid',
    'fullName': 'Tên giữ nguyên',
  });
  List<BankAccountModel> accounts = [];
  bool accountsFail = false;
  bool saveFail = false;
  bool linkFail = false;
  Completer<void>? saveGate;
  int saves = 0;
  ProfileFormData? submitted;
  BankHostedLink hosted = BankHostedLink(
    url: Uri.parse('https://my.sepay.vn/test'),
  );
  @override
  Future<ProfileModel> getProfile() async => profile;
  @override
  Future<List<BankAccountModel>> getBankAccounts() async {
    if (accountsFail) throw Exception('Unavailable');
    return accounts;
  }

  @override
  Future<ProfileModel> updateProfile({
    required ProfileFormData data,
    List<int>? avatarBytes,
    String? avatarFileName,
  }) async {
    saves++;
    submitted = data;
    await saveGate?.future;
    if (saveFail) throw Exception('Save failed');
    profile = ProfileModel.fromJson({
      'id': profile.id,
      'email': profile.email,
      'fullName': profile.fullName,
      ...data.toMultipartFields(),
    });
    return profile;
  }

  @override
  Future<BankHostedLink> createBankHostedLink({
    required BankLinkPurpose purpose,
    String? accountId,
  }) async {
    if (linkFail) {
      throw const FormatException(
        'Cần cấu hình webhook và IPN Bank Hub trước khi liên kết',
      );
    }
    return hosted;
  }
}

Future<ProfileViewModel> mount(
  WidgetTester tester,
  BankRepository repo, {
  Future<void> Function(Uri)? openUrl,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final vm = ProfileViewModel(repository: repo);
  addTearDown(vm.dispose);
  await vm.loadProfile();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BankAccountsScreen(viewModel: vm, openUrl: openUrl),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

Future<void> press(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(CustomButton, label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'merged bank card keeps masked display, reveal and upstream copy action',
    (tester) async {
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final repo = BankRepository()
        ..profile = ProfileModel.fromJson({
          'id': 'test-user',
          'email': 'test@example.invalid',
          'fullName': 'Tên giữ nguyên',
          'bankBin': '970422',
          'bankName': 'MB',
          'bankAccountNumber': '123456789',
          'bankAccountName': 'NGUYEN VAN A',
        });
      await mount(tester, repo);
      expect(find.text('•••• 6789'), findsOneWidget);
      expect(find.text('Tài khoản chính'), findsOneWidget);
      final reveal = find.byTooltip('Hiện số tài khoản');
      await tester.ensureVisible(reveal);
      await tester.tap(reveal);
      await tester.pumpAndSettle();
      expect(find.text('1234  5678  9'), findsOneWidget);
      await tester.tap(find.byTooltip('Sao chép số tài khoản'));
      await tester.pumpAndSettle();
      expect(copied, '123456789');
      expect(
        find.text('Thông tin trong hồ sơ · chưa xác nhận Bank Hub'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('bank-only update does not clear personal profile fields', () {
    const data = ProfileFormData.bankAccount(
      bankBin: '970422',
      bankName: 'MB',
      bankAccountNumber: '123456',
      bankAccountName: 'NGUYEN VAN A',
    );
    expect(data.toMultipartFields().keys.toSet(), {
      'bankBin',
      'bankName',
      'bankAccountNumber',
      'bankAccountName',
    });
  });

  test('hosted URL must be HTTPS on SePay without user info', () {
    for (final url in [
      'http://my.sepay.vn/test',
      'https://sepay.vn.evil.test/',
      'https://evilsepay.vn/',
      'https://name:pass@my.sepay.vn/',
    ]) {
      expect(
        () => BankHostedLink.fromJson({'hostedLinkUrl': url}),
        throwsFormatException,
      );
    }
    expect(
      BankHostedLink.fromJson({
        'hostedLinkUrl': 'https://my.sepay.vn/test',
      }).url.host,
      'my.sepay.vn',
    );
  });

  test('link confirmation needs a new active account, not unchanged data', () {
    final attempt = BankLinkAttempt(
      link: BankHostedLink(url: Uri.parse('https://my.sepay.vn/')),
      purpose: BankLinkPurpose.link,
      before: [account('a', true)],
    );
    expect(attempt.confirmedBy([account('a', true)]), isFalse);
    expect(
      attempt.confirmedBy([account('a', true), account('b', false)]),
      isFalse,
    );
    expect(
      attempt.confirmedBy([account('a', true), account('b', true)]),
      isTrue,
    );
  });

  test(
    'unlink/reactivate require target state transition; absence is not success',
    () {
      final link = BankHostedLink(url: Uri.parse('https://my.sepay.vn/'));
      final unlink = BankLinkAttempt(
        link: link,
        purpose: BankLinkPurpose.unlink,
        accountId: 'a',
        before: [account('a', true)],
      );
      expect(unlink.confirmedBy([]), isFalse);
      expect(
        unlink.confirmedBy([account('a', true), account('b', false)]),
        isFalse,
      );
      expect(unlink.confirmedBy([account('a', false)]), isTrue);
      final reactivate = BankLinkAttempt(
        link: link,
        purpose: BankLinkPurpose.reactivate,
        accountId: 'a',
        before: [account('a', false)],
      );
      expect(reactivate.confirmedBy([account('a', false)]), isFalse);
      expect(reactivate.confirmedBy([account('a', true)]), isTrue);
      final unchanged = BankLinkAttempt(
        link: link,
        purpose: BankLinkPurpose.unlink,
        accountId: 'a',
        before: [account('a', false)],
      );
      expect(unchanged.confirmedBy([account('a', false)]), isFalse);
    },
  );

  test('failed refresh cannot confirm using stale accounts', () async {
    final repo = BankRepository()..accounts = [account('a', true)];
    final vm = ProfileViewModel(repository: repo);
    addTearDown(vm.dispose);
    expect(await vm.loadBankAccounts(), isTrue);
    repo.accountsFail = true;
    expect(await vm.refreshAfterBankReturn(), isFalse);
    expect(vm.bankAccountsErrorMessage, isNotNull);
  });

  testWidgets('Bank Hub error does not hide manual bank form on mobile', (
    tester,
  ) async {
    await mount(tester, BankRepository()..accountsFail = true);
    expect(find.text('1. Thông tin nhận tiền'), findsOneWidget);
    await press(tester, 'Nhập tài khoản nhận tiền');
    expect(find.byType(BankAccountFormSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual save is displayed, unverified, and preserves unknown BIN',
    (tester) async {
      final repo = BankRepository()
        ..profile = ProfileModel.fromJson({
          'id': 'test-user',
          'email': 'test@example.invalid',
          'fullName': 'Tên giữ nguyên',
          'bankBin': '999999',
          'bankName': 'Existing bank',
        });
      await mount(tester, repo);
      await press(tester, 'Nhập tài khoản nhận tiền');
      await tester.enterText(find.byType(TextFormField).at(0), '123456789');
      await tester.enterText(find.byType(TextFormField).at(1), 'nguyen van a');
      await press(tester, 'Lưu thông tin nhận tiền');
      expect(find.byType(BankAccountFormSheet), findsNothing);
      expect(repo.submitted!.toMultipartFields()['bankBin'], '999999');
      expect(repo.profile.fullName, 'Tên giữ nguyên');
      expect(find.text('NGUYEN VAN A'), findsOneWidget);
      expect(
        find.text('Thông tin trong hồ sơ · chưa xác nhận Bank Hub'),
        findsOneWidget,
      );
      expect(repo.accounts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid input and duplicate submit do not issue extra saves', (
    tester,
  ) async {
    final repo = BankRepository();
    await mount(tester, repo);
    await press(tester, 'Nhập tài khoản nhận tiền');
    await press(tester, 'Lưu thông tin nhận tiền');
    expect(repo.saves, 0);
    await tester.enterText(find.byType(TextFormField).at(0), '123456789');
    await tester.enterText(find.byType(TextFormField).at(1), 'NGUYEN VAN A');
    repo.saveGate = Completer<void>();
    final save = find.widgetWithText(CustomButton, 'Lưu thông tin nhận tiền');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(repo.saves, 1);
    expect(tester.widget<CustomButton>(save).onPressed, isNull);
    repo.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BankAccountFormSheet), findsNothing);
  });

  testWidgets('save failure keeps entered data and permits retry', (
    tester,
  ) async {
    final repo = BankRepository()..saveFail = true;
    await mount(tester, repo);
    await press(tester, 'Nhập tài khoản nhận tiền');
    await tester.enterText(find.byType(TextFormField).at(0), '123456789');
    await tester.enterText(find.byType(TextFormField).at(1), 'NGUYEN VAN A');
    await press(tester, 'Lưu thông tin nhận tiền');
    expect(find.byType(BankAccountFormSheet), findsOneWidget);
    expect(find.text('123456789'), findsOneWidget);
    repo.saveFail = false;
    await press(tester, 'Lưu thông tin nhận tiền');
    expect(repo.saves, 2);
    expect(find.byType(BankAccountFormSheet), findsNothing);
  });

  testWidgets('return unchanged stays pending; backend transition confirms', (
    tester,
  ) async {
    final repo = BankRepository();
    var opens = 0;
    await mount(
      tester,
      repo,
      openUrl: (_) async {
        opens++;
      },
    );
    await press(tester, 'Liên kết qua SePay');
    await press(tester, 'Mở SePay để liên kết');
    expect(opens, 1);
    await press(tester, 'Kiểm tra kết quả');
    expect(find.text('Chờ xác nhận từ Bank Hub'), findsOneWidget);
    expect(
      find.textContaining('Chưa nhận được thay đổi xác nhận'),
      findsOneWidget,
    );
    repo.accounts = [account('new', true)];
    await press(tester, 'Kiểm tra kết quả');
    expect(find.text('Chờ xác nhận từ Bank Hub'), findsNothing);
    expect(
      find.text('Backend đã xác nhận liên kết tài khoản.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired session cannot launch; closing is local only', (
    tester,
  ) async {
    final repo = BankRepository()
      ..hosted = BankHostedLink(
        url: Uri.parse('https://my.sepay.vn/test'),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
    var opens = 0;
    await mount(
      tester,
      repo,
      openUrl: (_) async {
        opens++;
      },
    );
    await press(tester, 'Liên kết qua SePay');
    expect(find.text('Phiên đã hết hạn'), findsOneWidget);
    expect(find.text('Mở SePay để liên kết'), findsNothing);
    await press(tester, 'Đóng phiên trên ứng dụng');
    expect(opens, 0);
    expect(repo.accounts, isEmpty);
    expect(
      find.textContaining('Không ngắt liên kết hoặc thu hồi URL'),
      findsOneWidget,
    );
  });

  testWidgets(
    'missing SePay config displays a local error, manual remains usable',
    (tester) async {
      await mount(tester, BankRepository()..linkFail = true);
      await press(tester, 'Liên kết qua SePay');
      expect(find.textContaining('Cần cấu hình webhook'), findsOneWidget);
      await press(tester, 'Nhập tài khoản nhận tiền');
      expect(find.byType(BankAccountFormSheet), findsOneWidget);
    },
  );

  testWidgets(
    'unlink waits for backend and does not unlink on session creation',
    (tester) async {
      final repo = BankRepository()..accounts = [account('a', true)];
      await mount(tester, repo);
      await press(tester, 'Ngắt liên kết');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(repo.accounts.single.isLinked, isTrue);
      await press(tester, 'Kiểm tra kết quả');
      expect(find.text('Chờ xác nhận từ Bank Hub'), findsOneWidget);
      repo.accounts = [account('a', false)];
      await press(tester, 'Kiểm tra kết quả');
      expect(find.text('Backend đã xác nhận ngắt liên kết.'), findsOneWidget);
      expect(find.text('Đã ngắt liên kết'), findsOneWidget);
    },
  );

  testWidgets(
    'reactivate requires target confirmation and supports desktop layout',
    (tester) async {
      final repo = BankRepository()..accounts = [account('a', false)];
      await mount(tester, repo, size: const Size(1280, 900));
      await press(tester, 'Kích hoạt lại');
      repo.accounts = [account('a', false), account('unrelated', true)];
      await press(tester, 'Kiểm tra kết quả');
      expect(find.text('Chờ xác nhận từ Bank Hub'), findsOneWidget);
      repo.accounts = [account('a', true)];
      await press(tester, 'Kiểm tra kết quả');
      expect(
        find.text('Backend đã xác nhận kích hoạt lại tài khoản.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed refresh keeps pending session; retry confirms later', (
    tester,
  ) async {
    final repo = BankRepository();
    await mount(tester, repo);
    await press(tester, 'Liên kết qua SePay');
    repo.accountsFail = true;
    await press(tester, 'Kiểm tra kết quả');
    expect(find.text('Chờ xác nhận từ Bank Hub'), findsOneWidget);
    expect(find.text('Backend đã xác nhận liên kết tài khoản.'), findsNothing);
    repo.accountsFail = false;
    repo.accounts = [account('a', true)];
    await press(tester, 'Kiểm tra kết quả');
    expect(
      find.text('Backend đã xác nhận liên kết tài khoản.'),
      findsOneWidget,
    );
  });
}

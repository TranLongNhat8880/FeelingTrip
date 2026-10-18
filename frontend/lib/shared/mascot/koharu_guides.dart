class KoharuStep {
  const KoharuStep(
    this.target,
    this.title,
    this.message, {
    this.advanceOnTap = false,
    this.waitForSave = false,
  });
  final String target;
  final String title;
  final String message;
  final bool advanceOnTap;
  final bool waitForSave;
}

class KoharuGuide {
  const KoharuGuide(this.title, this.description, this.steps);
  final String title;
  final String description;
  final List<KoharuStep> steps;
}

const _trips = KoharuStep(
  'home.trips',
  'Mục Chuyến đi',
  'Cậu chạm vào tab “Chuyến đi” này để xem các kế hoạch du lịch của tụi mình nha!',
  advanceOnTap: true,
);
const _manage = KoharuStep(
  'home.manage',
  'Danh sách chuyến đi',
  'Chạm vào đây để xem toàn bộ chuyến đi cậu đã tạo hoặc tham gia nè.',
  advanceOnTap: true,
);
const _open = KoharuStep(
  'trip.open',
  'Chọn một chuyến đi',
  'Cậu chọn chuyến đi muốn xem nha! Nếu chưa có chuyến nào, tụi mình tạo một chuyến mới trước nhé.',
  advanceOnTap: true,
);

const koharuGuides = [
  KoharuGuide('Tạo chuyến đi mới', 'Điểm đến, ngày khởi hành và chế độ riêng tư', [
    _trips,
    _manage,
    KoharuStep(
      'trip.create',
      'Bắt đầu chuyến đi mới',
      'Chạm vào “Tạo chuyến đi” nè! Tớ sẽ đi cùng và hỗ trợ cậu qua từng bước nha.',
      advanceOnTap: true,
    ),
    KoharuStep(
      'trip.destination',
      'Cậu muốn vi vu ở đâu nè?',
      'Nhập địa điểm cậu thích hoặc chọn trên bản đồ nhé. Tên chuyến đi cứ để app gợi ý cho nhanh nè!',
    ),
    KoharuStep(
      'trip.dates',
      'Chọn ngày đi và ngày về',
      'Cậu chọn ngày đi và ngày về nha! Lịch trình sẽ tự động được chia theo từng ngày cực kỳ tiện lợi đó.',
    ),
    KoharuStep(
      'trip.privacy',
      'Chế độ chuyến đi',
      'Mới tạo thì chuyến đi sẽ ở chế độ riêng tư cho nhóm cậu. Sau này nếu muốn tìm thêm bạn đồng hành ghép đoàn, cậu chỉ cần xác minh eKYC là mở tuyển công khai được ngay!',
    ),
    KoharuStep(
      'trip.save',
      'Sẵn sàng lên đường!',
      'Kiểm tra lại thông tin một lượt rồi chạm nút tạo nha. Tớ đang đợi cậu lưu thành công nè!',
      waitForSave: true,
    ),
  ]),
  KoharuGuide('Lập lịch trình chi tiết', 'Thêm điểm dừng chân, giờ giấc và dự kiến chi phí', [
    _trips,
    _manage,
    _open,
    KoharuStep(
      'trip.itinerary',
      'Mở xem lịch trình',
      'Mỗi ngày sẽ có các điểm vui chơi riêng biệt. Cậu chạm vào đây để xem và sắp xếp lộ trình nha!',
      advanceOnTap: true,
    ),
    KoharuStep(
      'itinerary.add',
      'Thêm điểm dừng mới',
      'Cậu chọn ngày muốn đi rồi chạm nút thêm điểm dừng chân này nhé!',
      advanceOnTap: true,
    ),
    KoharuStep(
      'itinerary.form',
      'Kế hoạch cho điểm này',
      'Chọn quán ăn, điểm check-in, kèm giờ bắt đầu và kết thúc nha. Cậu có thể điền trước chi phí dự tính để cả nhóm cùng nắm nè!',
    ),
    KoharuStep(
      'itinerary.save',
      'Lưu vào lịch trình',
      'Xong xuôi thì chạm “Thêm vào lịch trình” nha! Tớ đợi cậu lưu thành công nè.',
      waitForSave: true,
    ),
  ]),
  KoharuGuide('Sổ quỹ & Chia tiền (Split Bill)', 'Ghi nhận chi tiêu thực tế và quyết toán trả nợ tự động', [
    _trips,
    _manage,
    _open,
    KoharuStep(
      'trip.expenses',
      'Mở Sổ quỹ chuyến đi',
      'Chạm vào đây để xem toàn bộ chi tiêu và tiền quỹ của cả nhóm nè. Cực kỳ minh bạch luôn!',
      advanceOnTap: true,
    ),
    KoharuStep(
      'expense.add',
      'Ghi nhận khoản chi mới',
      'Vừa thanh toán tiền ăn hay tiền phòng xong thì cậu chạm vào đây để ghi lại ngay nha!',
      advanceOnTap: true,
    ),
    KoharuStep(
      'expense.form',
      'Khoản này ai trả thế nhỉ?',
      'Cậu nhập số tiền thực tế, chọn ai đã bỏ tiền túi ra trả và tích chọn những bạn cùng chia khoản này nha!',
    ),
    KoharuStep(
      'expense.save',
      'Lưu & Tối ưu hóa nợ',
      'Chạm lưu lại nè! App sẽ tự động chia tiền và tính đường chuyển khoản tối ưu nhất, hạn chế chuyển vòng vo nhiều lần.',
      waitForSave: true,
    ),
    KoharuStep(
      'expense.result',
      'Bảng trả nợ & Quét VietQR',
      'Đây là kết quả ai cần chuyển cho ai nè! Cậu chỉ cần bấm vào khoản nợ là hiện ngay mã VietQR chuẩn xác, quét phát trả xong liền, siêu tiện lợi!',
    ),
  ]),
  KoharuGuide('Tìm bạn đồng hành', 'Xem chuyến đi phù hợp và gửi yêu cầu ghép đoàn', [
    KoharuStep(
      'home.feed',
      'Bảng tin ghép đoàn',
      'Trang chủ là nơi quy tụ các bài tuyển bạn đồng hành nè! Chạm vào để xem các chuyến đi thú vị đang mở tuyển nha.',
      advanceOnTap: true,
    ),
    KoharuStep(
      'companion.open',
      'Xem chi tiết chuyến đi',
      'Cậu mở bài tuyển để xem thời gian, yêu cầu, chi phí dự kiến và lịch trình xem có hợp gu không nhé!',
      advanceOnTap: true,
    ),
    KoharuStep(
      'companion.plan',
      'Gửi lời chào ghép đoàn',
      'Xem xong các điểm đến và thành viên, nếu thấy thích thì cậu hoàn thành eKYC rồi bấm gửi yêu cầu tham gia nha. Trưởng nhóm sẽ duyệt để cậu cùng đi nè!',
    ),
  ]),
  KoharuGuide('Hồ sơ & Xác minh danh tính', 'Cập nhật tài khoản, liên kết ngân hàng và eKYC', [
    KoharuStep(
      'home.profile',
      'Khu vực cá nhân',
      'Thông tin tài khoản, cài đặt và số tài khoản ngân hàng của cậu đều nằm ở đây nè!',
      advanceOnTap: true,
    ),
    KoharuStep(
      'profile.open',
      'Mở hồ sơ cá nhân',
      'Chạm vào thẻ hồ sơ để cập nhật thông tin và kiểm tra xem tài khoản đã có Tích Xanh chưa nha!',
      advanceOnTap: true,
    ),
    KoharuStep(
      'profile.ekyc',
      'Xác minh CCCD (eKYC)',
      'Cậu chỉ cần quét mã QR trên CCCD để nhận Tích Xanh uy tín nè. Koharu đợi ở đây để cậu an tâm thao tác thông tin cá nhân nha!',
    ),
  ]),
];

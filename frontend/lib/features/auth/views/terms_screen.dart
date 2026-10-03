import '../../../shared/buttons/custom_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  static const version = '1.0';

  static const _sections = <(String, String, String?)>[
    (
      'Phạm vi dịch vụ',
      """FeelingTrip là nền tảng công nghệ hỗ trợ người dùng xây dựng lịch trình, quản lý chuyến đi cá nhân hoặc theo nhóm, tìm bạn đồng hành, ghi nhận chi phí và tính toán công nợ giữa các thành viên.

Các tính năng được cung cấp theo phiên bản đang triển khai thực tế. FeelingTrip không phải đơn vị lữ hành, đơn vị tổ chức tour, ngân hàng, trung gian thanh toán hoặc dịch vụ cứu hộ khẩn cấp.""",
      null,
    ),
    (
      'Tài khoản và xác thực email',
      """Người dùng có trách nhiệm cung cấp thông tin đăng ký chính xác, sử dụng email thuộc quyền kiểm soát của mình và hoàn tất xác thực email bằng mã OTP.

Tài khoản chưa xác thực email chưa được phép đăng nhập sử dụng các chức năng yêu cầu xác thực. Khi đăng nhập đúng email và mật khẩu, người dùng được chuyển đến màn hình xác thực để nhập mã hoặc yêu cầu gửi lại OTP theo giới hạn của hệ thống.

Người dùng có trách nhiệm bảo vệ mật khẩu, mã OTP và thiết bị đăng nhập; không chia sẻ tài khoản hoặc sử dụng tài khoản của người khác. Khi phát hiện truy cập trái phép, người dùng cần thông báo cho bộ phận hỗ trợ.""",
      null,
    ),
    (
      'Chuyến đi và trách nhiệm của thành viên',
      """Trưởng nhóm và các thành viên có trách nhiệm cung cấp thông tin trung thực về lịch trình, địa điểm, thời gian, ngân sách dự kiến và các thỏa thuận khi tham gia chuyến đi.

Việc tham gia chuyến đi không mặc nhiên cho phép một thành viên đại diện hoặc cam kết tài chính thay cho thành viên khác. Những thay đổi ảnh hưởng đến lịch trình, chi phí hoặc nghĩa vụ thanh toán cần được trao đổi và thống nhất giữa những người liên quan.

Người dùng có trách nhiệm tìm hiểu điều kiện thực tế, thời tiết, sức khỏe cá nhân, an toàn di chuyển và các quy định tại địa phương trước và trong hành trình.""",
      null,
    ),
    (
      'Xác minh danh tính (eKYC)',
      """Một số chức năng có thể yêu cầu xác minh danh tính theo điều kiện được FeelingTrip thông báo tại chức năng tương ứng. Người dùng phải cung cấp hồ sơ thuộc về mình, chính xác và không chỉnh sửa nhằm làm sai lệch thông tin.

Trạng thái “Đã xác minh” chỉ ghi nhận kết quả kiểm tra hồ sơ tại thời điểm xét duyệt; không phải sự bảo đảm về hành vi, độ tin cậy hoặc khả năng tài chính của người dùng.

Mục đích thu thập, phạm vi sử dụng và thời hạn lưu giữ dữ liệu xác minh được trình bày trong Chính sách bảo mật và thông báo trước khi người dùng gửi hồ sơ.""",
      null,
    ),
    (
      'Ngân sách, khoản chi và công nợ',
      """Ngân sách chuyến đi là số tiền dự kiến để theo dõi chi tiêu, không phải tiền được nạp, giữ hoặc phong tỏa tại FeelingTrip. Việc thay đổi ngân sách không làm thay đổi các khoản chi và công nợ đã ghi nhận.

Người ghi nhận khoản chi có trách nhiệm kiểm tra nội dung, số tiền, người đã trả, những người tham gia chia tiền và phương thức chia. Thông tin hoặc ảnh hóa đơn có thể được bổ sung nếu có; không được tạo chứng từ giả hoặc đăng tải thông tin nhạy cảm như mã bảo mật thẻ, mật khẩu hay mã OTP ngân hàng.

Phương án rút gọn công nợ xác định người trả, người nhận và số tiền cần thanh toán dựa trên dữ liệu hệ thống đã ghi nhận. Việc tính toán hoặc hiển thị công nợ không đồng nghĩa với việc khoản nợ đã được thanh toán.

FeelingTrip không giữ tiền và không bảo lãnh nghĩa vụ thanh toán giữa các thành viên. Người dùng có trách nhiệm kiểm tra khoản chi, phản ánh sai lệch và thực hiện nghĩa vụ theo thỏa thuận của mình.

Thành viên không được rời chuyến đi hoặc bị trưởng nhóm loại khỏi chuyến đi khi vẫn còn khoản phải trả, khoản được nhận hoặc thanh toán chưa hoàn tất theo kiểm tra của hệ thống.""",
      'Lưu ý quan trọng: FeelingTrip không giữ tiền, không đóng vai trò trung gian thanh toán và không bảo lãnh tài chính. Mọi giao dịch chuyển khoản diễn ra trực tiếp giữa các tài khoản ngân hàng của người dùng.',
    ),
    (
      'Thanh toán và xác nhận giao dịch tự động',
      """Người thanh toán thực hiện chuyển khoản bằng ứng dụng ngân hàng của mình đến tài khoản người nhận. Trước khi xác nhận chuyển khoản, người dùng phải kiểm tra tên người nhận, tài khoản nhận, số tiền và nội dung chuyển khoản trong mã VietQR.

FeelingTrip chỉ tự động ghi nhận khoản nợ “Đã thanh toán” sau khi tiếp nhận và đối chiếu thành công thông báo giao dịch hợp lệ từ SePay Bank Hub.

Trạng thái chuyển khoản tại ngân hàng có thể được cập nhật trước trạng thái trên FeelingTrip. Nếu ứng dụng chưa xác nhận, người dùng cần kiểm tra lịch sử giao dịch ngân hàng trước khi chuyển thêm lần nữa để tránh thanh toán trùng.

Giao dịch sai nội dung, sai số tiền, sai thông tin nhận tiền hoặc sử dụng mã khoản nợ đã bị hủy có thể không được tự động xác nhận. Người dùng cần liên hệ người nhận hoặc bộ phận hỗ trợ để đối soát.

FeelingTrip không giữ tiền nên không thể trực tiếp hoàn tiền hoặc hủy giao dịch chuyển khoản ngân hàng.""",
      null,
    ),
    (
      'Nội dung, đánh giá và hành vi bị nghiêm cấm',
      """Người dùng chỉ được đăng tải nội dung, hình ảnh và tài liệu mà mình có quyền sử dụng hợp pháp. Đánh giá và báo cáo phải trung thực, có liên quan đến trải nghiệm hoặc sự việc thực tế.

Các hành vi bị nghiêm cấm bao gồm:
• Giả mạo danh tính, hồ sơ xác minh, hóa đơn hoặc bằng chứng chuyển khoản.
• Thao túng khoản chi, công nợ hoặc thông tin thanh toán.
• Lừa đảo, quấy rối, đe dọa hoặc công khai trái phép thông tin cá nhân.
• Đăng tải nội dung trái pháp luật hoặc xâm phạm quyền của người khác.
• Báo cáo sai sự thật, lạm dụng chức năng chặn hoặc SOS để gây phiền nhiễu.
• Truy cập trái phép, khai thác lỗ hổng nhằm gây hại hoặc làm gián đoạn hệ thống.""",
      null,
    ),
    (
      'Lịch trình AI và chức năng SOS',
      """Lịch trình do trí tuệ nhân tạo gợi ý mang tính tham khảo. Người dùng cần kiểm tra lại địa điểm, giờ hoạt động, chi phí, điều kiện di chuyển và tính khả thi trước khi sử dụng.

Chức năng SOS hỗ trợ phát cảnh báo và chia sẻ thông tin cần trợ giúp theo phạm vi chức năng đang được cung cấp. Khả năng gửi và tiếp nhận cảnh báo phụ thuộc vào kết nối mạng, quyền truy cập vị trí và tình trạng hoạt động của các dịch vụ liên quan.

SOS không thay thế việc liên hệ cơ quan khẩn cấp hoặc lực lượng cứu hộ và không bảo đảm có người ứng cứu ngay lập tức. Trong tình huống nguy hiểm, người dùng cần chủ động liên hệ cơ quan có thẩm quyền hoặc người hỗ trợ phù hợp.

Không được cố ý tạo cảnh báo SOS giả hoặc sử dụng chức năng này để quấy rối người khác.""",
      'Cảnh báo an toàn: Tính năng SOS không thay thế cho các đầu số khẩn cấp quốc gia (113, 114, 115). Hãy ưu tiên liên hệ cơ quan chuyên trách trong tình huống nguy hiểm.',
    ),
    (
      'Xử lý vi phạm và hỗ trợ tranh chấp',
      """Tùy tính chất và mức độ vi phạm, FeelingTrip có thể yêu cầu bổ sung thông tin, xử lý nội dung, hạn chế chức năng, tạm khóa hoặc khóa tài khoản.

Người dùng có thể liên hệ bộ phận hỗ trợ để biết lý do xử lý và đề nghị xem xét lại, kèm thông tin hoặc bằng chứng liên quan.

Việc hạn chế hoặc khóa tài khoản không mặc nhiên xóa bỏ các khoản công nợ hay nghĩa vụ đã phát sinh giữa các thành viên.

Khi có tranh chấp, FeelingTrip hỗ trợ đối soát dữ liệu hệ thống để các bên làm căn cứ giải quyết.""",
      null,
    ),
    (
      'Quyền riêng tư và thay đổi điều khoản',
      """Việc thu thập, sử dụng, chia sẻ và lưu giữ dữ liệu cá nhân được trình bày trong Chính sách bảo mật của FeelingTrip.

Chấp nhận Điều khoản sử dụng không đồng nghĩa với việc cho phép mọi hoạt động xử lý dữ liệu. Các hoạt động cần sự đồng ý riêng sẽ được giải thích và xin ý kiến tại chức năng tương ứng.

FeelingTrip có thể cập nhật điều khoản để phù hợp với chức năng và yêu cầu vận hành. Mọi câu hỏi, phản ánh hoặc đề nghị hỗ trợ được tiếp nhận tại feelingtrip.official@gmail.com.""",
      null,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        'Điều khoản sử dụng',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Quay lại',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.pop(context, false),
      ),
    ),
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.documentMaxWidth,
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.cardRadius,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.description_outlined,
                                  color: AppColors.primary,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FeelingTrip',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Điều khoản sử dụng',
                                      style: TextStyle(
                                        fontSize: AppSizes.fontSmall,
                                        color: AppColors.primaryText,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Những điều cần biết trước khi bắt đầu hành trình cùng FeelingTrip.',
                            style: TextStyle(
                              fontSize: AppSizes.fontBody,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Phiên bản 1.0 · Dự thảo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  '10 mục điều khoản',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Hiệu lực dự kiến: 09/10/2026\nĐơn vị vận hành: FeelingTrip Team',
                            style: TextStyle(
                              fontSize: AppSizes.fontCaption,
                              color: AppColors.textSecondary,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < _sections.length; i++) ...[
                      _section(i),
                      const SizedBox(height: 12),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Hỗ trợ và phản hồi\nfeelingtrip.official@gmail.com',
                              style: TextStyle(
                                fontSize: AppSizes.fontCaption,
                                color: AppColors.textSecondary,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth - 40,
              ),
              child: SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Tôi đã đọc và đồng ý',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  static Widget _section(int index) {
    final section = _sections[index];
    final paragraphs = section.$2.split('\n\n');
    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: AppSizes.fontCaption,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    section.$1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(
              paragraphs[i],
              style: const TextStyle(
                fontSize: AppSizes.fontBody,
                height: 1.65,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

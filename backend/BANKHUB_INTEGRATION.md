# SePay Bank Hub và UC thanh toán tự động

Triển khai backend trên nhánh `nhat`. Luồng: người dùng mở Hosted Link, xác thực/đồng ý
trên giao diện Bank Hub; backend xác minh tài khoản qua API và lưu trạng thái liên kết.
Người trả quét VietQR bằng app ngân hàng; IPN hợp lệ cập nhật khoản nợ trực tiếp thành PAID.
Không cần người trả báo chuyển hoặc người nhận xác nhận trong luồng tự động.

## Thiết lập để chạy thật

1. Nhận quyền sử dụng Bank Hub cùng `client_id`, `client_secret` từ SePay.
   Cấu hình `BANKHUB_ENVIRONMENT=sandbox` trước khi kiểm thử; production dùng thông tin riêng.
2. Điền `BANKHUB_CLIENT_ID`, `BANKHUB_CLIENT_SECRET`, `BANKHUB_EVENT_SECRET`,
   `BANKHUB_IPN_KEY` vào môi trường server. Không gửi secret cho Flutter.
3. Chạy `npm run db:migrate` trên database ứng dụng sau khi kiểm tra môi trường kết nối.
   Migration 002 thêm các bảng riêng, không chuyển dữ liệu ngân hàng cũ thành đã liên kết.
4. Đăng ký webhook sự kiện `https://<host>/api/v1/users/me/bank/events` với kiểu
   `SECRET_KEY`, header `X-Secret-Key` bằng `BANKHUB_EVENT_SECRET`. Đăng ký các sự kiện
   BANK_ACCOUNT_LINKED, BANK_ACCOUNT_UNLINKED, BANK_ACCOUNT_REACTIVATED và sự kiện
   vô hiệu hóa được nhà cung cấp hỗ trợ (handler nhận cả INACTIVED/INACTIVATED).
5. Đăng ký IPN giao dịch `https://<host>/api/v1/users/me/bank/ipn` với SePay;
   `Authorization: Apikey <BANKHUB_IPN_KEY>`. Đây là cấu hình KHÁC webhook sự kiện.
6. `SEPAY_BANK_BINS` phải ánh xạ chính xác brand_name/gateway sang NAPAS BIN.
   Thiếu ánh xạ thì liên kết không được đánh dấu thành công.
7. SePay yêu cầu company Active, active=1 và hạn mức transaction_amount > 0 hoặc Unlimited
   để gửi IPN. Xác nhận điều kiện dịch vụ/quota với SePay; code không tự mua gói hoặc hạn mức.
8. Nếu dùng redirect, cấu hình `BANKHUB_REDIRECT_URI` là HTTPS được đăng ký cho app.
   Redirect chỉ để điều hướng, KHÔNG phải bằng chứng liên kết thành công.

Backend tạo company riêng cho từng user (tên kỹ thuật `FeelingTrip-<UUID>`), không cho
client tự khai báo company/user sở hữu tài khoản. Hosted Link mở luồng liên kết một tài khoản;
account mới liên kết thành công trở thành tài khoản nhận mặc định. Các snapshot ngân hàng
của khoản nợ đã tạo được giữ nguyên để tránh chuyển hướng tiền khi đổi ngân hàng.
Nếu snapshot không còn liên kết, API trạng thái không hiển thị QR tự động; không âm thầm đổi người nhận.

## API cho màn hình ngân hàng và thanh toán

Các API người dùng yêu cầu JWT thật; frontend hiện đang dùng MockAuthRepository.
Thay đăng nhập giả bằng API thật trước khi nối các màn hình này. Phần thay giao diện Flutter
không nằm trong thay đổi backend này.

| Method / đường dẫn | Input / kết quả |
| --- | --- |
| POST `/api/v1/users/me/bank/link` | `{}` hoặc `{purpose:"LINK_BANK_ACCOUNT"}` → data.hostedLinkUrl, expiresAt |
| POST cùng đường dẫn | `{purpose:"UNLINK_BANK_ACCOUNT",accountId:"UUID"}` mở luồng hủy của chính user |
| POST cùng đường dẫn | `{purpose:"REACTIVATE_BANK_ACCOUNT",accountId:"UUID"}` mở luồng khôi phục |
| GET `/api/v1/users/me/bank/accounts` | data là danh sách id, bankName, accountNumber, accountHolderName, isLinked, isDefault |
| GET `/api/v1/expenses/settlement/:id/status` | data gồm status, amount, vietqrUrl, automaticConfirmationAvailable, paidAt |

Màn hình Thêm tài khoản gọi POST link, mở hostedLinkUrl trong trình duyệt/WebView.
Không tự lưu số tài khoản nhập tay là đã liên kết. Khi quay lại, gọi GET accounts để xem kết quả;
nếu chưa có thì tiếp tục đợi webhook, không báo thành công chỉ vì WebView đóng.

Màn hình thanh toán đọc API status ngay khi mở, khi app resume và mỗi 3 giây lúc đang chờ.
Không gọi chồng request; dừng khi rời màn hình, đăng xuất, PAID hoặc CANCELLED. Khi PAID:
ẩn QR và hiển thị Đã thanh toán. CANCELLED: yêu cầu tải lại công nợ. Khi mất mạng:
hiện trạng thái chưa xác định và thử lại, không suy ra đã trả tiền.
Đây là cập nhật gần realtime qua polling, không phải server push/WebSocket.
Nếu automaticConfirmationAvailable=false thì hiển thị người nhận chưa có liên kết phù hợp.

## Tính nhất quán và phục hồi

- IPN chỉ ghi PAID khi tiền vào, đúng reference FT đầy đủ, số tiền, gateway, số tài khoản,
  tài khoản Bank Hub và user nhận. Khoản CANCELLED không được ghi nhận tự động.
- Dedupe theo transaction_id; transaction và khóa chuyến đi ngăn thanh toán/tính lại chạy đua.
- Thông báo đã xác thực được lưu trước xử lý. Sự kiện sai thứ tự/lỗi provider giữ pending.
- Server có worker thử lại mỗi 15 giây khi cấu hình Bank Hub đủ, backoff tối đa 1 giờ.
  Có thể chạy `node scripts/bankhub-replay.js` để xử lý lại pending ngay.
- IPN có result MISMATCH_REQUIRES_REVIEW hoặc CANCELLED_REQUIRES_REVIEW cần đối soát vận hành;
  không tự chia khoản chuyển thiếu/thừa hoặc ghi nhận nợ khác. Theo dõi bảng bankhub_ipn,
  bankhub_events cho bản ghi pending lâu. Worker không thay thế giám sát vận hành.
- Thông tin ngân hàng từ webhook phải được kiểm chứng qua API Bank Hub, company phải thuộc user.
- Endpoint SePay cũ và các API paid/confirm thủ công được giữ để tương thích, là nhánh riêng;
  chúng không được gọi trong luồng UC tự động mới. Chưa xóa lịch sử REPORTED/PAID cũ.

## UC chi tiết thay thế

File `docs/diagrams/FeelingTrip-UC-BankHub-ThanhToan.drawio` gồm hai trang:

1. Thanh toán: Trưởng nhóm kế thừa Thành viên chuyến đi; Thành viên nối Xem thông tin khoản nợ
   và mã VietQR, Theo dõi trạng thái thanh toán. SePay Bank Hub nối Tự động xác nhận thanh toán.
   Tự động xác nhận thanh toán include Đối chiếu giao dịch với khoản nợ. Không include giữa
   việc xem QR và nhận IPN: hai việc diễn ra bất đồng bộ.
2. Ngân hàng: Người dùng đã đăng nhập nối Liên kết, Xem trạng thái, Hủy, Khôi phục liên kết.
   Bank Hub tham gia các luồng liên kết/hủy/khôi phục và Cập nhật kết quả liên kết ngân hàng.

Phần liên kết nằm trong quản lý hồ sơ/ngân hàng (phối hợp Thành), phần thanh toán thuộc Nhật.
UC mô tả nghiệp vụ backend/API đã triển khai; không khẳng định đã có đủ màn hình frontend.

## Nguồn và giới hạn kiểm chứng

- https://developer.sepay.vn/vi/bankhub/bat-dau-nhanh
- https://developer.sepay.vn/vi/bankhub/api/link-token/tao-link-token
- https://developer.sepay.vn/vi/bankhub/api/cong-ty/tao-cong-ty
- https://developer.sepay.vn/vi/bankhub/api/tai-khoan-ngan-hang/chi-tiet-tai-khoan
- https://developer.sepay.vn/vi/bankhub/webhook-event
- https://developer.sepay.vn/vi/bankhub/thong-bao-bien-dong-so-du

Kiểm thử tích hợp dùng PostgreSQL tạm và provider giả lập theo hợp đồng API công khai.
Chưa thực hiện liên kết ngân hàng thật, chưa đăng ký webhook trên tài khoản SePay và chưa
chạy migration trên database ứng dụng. Cần kiểm thử sandbox của SePay với credentials thực
trước khi tuyên bố sẵn sàng chạy production.

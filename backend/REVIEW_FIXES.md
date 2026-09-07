# Backend nhat: các thay đổi và cách chạy

Code thuộc auth, expenses, ai-planner, shared/config/database và CI.
Các feature của Phú, Thành, Tùng vẫn do từng thành viên triển khai.

## Cập nhật database hiện có

1. Cập nhật code và dependencies: `npm ci --legacy-peer-deps`.
2. Điền `.env` theo `.env.example`.
3. Chạy `npm run db:migrate` trong backend trước khi chạy server mới.
4. Chạy `npm run check`, `npm test`, sau đó `npm run dev`.

Migration có transaction và bảng đánh dấu phiên bản, có thể chạy lại.
Không tự chạy migration khi server khởi động. Database mới có thể chạy
`database/schema.sql` rồi `npm run db:migrate`.
Token phát hành trước migration không có tokenVersion nên cần đăng nhập lại.
OTP mới lưu hash trong PostgreSQL, 5 phút, tối đa 5 lần thử, gửi lại sau 60 giây.
Mật khẩu mới tối thiểu 8 ký tự, tối đa 72 byte UTF-8 theo giới hạn bcrypt.
Đổi mật khẩu và khóa/mở khóa tài khoản thu hồi token cũ.

## Hợp đồng Expenses

Mọi số tiền mới là số nguyên VND. Dữ liệu cũ có phần lẻ hoặc công nợ không cân bằng
phải đối soát; hệ thống từ chối rút gọn thay vì tự làm tròn/xóa chênh lệch.

| Method | Endpoint (sau /api/v1/expenses) | Quyền / hành vi |
|---|---|---|
| POST | / | Thành viên; payerId và các splits phải thuộc nhóm |
| GET | /trip/:tripId | Thành viên; danh sách và tổng hợp ngân sách |
| GET | /trip/:tripId/balances | Thành viên; số dư đã tính tiền hoàn trả PAID |
| PUT | /trip/:tripId/budget | Creator/LEADER; body estimatedBudget |
| POST | /trip/:tripId/settle | Thành viên; tính và lưu công nợ |
| GET | /settlement/:id/vietqr | Thành viên; QR của khoản nợ còn hiệu lực |
| PUT | /settlement/:id/paid | Chỉ người trả; PENDING -> REPORTED |
| PUT | /settlement/:id/confirm | Chỉ người nhận; REPORTED -> PAID |
| POST | /webhook/sepay | API key bắt buộc; không dùng JWT người dùng |

Công nợ không đổi giữ nguyên settlement ID và QR. Tính lại khi có bill mới sẽ
chuyển các PENDING cũ sang CANCELLED. Không tính lại khi còn REPORTED chưa xác nhận.
Tiền chuyển vào QR đã hủy phải đối soát thủ công, không tự gạch khoản nợ mới.
Các thao tác ghi chi tiêu dùng transaction và khóa trên cùng chuyến đi.
Feature Trips khi bổ sung thay đổi thành viên nên khóa cùng row trips trước khi ghi.
Thành viên đã rời nhóm vẫn xuất hiện trong số dư nếu còn lịch sử chi tiêu.
Tạo bill đồng thời tạo notification BILL cho người chịu tiền.

Rút gọn nợ tìm số giao dịch tối thiểu cho tối đa 15 người có số dư khác 0.
Nhóm lớn hơn dùng thuật toán tham lam có thời gian chạy giới hạn, vẫn bảo toàn tiền.

## SePay

Chọn xác thực API Key tại SePay. Header là `Authorization: Apikey <SEPAY_API_KEY>`.
Không có secret mặc định. Cấu hình `SEPAY_BANK_BINS` ánh xạ chính xác giá trị
gateway của webhook sang BIN, ví dụ `{"MBBank":"970422"}`.
Xác minh ánh xạ với tài khoản SePay thực tế trước khi bật.

Webhook yêu cầu id giao dịch, gateway, accountNumber, transferType và transferAmount.
Chỉ tiền vào đúng ngân hàng, đúng tài khoản snapshot lúc tạo QR và đúng số tiền
mới được ghi nhận. ID giao dịch chống xử lý lặp. Số tiền thiếu/thừa cần đối soát.
Mã mới là FT + UUID bỏ dấu gạch; mã 8 ký tự cũ chỉ được nhận nếu không trùng.
Dữ liệu tài khoản thụ hưởng được giữ cùng settlement để đổi hồ sơ ngân hàng
không khiến QR và bước xác minh trỏ tới hai tài khoản khác nhau.

## AI Planner

`GEMINI_MODEL` cấu hình model, mặc định gemini-3.1-flash-lite.
Timeout 30 giây. Output phải qua kiểm tra JSON, ngày 1..N liên tục, giờ HH:mm,
tối đa 14 ngày x 24 hoạt động và chi phí nguyên không âm.
Đầu ra có `source: gemini`. API lỗi trả 503.
Chỉ khi `AI_ALLOW_FALLBACK=true` mới trả mẫu cục bộ với
`source: fallback` và `warning`. Mẫu này không phải kết quả AI hay tối ưu đường đi.
Save nhận startDate đúng YYYY-MM-DD, tạo ngày bằng UTC, giữ category và tạo invite_code.
Bảo toàn estimatedBudget=0.

## Phần dùng chung cho team

Vai trò trưởng nhóm dùng LEADER (không dùng HOST).
Schema bổ sung user_blocks, emergency_contacts, sos_alerts để Thành triển khai
feature reviews/SOS; không có endpoint SOS mới trong lần sửa này.
SHOPPING được chấp nhận ở cả constants và bảng places.
app.js giữ nguyên đăng ký router; owner feature tự thêm endpoint trong routes.

## Kiểm thử và CI

`npm run check` kiểm tra từng file JS riêng.
`npm test` tự tạo PostgreSQL tạm nếu máy Windows có PostgreSQL 18 tại đường dẫn
mặc định. Máy khác đặt PG_BIN hoặc TEST_DATABASE_URL tới PostgreSQL test.
Bộ test tạo schema ngẫu nhiên riêng, dọn schema sau khi chạy; không dùng DATABASE_URL
của ứng dụng. SMTP và Gemini được giả lập, không gửi email hay gọi dịch vụ tính phí.
Test bao gồm SQL thật, migration chạy lại, phân quyền, OTP, token, chia tiền,
request đồng thời, webhook lặp và lưu lịch trình.

CI kiểm tra commit được push, merge đúng SHA đó vào main mới nhất, rồi kiểm tra
lại kết quả merge trước khi push main. Không coi kiểm tra cú pháp là kiểm thử nghiệp vụ.
Chưa kiểm thử SMTP/Gemini/SePay thật; cần cấu hình và thử các dịch vụ đó trên staging.
Định kỳ dọn counters hết hạn bằng `npm run db:cleanup`.

Nguồn API:
- https://developer.sepay.vn/vi/sepay-webhooks/tich-hop-webhook
- https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite

# Xét duyệt CCCD thủ công

Luồng mặc định từ 03/11/2026:

1. Người dùng vào Hồ sơ → Xác minh CCCD.
2. Nhập 12 số CCCD hoặc quét QR để điền số; thêm mặt trước, mặt sau và chân dung.
3. Xác nhận ảnh/giấy tờ của mình và gửi hồ sơ. App không yêu cầu phiên AI, OCR đạt hay video liveness.
4. Backend lưu ảnh Cloudinary loại authenticated và chuyển `UNVERIFIED`/`REJECTED` thành `PENDING`. Người dùng chưa có trạng thái đã xác minh ở bước này.
5. Admin → Hồ sơ chờ duyệt → kiểm tra số thẻ và ba ảnh. Ảnh có thể phóng to. Duyệt cấp `VERIFIED`; từ chối phải có lý do và chuyển `REJECTED`.
6. Người dùng nhận thông báo, có thể cập nhật trạng thái; hồ sơ bị từ chối cho phép bổ sung và nộp lại. Hồ sơ đang chờ hoặc đã xác minh không được gửi chồng.

## Triển khai

- Deploy backend Node mới lên Render và chạy bản Flutter mới.
- Giữ `EKYC_AUTO_ENABLED=false` hoặc không khai báo biến này. Biến chỉ bật khi có chủ đích nghiên cứu auto.
- Luồng thủ công cần DB, JWT và Cloudinary hiện có; không cần EKYC_WORKER_URL, EKYC_WORKER_KEY, Python hay service AI.
- Không có migration mới: sử dụng trạng thái và cột ảnh đã có trong users. Giữ nguyên users/ekyc_sessions và migration 011 để phần auto dùng lại sau.
- Code Google login và các phần khác đang sửa vẫn được giữ nguyên.

## API

`POST /api/v1/users/ekyc-submit` yêu cầu JWT và multipart:

| Trường | Dữ liệu |
|---|---|
| cccdNumber | Đúng 12 chữ số |
| cccdFrontImage | Ảnh mặt trước |
| cccdBackImage | Ảnh mặt sau |
| selfieImage | Ảnh chân dung |

Chỉ nhận JPG, PNG hoặc WEBP, tối đa 5 MB/ảnh. Cả ba ảnh được kiểm tra trước khi upload. Lỗi upload/lưu DB sẽ dọn các ảnh mới đã upload; cập nhật trạng thái có điều kiện để không nhận hai lần đồng thời. Giới hạn gửi hồ sơ theo tài khoản, không gom tất cả người cùng IP vào một hạn mức.

Các endpoint admin duyệt/từ chối giữ nguyên. Danh sách chờ duyệt chỉ dành cho ADMIN, trả link ảnh có chữ ký hết hạn sau 10 phút và `Cache-Control: no-store`; khi link hết hạn, tải lại danh sách. Hồ sơ công khai và API hồ sơ của chính user không trả số CCCD đầy đủ hoặc link ảnh. Khi duyệt, backend kiểm tra tài khoản còn hoạt động, đủ ảnh và CCCD chưa được cấp xác minh cho tài khoản khác.

## Phần tự động được giữ lại

- Backend: `users/identity.service.js`, `identity.repository.js`, `identity.upload.js`, `/users/ekyc/session`, `/users/ekyc-verify`.
- Worker và model loader: `backend/identity_worker`.
- Flutter: `automatic_ekyc_screen.dart`, màn liveness, OCR và các kiểm thử tự động cũ.
- Muốn nghiên cứu lại: cấu hình worker, bật `EKYC_AUTO_ENABLED=true`, và mở màn AutomaticEkycScreen trong luồng thử nghiệm. Không có nút chuyển sang auto trên giao diện người dùng hiện tại.

Kiểm thử dùng ảnh tổng hợp và Cloudinary giả lập, không đọc hay gửi ảnh CCCD cá nhân. Cần kiểm tra upload/xem ảnh trên Cloudinary thực và thao tác camera trên thiết bị khi triển khai.

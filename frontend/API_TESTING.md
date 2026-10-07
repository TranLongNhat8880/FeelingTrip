# Kiểm thử giao diện với API local

Mặc định app gọi API thật. Khởi động PostgreSQL trên Docker, sau đó:

```powershell
cd backend
npm start
```

Chạy frontend web ở terminal khác:

```powershell
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000/api/v1
```

Android emulator mặc định dùng `http://10.0.2.2:5000/api/v1`. Điện thoại thật cần
`--dart-define=API_BASE_URL=http://<IP-máy-chạy-backend>:5000/api/v1`.

## Chế độ xem giao diện bằng mock

```powershell
flutter run -d chrome --dart-define=USE_MOCK_DATA=true
flutter test --dart-define=USE_MOCK_DATA=true
```

Ở chế độ API, các nút đăng nhập nhanh mock bị ẩn. Lỗi mạng không tự đăng nhập
bằng dữ liệu giả. Danh sách chọn đăng bài chỉ lấy chuyến đang hoạt động mà tài
khoản là trưởng nhóm. Các trang khác của nhóm giữ luồng hiện tại.

## Kiểm thử tự động với database dev

Chỉ chạy seed trên database local/dev. Script thêm 6 tài khoản và 1 chuyến đi
riêng, không sửa dữ liệu đã có. Mỗi lần seed dùng email mới; chạy seed trước mỗi
lần kiểm thử live. Tài khoản và chuyến test được giữ lại để kiểm tra thủ công.
Thông tin đăng nhập nằm trong `frontend/.tmp/api-fixture.json`.

```powershell
cd backend
node ../frontend/tool/seed-ui-api-test.cjs
cd ../frontend
flutter test --dart-define=LIVE_API_TEST=true --dart-define=API_BASE_URL=http://127.0.0.1:5000/api/v1 test/live_api_test.dart
```

Luồng live kiểm tra: đăng nhập thật, chuyến của trưởng nhóm, tạo bài, lọc feed,
chi tiết (kể cả tiền PostgreSQL dạng chuỗi), gửi/trùng yêu cầu, chấp thuận thành
viên, thông báo đọc/xóa, admin duyệt/từ chối eKYC, khóa/mở khóa và đăng nhập bị
khóa. Ảnh CCCD thật lấy từ API admin; fixture không dùng giấy tờ cá nhân.

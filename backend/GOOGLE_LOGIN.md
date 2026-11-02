# Đăng nhập Google trong FeelingTrip

App nhận Google ID token qua SDK rồi gửi JSON đến `POST /api/v1/auth/google`. Backend kiểm tra chữ ký, hạn token, issuer, audience và email đã xác thực bằng `google-auth-library`, sau đó cấp JWT của FeelingTrip. Không nhận email, role hoặc trạng thái eKYC do client khai báo. Không cần Google client secret cho luồng này.

## 1. Tạo cấu hình trên Google Cloud

Mở Google Auth Platform trong Google Cloud Console, chọn hoặc tạo project.

- Hoàn thành Branding/Audience và thông tin hỗ trợ cho ứng dụng FeelingTrip.
- Nếu ứng dụng ở chế độ External Testing, thêm các tài khoản Google dùng thử vào Test users khi console yêu cầu.
- Chỉ sử dụng thông tin đăng nhập cơ bản: openid, email, profile; không cần xin quyền Drive, Contacts hay People API.
- Tạo OAuth client loại **Web application**. Sao chép Client ID có đuôi `.apps.googleusercontent.com`. Dùng cùng ID này ở backend và Flutter trong các bước dưới.

## 2. Cấu hình backend trên Render

Trong service Node FeelingTrip → Environment, thêm:

```dotenv
GOOGLE_CLIENT_IDS=<WEB_CLIENT_ID>.apps.googleusercontent.com
```

Có thể khai báo nhiều audience, ngăn cách bằng dấu phẩy nếu dùng nhiều OAuth client. Không thêm Android Client ID nếu ứng dụng đang yêu cầu ID token bằng Web client ở serverClientId. Lưu và deploy mã backend mới. Thay `.env` trên máy không cập nhật Render.

Endpoint Google dùng cùng giới hạn request của phân hệ auth. Thiếu cấu hình server trả 503 và không tạo phiên đăng nhập. Cột `users.google_id` và mật khẩu nullable đã có trong schema hiện tại; thay đổi này không cần thêm migration. Database triển khai phải đã có schema và các migration hiện hành.

## 3. Chạy Android trên điện thoại

Tạo thêm OAuth client loại **Android**, cùng Google Cloud project:

- Package name: `com.feelingtrip.feeling_trip`.
- SHA-1: lấy của chứng chỉ ký bản app đang chạy. Có thể xem bằng `./gradlew signingReport` trong `frontend/android` (Windows dùng `.\gradlew.bat signingReport`).
- Bản debug và bản release dùng chứng chỉ khác nhau cần được đăng ký tương ứng. Project hiện đang ký release bằng debug key; khi chuyển sang key release phải cập nhật OAuth client.

APK release xuất ngày 02/11/2026 đã được kiểm tra bằng apksigner. Với bản này, tạo Android OAuth client theo:

```text
Package: com.feelingtrip.feeling_trip
SHA-1: F5:2E:5D:A9:C7:AB:C7:3C:79:E0:47:83:7C:CC:BD:9F:43:76:23:BE
```

Chữ ký này khác bản APK debug cũ ngày 20/10/2026. Cài đè lên app ký bằng key cũ có thể bị Android từ chối; không tự gỡ app cũ nếu cần giữ dữ liệu trên thiết bị. Khi đổi signing key, lấy lại SHA-1 từ APK mới.

Từ `frontend`, chạy:

```powershell
flutter run -d <DEVICE_ID> --dart-define=GOOGLE_WEB_CLIENT_ID=<WEB_CLIENT_ID>.apps.googleusercontent.com
```

Code truyền Web Client ID vào `serverClientId` nên không cần thêm Firebase hoặc google-services.json cho cấu hình Android này. Không truyền Android Client ID thay cho Web Client ID. Nếu Flutter trên Windows báo thiếu symlink support, bật Developer Mode trong Windows Settings rồi chạy lại `flutter pub get`.

## 4. Chạy Flutter web

Trong OAuth client loại Web → Authorized JavaScript origins, thêm:

```text
http://localhost
http://localhost:7357
```

Thêm origin thực tế nếu publish Flutter web. Đây là origin của giao diện, không phải URL backend Render và không chứa đường dẫn `/api/v1`. Luồng SDK ID token này không cần thêm callback backend vào Authorized redirect URIs.

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=GOOGLE_WEB_CLIENT_ID=<WEB_CLIENT_ID>.apps.googleusercontent.com
```

Web sử dụng nút do Google Identity Services cung cấp; Android/iOS dùng nút trong giao diện app. Dùng cổng cố định đã đăng ký, thay vì cổng Flutter ngẫu nhiên. Thay dart-define cần chạy/build lại app, hot reload không thay cấu hình biên dịch.

Project đã có lệnh chạy nhanh cho Edge trên Windows. Từ thư mục `frontend`, chạy `.\run-edge.cmd`. Script đặt sẵn localhost:7357 và Web Client ID công khai của FeelingTrip, giữ hot reload trong terminal. Có thể thêm tham số Flutter ở cuối, ví dụ `.\run-edge.cmd --verbose`.

## 5. iOS

Cần tạo OAuth client iOS theo bundle identifier thực tế, thêm reversed client ID vào URL Types của Runner theo tài liệu plugin. Truyền cả `GOOGLE_IOS_CLIENT_ID` và `GOOGLE_WEB_CLIENT_ID` khi build/chạy. Chưa thể kiểm chứng build iOS trên máy Windows; cần hoàn thành cấu hình Runner và thử trên macOS/iPhone trước khi dùng.

## Quy tắc tài khoản

- Lần đầu với Gmail/Google Workspace mới: backend yêu cầu đồng ý Điều khoản sử dụng. App mở màn hình điều khoản hiện có; chỉ tạo tài khoản và lưu phiên sau khi người dùng chấp nhận.
- Tài khoản Google đã liên kết: nhận diện bằng `sub` của token, không theo tên hiển thị hoặc email do client gửi.
- Gmail/Workspace trùng tài khoản email đã xác thực: liên kết vào cùng User, giữ mật khẩu, hồ sơ, vai trò và dữ liệu chuyến đi hiện có.
- Tài khoản email cũ chưa xác thực, email đã gắn Google khác, hoặc email bên thứ ba trùng tài khoản cũ: từ chối liên kết tự động. Không thay đổi Google ID của tài khoản khác.
- Google không bảo đảm quyền sở hữu hiện tại của email ngoài Gmail/Workspace. Tài khoản mới dùng loại email này được hướng dẫn đăng ký và xác thực qua OTP; luồng liên kết riêng sau khi đăng nhập chưa được thêm.
- Tài khoản bị khóa không được đăng nhập bằng Google. Xác thực email Google không cấp trạng thái xác minh CCCD.
- ID token Google chỉ dùng để đổi lấy JWT app; không lưu ID token Google vào local storage hay log.

## Kiểm tra sau triển khai

Thử tài khoản mới và đồng ý/hủy điều khoản, đăng nhập lại, đăng xuất rồi chọn Google khác, Gmail trùng tài khoản email đã xác thực, tài khoản bị khóa. Kiểm tra tài khoản mới vẫn chưa xác minh CCCD và dữ liệu cũ vẫn được giữ khi liên kết.

Backend test dùng PostgreSQL tạm và chữ ký RSA thử nghiệm; chỉ giả lập việc tải public key. Chữ ký token, issuer, audience và hạn được kiểm tra bằng thư viện thật. Flutter test kiểm tra trao đổi phiên và đồng ý điều khoản. Các test này không thay thế đăng nhập thật qua OAuth client đã đăng ký.

Tài liệu chính thức:

- https://developers.google.com/identity/gsi/web/guides/verify-google-id-token
- https://pub.dev/packages/google_sign_in_android
- https://pub.dev/packages/google_sign_in_web
- https://pub.dev/packages/google_sign_in_ios

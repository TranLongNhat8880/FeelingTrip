# FeelingTrip Backend API

Dự án Backend cho ứng dụng **FeelingTrip** xây dựng bằng **Node.js, Express.js và PostgreSQL** theo kiến trúc **Feature-based Architecture (Modular)**.

---

## 📁 Cấu trúc thư mục

```text
backend/
├── src/
│   ├── app.js               # Đăng ký middleware chung & các routes
│   ├── server.js            # Entry point kết nối DB và start server
│   │
│   ├── config/              # Cấu hình môi trường & Database
│   │   ├── env.js           # Load biến từ .env
│   │   └── database.js      # Kết nối PostgreSQL (pg Pool)
│   │
│   ├── shared/              # THƯ MỤC DÙNG CHUNG (TẤT CẢ THÀNH VIÊN ĐỀU CÓ THỂ GỌI)
│   │   ├── constants/       # Mã HTTP (httpStatus), vai trò (roles), danh mục (categories)
│   │   ├── middlewares/     # verifyToken (auth), checkRole (role), errorHandler
│   │   ├── services/        # Third-party: VietQR, Gemini AI, Goong Map
│   │   └── utils/           # response (sendSuccess, sendError), token, hash, minCashFlow
│   │
│   └── features/            # CÁC MODULE TÍNH NĂNG (MỖI BẠN TỰ CODE TRONG FOLDER CỦA MÌNH)
│       │                    # Mỗi module gồm 4 tầng chuẩn:
│       │                    # - *.routes.js     : Định tuyến API
│       │                    # - *.controller.js : Nhận req, validate, trả res
│       │                    # - *.service.js    : Xử lý nghiệp vụ logic
│       │                    # - *.repository.js : Viết câu lệnh SQL truy vấn Database
│       │                    # - explain.txt     : Hướng dẫn chi tiết phân hệ
│       ├── auth/            # Đăng ký, đăng nhập, OTP
│       ├── users/           # Hồ sơ cá nhân, eKYC, ngân hàng
│       ├── trips/           # Chuyến đi, thành viên, mời nhóm
│       ├── itineraries/     # Lịch trình ngày, hoạt động, Smart Swap
│       ├── companions/      # Bảng tin Newsfeed tìm bạn đồng hành
│       ├── expenses/        # Chi phí, Split Bill, VietQR
│       ├── reviews/         # Đánh giá, báo cáo, chặn người dùng
│       ├── ai-planner/      # Tích hợp AI gợi ý lịch trình
│       └── admin/           # Phê duyệt, quản trị hệ thống
```

---

## 🛠️ Hướng dẫn cài đặt & Chạy trên máy cá nhân

1. Cài đặt thư viện:
   ```bash
   npm install
   ```

2. Tạo file cấu hình môi trường `.env`:
   ```bash
   cp .env.example .env
   ```
   *(Điền thông tin PostgreSQL của bạn vào `.env`)*

3. Chạy ở chế độ phát triển (tự reload khi sửa code):
   ```bash
   npm run dev
   ```

---

## 👥 Quy tắc làm việc nhóm & Tránh xung đột (Git Workflow)

1. **Phân chia thư mục:** Mỗi bạn chỉ làm việc trong thư mục `features/<tên_tính_năng>/` được phân công.
2. **Sử dụng tài nguyên dùng chung:**
   - Cần trả về response chuẩn? Gọi `sendSuccess(res, data)` hoặc `sendError(res, message)` từ `shared/utils/response.util.js`.
   - Cần bắt đăng nhập? Dùng middleware `authenticate` từ `shared/middlewares/auth.middleware.js`.
   - Cần check quyền Admin? Dùng `authorize(ROLES.ADMIN)` từ `shared/middlewares/role.middleware.js`.
3. **Quy trình Git:** Làm trên nhánh nhat/phu/thanh/tung như CONG_VIEC.txt. Push nhánh của mình; CI test commit và kết quả merge rồi mới đẩy main. Không push trực tiếp main.

Xem [REVIEW_FIXES.md](REVIEW_FIXES.md) để chạy migration, cấu hình dịch vụ và kiểm thử.

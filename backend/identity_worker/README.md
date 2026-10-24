# Xác minh danh tính tự động cho đồ án FeelingTrip

Worker riêng chạy CPU; Node.js API gọi worker qua mạng riêng bằng `EKYC_WORKER_KEY`.
Ảnh/video không gửi đến dịch vụ AI bên ngoài. Không commit `.env`, model, ảnh hoặc video.
Worker build bằng Python + Railpack, không cần Dockerfile hay cài Docker trên máy.

## Luồng

1. App gọi `POST /api/v1/users/ekyc/session` sau khi đăng nhập. Server cấp ID, thứ tự thao tác và hạn 5 phút.
2. Camera trước vừa quay video không âm thanh vừa hướng dẫn nhắm/mở mắt, quay trái/phải. Mất mặt hoặc chuyển app ra nền phải quay lại từ đầu.
3. `POST /api/v1/users/ekyc-verify`: multipart gồm `sessionId`, `cccdNumber`, `qrData`, ba ảnh cũ và `livenessVideo`.
4. Server dùng phiên đúng tài khoản, chưa sử dụng, còn hạn. Worker tự đọc QR/OCR từ ảnh thẻ, so số thẻ/họ tên/ngày sinh, so embedding SFace và xem lại video bằng MediaPipe + MiniFASNetV2.
5. Chỉ khi TẤT CẢ kiểm tra đạt, API mới lưu ảnh Cloudinary dạng authenticated và cập nhật `VERIFIED`, `is_verified=true` trong transaction. Không nhận điểm số/trạng thái do client khai báo.
6. Thiếu bằng chứng hoặc không khớp: 422, yêu cầu chụp/quay lại. Worker bận/mất kết nối: 503; không tự duyệt, không tự chuyển sang admin.
7. App đọc lại hồ sơ và cập nhật phiên đăng nhập từ API sau khi xác minh. Chỉ hiển thị thành công khi server đã xác nhận VERIFIED; việc upload được chấp nhận chưa đồng nghĩa với đã duyệt.

Hồ sơ cũ đang PENDING vẫn giữ nguyên; admin vẫn có thể xử lý hồ sơ cũ. Migration 011 chỉ thêm bảng phiên, không đổi dữ liệu users.

## Chạy trên máy Windows

```powershell
cd backend/identity_worker
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt
.venv/Scripts/python.exe fetch_models.py
# Tạo .env: EKYC_WORKER_KEY=<chuỗi ngẫu nhiên >=32 ký tự>, PORT=5101
.venv/Scripts/python.exe app.py
```

Trong `backend/.env`: `EKYC_WORKER_URL=http://127.0.0.1:5101`, `EKYC_WORKER_KEY` giống worker.
Sau đó chạy `npm run db:migrate` ở backend và khởi động lại API.
App dùng API trên máy: `flutter run --dart-define=API_BASE_URL=http://<IP máy>:5000/api/v1` (xem tên cấu hình API trong frontend).

## Railway

Luồng sau khi triển khai: **app điện thoại → Node API Railway → worker AI qua mạng riêng Railway → Node cập nhật kết quả**. Không cần mở máy tính hay chạy worker local.

1. Trong **cùng project và environment** với Node API, tạo service `identity-worker` từ cùng repository/branch đã có code này.
2. Settings → Source → Root Directory: `/backend/identity_worker`. Settings → Build → Builder: **Railpack**. Xóa Custom Build Command / Custom Start Command cũ nếu có; cấu hình `railpack.json` trong thư mục worker đã đặt lệnh build/start. Giữ Node API ở root và builder hiện tại của nó.
   - `.python-version` cố định Python 3.11; Railway tự cài `requirements.txt`.
   - `railpack.json` cài thư viện hệ thống `libgl1`, `libglib2.0-0`, `libgomp1` ở cả build và runtime, rồi chạy `python prepare.py` để tải/kiểm tra model. Khi khởi động dùng `python app.py` (Waitress).
   - `.env`, `.venv`, model local, ảnh/video và test được loại khỏi nguồn build bằng `exclude`. Model phục vụ được tải lại từ nguồn công khai có checksum lúc build.
   - Settings → Deploy → Healthcheck Path: `/ready`, timeout 120 giây; giữ 1 replica và Restart Policy: On Failure (3 lần).
   - `railpack.json` là cấu hình **builder Railpack**, khác với `railway.json`/`railway.toml` (Config as Code cũ đã bị Railway ngừng cho service mới).
3. Variables của worker:

   ```dotenv
   HOST=*
   PORT=5101
   EKYC_WORKER_KEY=<chuỗi ngẫu nhiên >=32 ký tự>
   ```

   `HOST=*` là wildcard của Waitress, nghe cả IPv4 và IPv6 để hỗ trợ mạng riêng Railway. Không cần Generate Domain, không cần database/Cloudinary credentials ở worker.
4. Variables của **Node API** (giả sử tên service chính xác là `identity-worker`):

   ```dotenv
   EKYC_WORKER_URL=http://${{identity-worker.RAILWAY_PRIVATE_DOMAIN}}:5101
   EKYC_WORKER_KEY=${{identity-worker.EKYC_WORKER_KEY}}
   ```

   Hai biến dùng Railway reference; không đưa khóa vào app hoặc commit `.env`. Nếu đổi tên service hoặc cổng thì sửa reference/URL tương ứng.
5. Deploy worker, chờ build và health check `/ready` đạt. Endpoint này chỉ trả `ready`; `/health` và `/verify` vẫn yêu cầu `X-Worker-Key`. Model được tải và kiểm tra checksum lúc build; startup chỉ tải vào RAM.
6. Chạy migration 011 bằng quy trình migration của backend trước khi dùng API mới (migration đã áp dụng thì không cần chạy SQL lại). Deploy Node API có các route eKYC mới. Từ Railway shell của Node có thể kiểm tra kết nối mà không in khóa:

   ```sh
   node -e 'fetch(process.env.EKYC_WORKER_URL+"/health",{headers:{"X-Worker-Key":process.env.EKYC_WORKER_KEY},signal:AbortSignal.timeout(10000)}).then(async r=>{console.log(r.status,await r.json());if(!r.ok)process.exitCode=1}).catch(()=>{console.error("Worker unreachable");process.exitCode=1})'
   ```

7. Cài/chạy bản app Android mới dùng API Railway mặc định. Thử QR → ảnh thẻ → thử thách camera → xác minh; kiểm tra cả người đúng, khác người và ảnh tĩnh. Chưa coi health check hoặc test tự động là bằng chứng luồng camera thật đã đạt.

Lần build đầu sẽ tải Python dependencies và model nên có thể lâu hơn Node API. Worker là service tính tài nguyên riêng; theo dõi RAM/CPU trong Metrics khi test để đặt giới hạn phù hợp. Không bật sleep cho worker nếu muốn tạo phiên xác minh ngay (Node chỉ chờ health 4 giây).

Chỉ cần commit mã nguồn và cấu hình rồi deploy service Python. Không có bước build image, chạy Docker CLI hay quản lý container thủ công. Railway vẫn đóng gói ứng dụng trên hạ tầng của họ qua Railpack; việc này không cần thao tác Docker trong project.

Tài liệu: [Railpack Python](https://railpack.com/languages/python), [cấu hình Railpack](https://railpack.com/config/file), [thư viện hệ thống](https://railpack.com/guides/installing-packages/).

Ứng dụng hiện mặc định gọi Railway. Chỉ khi chủ động kiểm thử local mới cần truyền `API_BASE_URL` như trên; thay `.env` trên máy không cập nhật Variables hay triển khai trên Railway.

## Model và giới hạn

- [YuNet](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet): phát hiện/căn mặt, MIT.
- [SFace](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface): embedding nhận diện, Apache-2.0. Ngưỡng cosine **0.50**, không phải “50% chính xác”.
- [MediaPipe Face Landmarker](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker): kiểm tra thứ tự động tác trực tiếp.
- [MiniFASNetV2](https://github.com/yakhyo/face-anti-spoofing): kiểm tra chống ảnh/video trình chiếu; ngưỡng live **0.90** trên nhiều khung nhìn thẳng. Model gốc: [Silent-Face-Anti-Spoofing](https://github.com/minivision-ai/Silent-Face-Anti-Spoofing), Apache-2.0.
- [RapidOCR](https://github.com/RapidAI/RapidOCR): OCR Latin PP-OCRv5, Apache-2.0; đối chiếu chính xác sau chuẩn hóa dấu, không tự sửa số CCCD sai.

`fetch_models.py` khóa SHA-256 của toàn bộ model. Dữ liệu inference chỉ trong RAM/temp, video tạm xóa khi xử lý xong; không lưu embedding. Bảng phiên chỉ giữ kết quả/điểm kỹ thuật.

Đây là luồng tự duyệt cho đồ án, chưa được chứng nhận PAD hoặc đánh giá sai nhận trên tập CCCD thực tế. Phải thử trên camera thật với các cặp đúng/sai, ảnh in/màn hình và nhiều điều kiện ánh sáng trước khi sử dụng thực tế. Không kiểm chứng CCCD do cơ quan có thẩm quyền cấp; QR và OCR khớp không chứng minh thẻ thật.
Model có thể sai và chất lượng ảnh thẻ ảnh hưởng mạnh; không hạ ngưỡng chỉ để demo qua. Các model phải được xem giấy phép trước khi phân phối thương mại.

## Kiểm thử

Ở thư mục worker:

```powershell
.venv/Scripts/python.exe fetch_test_fixtures.py
.venv/Scripts/python.exe -m unittest test_deployment test_checks test_engine -v
```

Các ảnh mẫu công khai chỉ nằm trong `backend/.tmp/identity-fixtures` đã được Git ignore; không dùng ảnh CCCD cá nhân. Test ảnh thẻ tổng hợp chạy thật QR/OCR/SFace; riêng phần video trong ca thành công được mock. Ca video đứng yên chạy MediaPipe/SFace/MiniFASNet thật và phải bị từ chối. Đây chưa phải ca xác minh thành công quay bằng điện thoại thật.

Ở backend: `npm test` dùng PostgreSQL/schema tạm, kiểm tra phiên một lần, sai tài khoản, hết hạn, khôi phục tác vụ, tranh chấp CCCD và việc từ chối khi thiếu bất kỳ điều kiện xác minh nào. Ở frontend: các test `ekyc_qr_flow_test.dart` và `face_liveness_capture_test.dart` mô phỏng API/camera để kiểm tra vòng đời và truyền bằng chứng. Cần quay thử trên điện thoại trước khi đánh giá độ chính xác thực tế.

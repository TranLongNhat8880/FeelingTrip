# PHÂN TÍCH VẤN ĐỀ VÀ GIẢI PHÁP KỸ THUẬT CHO CÁC TÍNH NĂNG (FEELINGTRIP)

Tài liệu này phân tích chi tiết toàn bộ các tính năng của ứng dụng **FeelingTrip**, bao gồm các tính năng cộng đồng, tìm bạn đồng hành dạng Newsfeed, gợi ý lịch trình thông minh (Smart Swap, Clone Plan tương đồng), phân chia chi phí (Split Bill), và bảo mật danh tính. Mỗi tính năng đều chỉ rõ **Vấn đề / Thách thức kỹ thuật thực tế** và **Giải pháp công nghệ tối ưu** để triển khai.

---

## BẢNG TỔNG QUAN CÁC TÍNH NĂNG & THÁCH THỨC KỸ THUẬT

| STT | Phân hệ / Tính năng | Thách thức / Vấn đề kỹ thuật | Giải pháp kỹ thuật đề xuất |
| :--- | :--- | :--- | :--- |
| **1** | **Xác minh danh tính CCCD (eKYC)** | Không truy cập được CSDL Bộ Công An C06; nguy cơ làm giả ảnh, mạo danh. | **Quét mã QR trên thẻ CCCD gắn chip (0đ)** hoặc kết hợp **FPT.AI eKYC OCR + Face Match**. |
| **2** | **Bản tin tìm bạn đồng hành (Travel Newsfeed)** | Hiệu năng tải bảng tin (Infinite Scroll), quản lý trạng thái slot còn trống, lọc tương tác. | Thiết kế Card bài post du lịch; phân trang **Cursor-based Pagination**; tự động cập nhật trạng thái khi đủ người. |
| **3** | **Lịch trình mẫu & Thay thế điểm thông minh (Smart Swap B -> B+)** | Tìm điểm tương đương không làm lệch quãng đường di chuyển và đúng sở thích. | Phân loại địa điểm theo `category` + Truy vấn vị trí lân cận (bán kính R km quanh điểm B cũ) để gợi ý điểm B+. |
| **4** | **Gợi ý Plan tương đồng & Clone Top-rate (Fork Plan)** | Phát hiện plan trùng khớp; thuật toán xếp hạng; kỹ thuật Deep Copy dữ liệu tour nhiều cấp. | Truy vấn so khớp `destination + duration`; xếp hạng theo `avg_rating & clone_count`; dùng **PostgreSQL Transaction** để Deep Clone. |
| **5** | **Chia tiền (Split Bill) & VietQR** | Nợ chéo lòng vòng nhiều người; thanh toán rườm rà; sai số làm tròn tiền. | Áp dụng thuật toán **Rút gọn dòng nợ (Min Cash Flow)** + Render **VietQR tự động** theo chuẩn NAPAS. |
| **6** | **Bản đồ & Tối ưu lộ trình di chuyển** | Chi phí Google Maps API đắt đỏ; bài toán tối ưu đường đi (TSP). | Tích hợp **Goong Map / Mapbox**; thuật toán tham lam (Greedy / Nearest Neighbor) tối ưu thứ tự di chuyển. |
| **7** | **AI Travel Planner (Nâng cao)** | Dữ liệu AI trả về dạng text tự do, khó đưa vào app; ảo giác (hallucination). | Sử dụng **Google Gemini API** với **Structured JSON Output** ép kiểu chuẩn schema lịch trình. |

---

## CHI TIẾT TỪNG PHÂN HỆ VÀ GIẢI PHÁP KỸ THUẬT

### 1. Phân hệ Tài khoản và Xác thực Danh tính (eKYC)

#### Tính năng:
- Đăng ký/đăng nhập (Email OTP, Google OAuth 2.0).
- Hồ sơ người dùng, thông tin ngân hàng thụ hưởng (phục vụ sinh VietQR).
- Xác minh danh tính bằng CCCD (cấp huy hiệu Tích xanh "Đã xác minh").

#### Vấn đề kỹ thuật:
- **Giới hạn quyền truy cập:** Không thể kết nối trực tiếp vào CSDL Dân cư Quốc gia C06 của Bộ Công An (chỉ cấp cho ngân hàng/tổ chức tài chính).
- **Gian lận danh tính:** Nguy cơ người dùng lấy ảnh CCCD của người khác tải lên để lừa đảo khi ghép tour.

#### Giải pháp kỹ thuật:
- **Tận dụng mã QR trên thẻ CCCD (Khuyên dùng - 0đ):** Sử dụng camera Flutter (`mobile_scanner`) quét mã QR góc phải CCCD, giải mã ra ngay chuỗi chuẩn: `Số CCCD | CMND cũ | Họ tên | Ngày sinh | Giới tính | Địa chỉ | Ngày cấp`. Hoàn toàn miễn phí, quét dưới 1 giây.
- **eKYC tích hợp:** Sử dụng FPT.AI eKYC API hoặc Google Cloud Vision để OCR 2 mặt thẻ và Face Matching (so khớp selfie với ảnh thẻ).
- **Admin Approval:** Quản trị viên duyệt và cấp tích xanh qua Web Admin.

---

### 2. Phân hệ Bảng tin Tìm bạn Đồng hành (Travel Newsfeed)

#### Tính năng:
- Hiển thị dưới dạng **bài post trên Newsfeed** cộng đồng để mọi người lướt xem và tìm đồng đội.
- Thông tin bài post: Ảnh bìa/điểm đến, thời gian, ngân sách dự kiến, số lượng thành viên hiện có & số slot cần tuyển, yêu cầu (độ tuổi, phong cách, giới tính).
- Tương tác: Thả tim/lưu bài, bấm "Gửi yêu cầu tham gia" kèm tin nhắn giới thiệu.

#### Vấn đề kỹ thuật:
1. **Hiệu năng tải Newsfeed:** Khi số lượng bài post tăng cao, tải toàn bộ bài post và ảnh sẽ làm chậm ứng dụng, ngốn RAM điện thoại.
2. **Xung đột trạng thái Slot còn trống:** Khi bài post chỉ còn 1 slot nhưng nhiều người cùng gửi yêu cầu hoặc Trưởng nhóm duyệt quá số lượng.

#### Giải pháp kỹ thuật:
- **Phân trang dạng Cursor-based Pagination:** Không dùng `OFFSET / LIMIT` truyền thống (dễ bị trùng bài khi có bài mới chèn vào), mà dùng `WHERE created_at < last_cursor ORDER BY created_at DESC LIMIT 10` để cuộn vô tận (Infinite Scroll) cực mượt.
- **Quản lý trạng thái bài post:** Bài post có các trạng thái: `OPEN` (Đang tuyển), `FULL` (Đã đủ người - tự động ẩn khỏi feed hoặc mờ đi), `CLOSED` (Đã đóng).
- **Kiểm soát số lượng:** Khi Leader bấm chấp thuận (Accept), Backend chạy trong 1 Database Transaction: kiểm tra `current_members < max_members`, nếu vừa đủ thì tự động chuyển status sang `FULL`.

---

### 3. Phân hệ Lịch trình Đề xuất & Thay thế Điểm thông minh (Smart Swap B -> B+)

#### Tính năng:
- Hệ thống cung cấp kho **Lịch trình mẫu (Curated / Template Itineraries)** lấy từ dữ liệu hệ thống chuẩn bị sẵn (data điểm đến, lịch trình chuẩn).
- **Thay thế điểm thông minh (Smart Swap):** Lịch trình gợi ý có lộ trình `Dest A -> Dest B -> Dest C`. Người dùng không thích điểm B thì có thể bấm "Đổi địa điểm" -> Hệ thống đề xuất danh sách `Dest B+` tương đương để thay thế.

#### Vấn đề kỹ thuật:
1. **Làm sao để gợi ý điểm B+ hợp lý?**
   - Nếu đổi điểm B thành B+ mà điểm B+ nằm quá xa (ngược hướng di chuyển so với A và C) thì lịch trình sẽ bị nát và tốn thời gian di chuyển.
   - Điểm B+ phải cùng phong cách/loại hình với điểm B (ví dụ: Đổi quán cà phê view đồi này thành quán cà phê ngắm hoàng hôn khác, đổi bảo tàng này thành di tích lịch sử khác).

#### Giải pháp kỹ thuật:
- **Mô hình Dữ liệu Địa điểm có Gắn Tag & Phân loại:**
  - Bảng `places` có các cột: `id`, `name`, `category` (CAFE, RESTAURANT, ATTRACTION, NATURE...), `lat`, `lng`, `price_level`, `avg_duration_minutes`.
- **Thuật toán Gợi ý Thay thế (Smart Swap Algorithm):**
  - Khi user chọn thay thế điểm $B(lat_B, lng_B, category_B)$:
    1. Lọc các địa điểm $B^+$ có cùng `category = category_B` (hoặc liên quan).
    2. Tính khoảng cách địa lý (Haversine Distance hoặc PostGIS `ST_Distance`) từ các điểm ứng viên tới điểm $B$: Chọn các điểm trong bán kính $R \le 3\text{km}$ quanh điểm $B$.
    3. Hoặc tối ưu hơn: Tính tổng khoảng cách tăng thêm $\Delta d = (\text{dist}(A, B^+) + \text{dist}(B^+, C)) - (\text{dist}(A, B) + \text{dist}(B, C))$. Ưu tiên các điểm có $\Delta d$ nhỏ nhất.
  - Trả về danh sách Top 5 điểm $B^+$ phù hợp nhất để user bấm 1 nút là hoán đổi vị trí ngay lập tức.

---

### 4. Gợi ý Plan tương đồng & Sao chép Lịch trình Cộng đồng (Plan Similarity & Top-rated Clone)

#### Tính năng:
- **Phát hiện Plan tương đồng:** Khi người dùng bắt đầu lập kế hoạch (chọn điểm đến: Đà Lạt, số ngày: 3 ngày 2 đêm), hệ thống tự động quét và hiển thị thông báo: *"Đang có các lịch trình Đà Lạt 3N2Đ được cộng đồng đánh giá rất cao, bạn có muốn tham khảo không?"*.
- **Xếp hạng Top-rated:** Ưu tiên hiển thị các lịch trình có đánh giá sao cao nhất ($\ge 4.5\star$) và có nhiều người dùng sao chép nhất.
- **Nhân bản 1-click (One-click Clone / Fork Plan):** Người dùng có thể bấm **"Sử dụng lịch trình này"** để nhân bản toàn bộ lộ trình của người khác thành chuyến đi của chính mình, sau đó tha hồ chỉnh sửa, thêm bớt thành viên.

#### Vấn đề kỹ thuật:
1. **So khớp Plan tương đồng nhanh chóng:**
   - Tránh việc quét toàn bộ cơ sở dữ liệu làm chậm ứng dụng.
2. **Sao chép dữ liệu đa cấp (Deep Copy Data):**
   - Một chuyến đi gồm nhiều cấp: `Trip -> Itinerary Days -> Itinerary Items (Activities)`.
   - Nếu clone không cẩn thận, user sửa plan mới sẽ vô tình làm thay đổi plan gốc của người khác, hoặc bị lỗi khóa ngoại (Foreign Key).

#### Giải pháp kỹ thuật:
- **Truy vấn So khớp & Xếp hạng:**
  ```sql
  SELECT t.*, AVG(r.rating) as avg_rating, COUNT(r.id) as review_count
  FROM trips t
  LEFT JOIN trip_reviews r ON t.id = r.trip_id
  WHERE t.destination ILIKE :destination 
    AND t.duration_days = :duration_days 
    AND t.is_public = true 
    AND t.status = 'COMPLETED'
  GROUP BY t.id
  ORDER BY avg_rating DESC, t.clone_count DESC
  LIMIT 5;
  ```
- **Kỹ thuật Deep Clone bằng PostgreSQL Transaction:**
  - Viết 1 Service `cloneTrip(sourceTripId, currentUserId)`:
    1. Tạo bản ghi mới trong bảng `trips` với `user_id = currentUserId`, `original_trip_id = sourceTripId`.
    2. Lấy toàn bộ `itineraries` (các ngày) của trip cũ -> Insert thành các ngày mới thuộc trip mới.
    3. Lấy toàn bộ `itinerary_items` (hoạt động/địa điểm) -> Insert tương ứng vào các ngày mới.
    4. Tăng trường `clone_count = clone_count + 1` của chuyến đi gốc.
    5. Toàn bộ nằm trong 1 **Database Transaction (`BEGIN ... COMMIT`)** để đảm bảo nếu lỗi ở bất kỳ bước nào thì tự rollback, không tạo dữ liệu rác.

---

### 5. Phân hệ Quản lý Ngân sách, Chia tiền (Split Bill) & VietQR

#### Tính năng:
- Ghi nhận các khoản chi tiêu trong nhóm.
- Tự động tính toán ai đang nợ ai.
- Thuật toán tối ưu rút gọn nợ để giảm số lượng giao dịch chuyển khoản.
- Tạo mã VietQR có sẵn số tiền và nội dung chuyển khoản chuẩn NAPAS.

#### Vấn đề kỹ thuật:
- **Bài toán nợ chéo lòng vòng:** 3 người: A trả 1.7tr tiền phòng, B trả 3tr ăn uống, C trả 900k thuê xe. Tổng 5.6tr -> mỗi người chịu 1.866k. Nếu để từng người tự trả nhau sẽ cực kỳ rắc rối.
- **Tạo mã QR thanh toán:** Cần chuẩn hóa mã QR để mọi app ngân hàng (MB, Vietcombank, Techcombank...) quét là hiểu ngay.

#### Giải pháp kỹ thuật:
- **Thuật toán Dòng tiền Cực tiểu (Min Cash Flow Algorithm):**
  1. Tính số dư ròng của từng người: $\text{Net}_i = \text{Tổng tiền đã trả} - \text{Tổng tiền phải chịu}$.
     - Người $A$: $1.700.000 - 1.866.667 = -166.667$ (Nợ)
     - Người $B$: $3.000.000 - 1.866.667 = +1.133.333$ (Nhận)
     - Người $C$: $900.000 - 1.866.667 = -966.667$ (Nợ)
  2. Thuật toán ghép nợ:
     - $C$ chuyển cho $B$: $966.667$đ.
     - $A$ chuyển cho $B$: $166.667$đ.
     => Chỉ cần đúng **2 giao dịch** là toàn bộ công nợ được giải quyết dứt điểm!
- **Sinh mã VietQR động:**
  Sử dụng chuẩn URL mở của VietQR:
  `https://img.vietqr.io/image/<BANK_BIN>-<STK>-compact2.png?amount=<SO_TIEN>&addInfo=<NOI_DUNG>`

---

### 6. Phân hệ Bản đồ & Tối ưu Lộ trình

#### Tính năng:
- Tìm kiếm địa điểm, định vị GPS, vẽ tuyến đường di chuyển giữa các điểm trong ngày.
- Gợi ý thứ tự di chuyển tối ưu để không bị đi vòng vèo.

#### Vấn đề kỹ thuật:
- Chi phí Google Maps Platform rất đắt nếu gọi API Directions và Places nhiều lần.

#### Giải pháp kỹ thuật:
- Sử dụng **Goong Maps** (chuyên cho bản đồ và địa chỉ tại Việt Nam) hoặc **Mapbox** có gói miễn phí ban đầu rất lớn.
- Với số điểm trong 1 ngày thường từ 3 - 6 điểm, áp dụng thuật toán **Greedy / Nearest Neighbor** trên Backend để tính toán thứ tự ghé thăm tối ưu nhất.

---

### 7. Phân hệ AI Travel Planner (Tính năng nâng cao)

#### Tính năng:
- Người dùng chỉ cần nhập: Điểm đến, số ngày, ngân sách, phong cách -> AI tự động sinh lịch trình hoàn chỉnh.

#### Giải pháp kỹ thuật:
- Gọi **Google Gemini API (Gemini 1.5 Flash)** với tham số `response_mime_type: "application/json"`.
- Ép kiểu dữ liệu trả về đúng JSON Schema của hệ thống (gồm tên chuyến đi, danh sách các ngày, hoạt động, thời gian, ước tính chi phí) để lưu trực tiếp vào cơ sở dữ liệu.

---

## TỔNG KẾT KIẾN TRÚC DỮ LIỆU ĐỀ XUẤT CHO CÁC TÍNH NĂNG MỚI

Để hiện thực hóa các tính năng trên, hệ thống sẽ cần các bảng dữ liệu cốt lõi sau trong PostgreSQL:
1. `users`: Tài khoản, trạng thái eKYC (`is_verified`), thông tin ngân hàng.
2. `companion_posts`: Bảng lưu các bài post tìm bạn đồng hành trên Newsfeed.
3. `companion_requests`: Yêu cầu tham gia bài post từ người khác.
4. `trips`: Chuyến đi (có `is_public`, `original_trip_id`, `clone_count`).
5. `itineraries`: Danh sách các ngày trong chuyến đi (Day 1, Day 2...).
6. `itinerary_items`: Chi tiết từng hoạt động/địa điểm trong ngày.
7. `places`: Kho dữ liệu địa điểm mẫu (có tọa độ, category phục vụ tính năng Smart Swap).
8. `expenses` & `expense_splits`: Quản lý chi tiêu và phân chia bill.
9. `settlements`: Các giao dịch nợ rút gọn đã được tính toán.
10. `trip_reviews`: Đánh giá chuyến đi và thành viên.

Đề tài: Xây dựng app hỗ trợ lập kế hoạch và quản lý hành trình du lịch 

Khó khăn khi lên lịch trình:
+ Không biết đi đâu :
+ Không biết sắp xếp lịch trình sao cho tối ưu, tiết kiệm
+ Lịch trình vứt lung tung trên mess, zalo, tiktok,…
+ Một người trong hội muốn tham gia (chi phí)

! Có 3 người đi du lịch, A trả tiền phòng hết 1tr7, B trả tiền nhà hàng 3tr, C trả tiền thuê xe 900k  Tối ưu giao dịch
5tr6 / 3 = 1tr866,67k
-	Tạo QR chuyển tiền và thông báo đã thanh toán thành công 
CÁC TÍNH NĂNG DỰ KIẾN CỦA ỨNG DỤNG
1. Phân hệ tài khoản và người dùng
Đăng ký và đăng nhập
•	Đăng ký / đăng nhập bằng:
o	Email và mật khẩu.
o	Google OAuth 2.0.
•	Xác thực email bằng OTP.
•	Quên mật khẩu / đặt lại mật khẩu.
•	Đổi mật khẩu.
•	Xác thực 2 bước (2FA) là chức năng mở rộng nếu cần tăng bảo mật.
Hồ sơ cá nhân
Người dùng có thể quản lý:
•	Ảnh đại diện.
•	Nickname (có thể trùng).
•	Username (duy nhất).
•	Họ và tên.
•	Số điện thoại.
•	Ngày sinh.
•	Giới tính.
•	Tiểu sử ngắn.
Trong đó chỉ một số thông tin cơ bản cần khai báo khi đăng ký; các thông tin còn lại có thể bổ sung sau.
Thông tin thanh toán
Người dùng có thể lưu:
•	Ngân hàng.
•	Số tài khoản.
•	Tên chủ tài khoản.
Thông tin này được sử dụng khi:
•	Chia chi phí chuyến đi.
•	Sinh mã QR chuyển khoản.
•	Thanh toán khoản nợ giữa các thành viên.
Không bắt buộc khai báo thông tin ngân hàng nếu người dùng không sử dụng chức năng Split Bill.
Xác minh danh tính
•	Người dùng có thể xác minh danh tính bằng CCCD.
•	Sau khi xác minh thành công, tài khoản hiển thị trạng thái "Đã xác minh".
Người chưa xác minh vẫn có thể:
•	Tạo chuyến đi cá nhân.
•	Tạo chuyến đi với bạn bè.
•	Tham gia nhóm thông qua lời mời từ người quen.
Người đã xác minh mới được:
•	Tạo chuyến đi công khai.
•	Tìm người đồng hành.
•	Gửi yêu cầu tham gia chuyến đi của người lạ.
•	Nhận yêu cầu tham gia từ người lạ.
Việc xác minh danh tính nhằm tăng mức độ tin cậy giữa các thành viên khi tham gia chuyến đi với người chưa quen.
________________________________________
2. Phân hệ quản lý chuyến đi
Tạo chuyến đi nhanh
Khi tạo chuyến đi, chỉ yêu cầu một số thông tin cơ bản:
•	Điểm đến.
•	Ngày bắt đầu.
•	Ngày kết thúc.
•	Hình thức chuyến đi:
o	Cá nhân.
o	Đi cùng bạn bè.
o	Nhóm riêng tư.
o	Nhóm công khai.
Các thông tin khác có thể bổ sung sau:
•	Tên chuyến đi.
•	Ngân sách dự kiến.
•	Mô tả.
•	Ghi chú.
•	Ảnh đại diện / ảnh bìa chuyến đi.
Hệ thống tự động:
•	Tính số ngày của chuyến đi.
•	Xác định trạng thái:
o	Sắp diễn ra.
o	Đang diễn ra.
o	Đã hoàn thành.
Quản lý chuyến đi
Người tạo chuyến đi có thể:
•	Chỉnh sửa thông tin.
•	Thay đổi quyền riêng tư.
•	Hủy chuyến đi.
•	Kết thúc chuyến đi.
•	Xem danh sách thành viên.
•	Truy cập lịch trình, chi phí và các hoạt động liên quan.
Người dùng có thể xem danh sách:
•	Chuyến đi sắp tới.
•	Chuyến đi đang diễn ra.
•	Chuyến đi đã hoàn thành.
________________________________________
 
3. Phân hệ nhóm du lịch
Mỗi chuyến đi có thể có một nhóm thành viên riêng.
Mời và tham gia nhóm
Người dùng có thể mời thành viên bằng:
•	Danh sách bạn bè.
•	Username.
•	Mã tham gia.
Đối với nhóm riêng tư:
•	Thành viên chỉ tham gia thông qua lời mời hoặc mã nhóm.
Đối với nhóm công khai:
•	Người dùng khác có thể gửi yêu cầu tham gia.
Quản lý thành viên
Trưởng nhóm có thể:
•	Chấp nhận / từ chối yêu cầu tham gia.
•	Xóa thành viên khỏi chuyến đi.
•	Chuyển quyền trưởng nhóm.
•	Quản lý quyền của thành viên.
Thành viên có thể:
•	Rời khỏi nhóm.
•	Xem lịch trình.
•	Đề xuất địa điểm.
•	Tham gia bình chọn.
•	Ghi nhận chi phí nếu được phép.
Phân quyền
Hệ thống có hai vai trò cơ bản:
Trưởng nhóm
•	Quản lý thông tin chuyến đi.
•	Quản lý thành viên.
•	Quản lý lịch trình chính.
•	Chốt các đề xuất của nhóm.
Thành viên
•	Xem thông tin chuyến đi.
•	Xem lịch trình.
•	Đề xuất hoạt động / địa điểm.
•	Vote.
•	Quản lý các khoản chi liên quan đến bản thân.
Không nên tạo quá nhiều role ở phiên bản đầu để tránh phức tạp hóa phân quyền.
________________________________________
4. Phân hệ tìm người đồng hành
Phân hệ này chỉ áp dụng đối với người dùng đã xác minh danh tính.
Công khai chuyến đi
Trưởng nhóm có thể chuyển chuyến đi sang trạng thái công khai để tìm thêm thành viên.
Khi công khai, có thể thiết lập:
•	Số lượng thành viên cần thêm.
•	Khoảng độ tuổi mong muốn (tùy chọn).
•	Mô tả ngắn về chuyến đi.
•	Một số yêu cầu hoặc lưu ý dành cho người muốn tham gia.
Các thông tin như điểm đến, ngày đi, số ngày và ngân sách được lấy trực tiếp từ chuyến đi, không yêu cầu nhập lại.
Tìm kiếm chuyến đi
Người dùng có thể tìm chuyến đi theo:
•	Điểm đến.
•	Khoảng thời gian.
•	Ngân sách dự kiến.
•	Số chỗ còn lại.
Có thể mở rộng thêm bộ lọc:
•	Độ tuổi.
•	Sở thích.
•	Phong cách du lịch.
Xem thông tin chuyến đi
Người dùng có thể xem:
•	Điểm đến.
•	Thời gian chuyến đi.
•	Số thành viên hiện tại.
•	Số người đang cần thêm.
•	Ngân sách dự kiến.
•	Mô tả chuyến đi.
•	Hồ sơ cơ bản của trưởng nhóm.
•	Trạng thái xác minh.
•	Điểm đánh giá sau các chuyến đi trước.
Không hiển thị công khai:
•	Số điện thoại.
•	CCCD.
•	Thông tin ngân hàng.
•	Các thông tin nhạy cảm khác.
Tham gia chuyến đi
Người dùng có thể:
•	Gửi yêu cầu tham gia.
•	Viết lời giới thiệu ngắn khi gửi yêu cầu.
•	Hủy yêu cầu khi chưa được duyệt.
Trưởng nhóm có thể:
•	Xem hồ sơ người gửi yêu cầu.
•	Xem trạng thái xác minh.
•	Xem đánh giá.
•	Chấp nhận hoặc từ chối.
Sau khi được chấp nhận, người dùng trở thành thành viên của nhóm du lịch và được truy cập các chức năng dành cho thành viên.

CÁC TÍNH NĂNG PHỤ TRỢ
5. Phân hệ lập và quản lý lịch trình
Người dùng có thể xây dựng lịch trình cho từng chuyến đi theo 3 cách:
•	Sử dụng lịch trình mẫu có sẵn.
•	Tự tạo lịch trình.
•	Sử dụng AI để gợi ý lịch trình nếu có triển khai tính năng nâng cao.
Lịch trình được chia theo từng ngày.
Người dùng có thể:
•	Thêm địa điểm hoặc hoạt động.
•	Xóa địa điểm / hoạt động.
•	Thay đổi thứ tự.
•	Chuyển hoạt động sang ngày khác.
•	Đánh dấu hoạt động đã hoàn thành.
Thông tin cơ bản của một hoạt động gồm:
•	Tên địa điểm / hoạt động.
•	Thời gian dự kiến.
•	Ghi chú.
Các thông tin khác như chi phí dự kiến có thể bổ sung nếu cần.
________________________________________
6. Phân hệ địa điểm và bản đồ
•	Tìm kiếm địa điểm.
•	Xem địa điểm trên bản đồ.
•	Thêm địa điểm trực tiếp vào lịch trình.
•	Hiển thị các địa điểm của chuyến đi trên bản đồ.
•	Xem khoảng cách giữa các địa điểm.
•	Hỗ trợ mở chỉ đường.
Tính năng mở rộng
•	Gợi ý thứ tự di chuyển hợp lý giữa các địa điểm.
•	Tối ưu tuyến đường để hạn chế đi vòng và tiết kiệm thời gian di chuyển.
________________________________________
7. Phân hệ quản lý ngân sách và chi phí
Người dùng có thể thiết lập ngân sách dự kiến cho chuyến đi.
Hệ thống hỗ trợ theo dõi:
•	Tổng ngân sách.
•	Tổng số tiền đã chi.
•	Số tiền còn lại.
Khi ghi nhận một khoản chi, người dùng chỉ cần nhập:
•	Số tiền.
•	Người thanh toán.
Có thể bổ sung:
•	Nội dung khoản chi.
•	Danh mục chi phí.
•	Những thành viên cùng sử dụng khoản chi.
Danh mục chi phí có thể gồm:
•	Ăn uống.
•	Di chuyển.
•	Khách sạn.
•	Vé tham quan.
•	Mua sắm.
•	Khác.
________________________________________
 
8. Phân hệ chia tiền - Split Bill
Áp dụng đối với chuyến đi có nhiều thành viên.
Hệ thống hỗ trợ:
•	Tính số tiền mỗi người phải chịu.
•	Theo dõi mỗi người đã thanh toán bao nhiêu.
•	Xác định ai đang nợ ai.
•	Tính số tiền cần chuyển để cân bằng chi phí.
Hỗ trợ các cách chia:
•	Chia đều.
•	Chia cho một số thành viên.
•	Chia số tiền khác nhau cho từng người.
Người dùng có thể:
•	Sinh mã QR chuyển khoản dựa trên thông tin ngân hàng của người nhận.
•	Đánh dấu khoản tiền đã thanh toán.
________________________________________
9. Phân hệ đánh giá và an toàn
Đặc biệt hỗ trợ các chuyến đi có người lạ tham gia.
Người dùng có thể:
•	Đánh giá thành viên sau chuyến đi.
•	Báo cáo người dùng.
•	Chặn người dùng.
•	Lưu người liên hệ khẩn cấp.
•	Chia sẻ lịch trình chuyến đi với người thân.
Tính năng mở rộng
•	Chia sẻ vị trí trong thời gian chuyến đi.
•	Gửi vị trí hiện tại cho người liên hệ khẩn cấp.
•	Nút SOS.
________________________________________
10. Phân hệ thông báo
Hệ thống gửi thông báo khi có các sự kiện quan trọng như:
•	Có lời mời tham gia chuyến đi.
•	Có yêu cầu tham gia chuyến đi.
•	Yêu cầu được chấp nhận hoặc từ chối.
•	Lịch trình có thay đổi.
•	Sắp đến thời gian của một hoạt động.
•	Có khoản tiền cần thanh toán.
Các thông báo ít quan trọng như bình chọn hoặc bình luận có thể chỉ hiển thị trong ứng dụng để tránh gây phiền.
________________________________________
11. Phân hệ quản trị Admin
Admin có thể:
Quản lý người dùng
•	Xem danh sách tài khoản.
•	Khóa / mở khóa tài khoản.
•	Xử lý tài khoản bị báo cáo.
•	Xem trạng thái xác minh người dùng.
Quản lý báo cáo
•	Xem nội dung báo cáo.
•	Xem người báo cáo và người bị báo cáo.
•	Cảnh cáo hoặc khóa tài khoản vi phạm.
Quản lý chuyến đi công khai
•	Xử lý chuyến đi bị báo cáo.
•	Ẩn hoặc xóa nội dung vi phạm.
Quản lý lịch trình mẫu
•	Tạo lịch trình mẫu.
•	Chỉnh sửa lịch trình mẫu.
•	Xóa lịch trình mẫu.
•	Quản lý các địa điểm có trong lịch trình mẫu.
________________________________________
12. AI Travel Planner - tính năng nâng cao
Người dùng cung cấp một số thông tin cơ bản:
•	Điểm đến.
•	Số ngày.
•	Ngân sách.
•	Sở thích.
AI có thể đề xuất:
•	Danh sách địa điểm phù hợp.
•	Lịch trình từng ngày.
•	Thứ tự địa điểm.
•	Chi phí dự kiến.
Người dùng có thể chỉnh sửa trước khi thêm lịch trình AI vào chuyến đi.
AI Travel Planner chỉ đóng vai trò hỗ trợ, không bắt buộc người dùng phải sử dụng.


CHƯƠNG 1. GIỚI THIỆU
1.1. Lý do chọn đề tài
Trong những năm gần đây, cùng với sự phát triển mạnh mẽ của công nghệ thông tin và mức sống của người dân, nhu cầu du lịch và khám phá những địa điểm mới ngày càng gia tăng. Đặc biệt, giới trẻ có xu hướng lựa chọn hình thức du lịch tự túc, chủ động tìm kiếm địa điểm, xây dựng lịch trình và quản lý chi phí thay vì phụ thuộc hoàn toàn vào các tour du lịch có sẵn.
Tuy nhiên, quá trình tổ chức một chuyến đi hiện nay vẫn còn khá phân tán. Người dùng thường phải sử dụng ứng dụng bản đồ để tìm kiếm địa điểm, ứng dụng ghi chú để xây dựng lịch trình, các công cụ khác để quản lý chi phí và các nền tảng nhắn tin để trao đổi với những người cùng tham gia. Điều này làm tăng số lượng thao tác, khó đồng bộ thông tin và gây bất tiện khi kế hoạch thay đổi.
Đối với các chuyến đi theo nhóm, người dùng còn gặp khó khăn trong việc thống nhất lịch trình, quản lý thành viên và chia các khoản chi phí phát sinh. Ngoài ra, một số người có nhu cầu tìm kiếm bạn đồng hành có cùng điểm đến và thời gian nhưng chưa có nhiều công cụ hỗ trợ quản lý toàn bộ quá trình từ tìm người, tạo nhóm đến lập kế hoạch chuyến đi trên cùng một nền tảng.
Từ những vấn đề trên, nhóm lựa chọn đề tài “Xây dựng ứng dụng di động hỗ trợ lập kế hoạch và quản lý hành trình du lịch” nhằm nghiên cứu và xây dựng một ứng dụng hỗ trợ người dùng quản lý chuyến đi thuận tiện, trực quan và tập trung hơn.
1.2. Mục tiêu của đề tài
Mục tiêu tổng quát của đề tài là phân tích, thiết kế và xây dựng một ứng dụng di động hỗ trợ người dùng lập kế hoạch, tổ chức và quản lý hành trình du lịch.
Các mục tiêu cụ thể gồm:
•	Phân tích và thiết kế hệ thống quản lý hành trình du lịch.
•	Xây dựng hệ thống tài khoản, đăng ký, đăng nhập và quản lý hồ sơ cá nhân.
•	Hỗ trợ đăng nhập bằng email và Google OAuth 2.0.
•	Xây dựng chức năng tạo, chỉnh sửa và quản lý chuyến đi.
•	Xây dựng chức năng quản lý nhóm du lịch và thành viên trong chuyến đi.
•	Hỗ trợ người dùng công khai chuyến đi và tìm kiếm người đồng hành phù hợp.
•	Xây dựng chức năng lập và quản lý lịch trình theo từng ngày.
•	Hỗ trợ tìm kiếm, lưu và hiển thị các địa điểm trong hành trình.
•	Xây dựng chức năng quản lý ngân sách và các khoản chi phí trong chuyến đi.
•	Xây dựng chức năng Split Bill để tính toán chi phí giữa các thành viên.
•	Hỗ trợ sinh mã QR chuyển khoản dựa trên thông tin ngân hàng của người nhận.
•	Xây dựng các chức năng đánh giá, báo cáo và hỗ trợ tăng mức độ an toàn khi tham gia chuyến đi với người lạ.
•	Xây dựng giao diện ứng dụng trực quan, tối giản số lượng thao tác người dùng.
•	Thực hiện kiểm thử và đánh giá hoạt động của hệ thống.
1.3. Giới hạn và phạm vi của đề tài
1.3.1. Phạm vi chức năng
Hệ thống tập trung xây dựng các nhóm chức năng chính:
Quản lý tài khoản
•	Đăng ký và đăng nhập.
•	Xác thực email.
•	Google OAuth 2.0.
•	Quên và thay đổi mật khẩu.
•	Quản lý hồ sơ cá nhân.
•	Quản lý thông tin tài khoản ngân hàng.
•	Xác minh danh tính đối với chức năng tham gia chuyến đi với người lạ.
Quản lý chuyến đi
•	Tạo chuyến đi.
•	Chỉnh sửa hoặc hủy chuyến đi.
•	Theo dõi chuyến đi sắp tới, đang diễn ra và đã hoàn thành.
•	Quản lý hình thức riêng tư hoặc công khai của chuyến đi.
Quản lý nhóm du lịch
•	Mời thành viên.
•	Tham gia bằng mã hoặc lời mời.
•	Gửi yêu cầu tham gia.
•	Quản lý thành viên.
•	Phân biệt trưởng nhóm và thành viên.
Tìm người đồng hành
•	Công khai chuyến đi.
•	Tìm chuyến đi theo địa điểm, thời gian và ngân sách.
•	Xem thông tin cơ bản của trưởng nhóm.
•	Gửi và xử lý yêu cầu tham gia.
Quản lý lịch trình
•	Xây dựng lịch trình theo từng ngày.
•	Thêm, xóa và thay đổi thứ tự địa điểm hoặc hoạt động.
•	Sử dụng lịch trình mẫu hoặc tự xây dựng lịch trình.
•	Theo dõi tiến độ thực hiện hành trình.
Quản lý địa điểm và bản đồ
•	Tìm kiếm địa điểm.
•	Thêm địa điểm vào lịch trình.
•	Hiển thị địa điểm trên bản đồ.
•	Hỗ trợ xem khoảng cách và tuyến đường.
Quản lý chi phí và Split Bill
•	Thiết lập ngân sách.
•	Ghi nhận các khoản chi.
•	Theo dõi tổng số tiền đã chi.
•	Xác định người thanh toán và người sử dụng khoản chi.
•	Tính số tiền giữa các thành viên.
•	Sinh QR chuyển khoản.
Đánh giá và an toàn
•	Đánh giá thành viên sau chuyến đi.
•	Báo cáo và chặn người dùng.
•	Hỗ trợ lưu người liên hệ khẩn cấp.
•	Chia sẻ thông tin hành trình với người thân.
Quản trị hệ thống
•	Quản lý tài khoản người dùng.
•	Khóa hoặc mở khóa tài khoản.
•	Xử lý các báo cáo vi phạm.
•	Quản lý chuyến đi công khai bị báo cáo.
•	Quản lý dữ liệu hoặc lịch trình mẫu của hệ thống.
1.3.2. Đối tượng sử dụng
Hệ thống hướng tới hai nhóm đối tượng chính:
Người dùng:
•	Người đi du lịch cá nhân.
•	Người đi du lịch cùng bạn bè hoặc theo nhóm.
•	Người có nhu cầu tìm người đồng hành.
Trong từng chuyến đi, người dùng có thể giữ vai trò:
•	Trưởng nhóm.
•	Thành viên.
Quản trị viên:
•	Quản lý tài khoản.
•	Xử lý báo cáo.
•	Kiểm soát nội dung và các chuyến đi công khai trong hệ thống.
1.3.3. Phạm vi dữ liệu
Hệ thống quản lý các nhóm dữ liệu chính:
•	Tài khoản và hồ sơ người dùng.
•	Thông tin xác minh.
•	Thông tin chuyến đi.
•	Thành viên chuyến đi.
•	Yêu cầu tham gia.
•	Lịch trình.
•	Địa điểm và hoạt động.
•	Ngân sách và các khoản chi.
•	Dữ liệu chia tiền và thanh toán.
•	Đánh giá.
•	Báo cáo vi phạm.
•	Thông báo.
•	Hình ảnh và các tệp liên quan.
1.3.4. Giới hạn của đề tài
Do đề tài được thực hiện trong phạm vi đồ án môn học và giới hạn về thời gian, hệ thống chủ yếu tập trung vào các chức năng hỗ trợ lập kế hoạch và quản lý hành trình du lịch.
Một số giới hạn gồm:
•	Chưa triển khai thương mại ở quy mô lớn.
•	Không thực hiện nghiệp vụ đặt vé máy bay, khách sạn hoặc tour trực tiếp.
•	Chức năng thanh toán chủ yếu hỗ trợ tạo QR chuyển khoản và ghi nhận trạng thái thanh toán, không đóng vai trò như một ví điện tử.
•	Xác minh CCCD chỉ phục vụ mô phỏng quy trình xác minh danh tính trong hệ thống; đề tài không kết nối trực tiếp với Cơ sở dữ liệu quốc gia về dân cư.
•	Các chức năng theo dõi vị trí thời gian thực và SOS có thể được xem là chức năng mở rộng.
•	AI tạo lịch trình và tối ưu tuyến đường nâng cao được xem là hướng phát triển nếu thời gian thực hiện cho phép.
1.4. Kết quả dự kiến đạt được
Sau khi hoàn thành, đề tài dự kiến đạt được các kết quả:
•	Xây dựng được ứng dụng di động hỗ trợ lập kế hoạch và quản lý hành trình du lịch.
•	Xây dựng hệ thống tài khoản, xác thực và phân quyền người dùng.
•	Xây dựng chức năng tạo và quản lý chuyến đi cá nhân hoặc theo nhóm.
•	Xây dựng chức năng tìm và tham gia chuyến đi công khai.
•	Xây dựng chức năng lập và chỉnh sửa lịch trình.
•	Tích hợp bản đồ và dữ liệu địa điểm phục vụ hành trình.
•	Xây dựng chức năng quản lý ngân sách và chi phí.
•	Xây dựng chức năng Split Bill và tạo QR chuyển khoản.
•	Xây dựng các chức năng đánh giá, báo cáo và quản lý người dùng.
•	Xây dựng giao diện ứng dụng thân thiện, trực quan và tối giản thao tác.
•	Xây dựng Backend và RESTful API phục vụ ứng dụng di động.
•	Hoàn thiện cơ sở dữ liệu PostgreSQL và hệ thống lưu trữ tệp.
•	Triển khai Backend và cơ sở dữ liệu lên môi trường trực tuyến.
•	Thực hiện kiểm thử các chức năng chính và sửa các lỗi phát sinh.
•	Hoàn thành sản phẩm và báo cáo đồ án.
 
CHƯƠNG 2. KIẾN THỨC NỀN TẢNG
2.1. Cơ sở lý thuyết
2.1.1. Cơ sở lý thuyết về ứng dụng hỗ trợ lập kế hoạch và quản lý hành trình du lịch
Ứng dụng hỗ trợ lập kế hoạch và quản lý hành trình du lịch là hệ thống giúp người dùng tổ chức các thông tin liên quan đến một chuyến đi trên cùng một nền tảng. Thông qua ứng dụng, người dùng có thể tạo chuyến đi, xây dựng lịch trình, quản lý địa điểm, theo dõi ngân sách và phối hợp với những người cùng tham gia.
Quá trình quản lý hành trình có thể được chia thành ba giai đoạn chính:
•	Trước chuyến đi: Người dùng lựa chọn điểm đến, tạo chuyến đi, xây dựng lịch trình, dự kiến ngân sách và mời các thành viên cùng tham gia.
•	Trong chuyến đi: Người dùng theo dõi lịch trình, xem các địa điểm cần đến, cập nhật hoạt động và ghi nhận các khoản chi phí phát sinh.
•	Sau chuyến đi: Người dùng có thể xem lại lịch sử hành trình, tổng hợp chi phí và đánh giá các thành viên hoặc địa điểm đã trải nghiệm.
Đối với chuyến đi theo nhóm, ứng dụng còn hỗ trợ quản lý thành viên, chia sẻ lịch trình và quản lý chi phí chung. Việc số hóa quá trình lập kế hoạch giúp người dùng giảm bớt việc phải sử dụng nhiều ứng dụng khác nhau, đồng thời giúp thông tin của chuyến đi được tổ chức tập trung và dễ theo dõi hơn. Nội dung này phù hợp với định hướng hiện tại của đề tài về lập lịch trình, quản lý địa điểm, chi phí và hành trình du lịch.
2.1.2. Cơ sở lý thuyết về kiến trúc Client – Server
Kiến trúc Client – Server là mô hình trong đó hệ thống được chia thành hai thành phần chính là Client và Server.
•	Client là phía người dùng trực tiếp tương tác với hệ thống. Trong đề tài, Client là ứng dụng di động được xây dựng bằng Flutter.
•	Server là phía tiếp nhận yêu cầu từ Client, xử lý nghiệp vụ, truy xuất dữ liệu và trả kết quả về cho ứng dụng.
Khi người dùng thực hiện một thao tác, ví dụ tạo chuyến đi hoặc xem lịch trình, Client sẽ gửi một yêu cầu tới Server. Server xử lý yêu cầu, làm việc với cơ sở dữ liệu nếu cần và gửi dữ liệu phản hồi lại cho Client.
Hệ thống có thể được tổ chức theo mô hình ba tầng:
•	Presentation Layer: Giao diện ứng dụng di động.
•	Business Logic Layer: Xử lý nghiệp vụ ở Backend.
•	Data Layer: Lưu trữ và quản lý dữ liệu.
Trong đề tài, Flutter đảm nhiệm tầng giao diện, Node.js kết hợp Express.js đảm nhiệm tầng nghiệp vụ và PostgreSQL đảm nhiệm tầng dữ liệu.
2.1.3. Cơ sở lý thuyết về RESTful API
REST là một phong cách kiến trúc thường được sử dụng để xây dựng các dịch vụ Web. RESTful API cho phép Client và Server giao tiếp với nhau thông qua giao thức HTTP.
Trong RESTful API, dữ liệu của hệ thống được biểu diễn dưới dạng các Resource như người dùng, chuyến đi, lịch trình hoặc khoản chi phí. Mỗi Resource được quản lý thông qua các API tương ứng.
Một đặc điểm quan trọng của REST là Stateless, nghĩa là mỗi yêu cầu từ Client gửi đến Server phải chứa đầy đủ thông tin cần thiết để Server xử lý.
Dữ liệu trao đổi giữa Client và Server thường sử dụng định dạng JSON.
Các phương thức HTTP chính gồm:
•	GET: Dùng để lấy dữ liệu.
•	POST: Dùng để tạo mới dữ liệu.
•	PUT/PATCH: Dùng để cập nhật dữ liệu.
•	DELETE: Dùng để xóa dữ liệu.
Trong đề tài, RESTful API được sử dụng làm cầu nối giữa ứng dụng Flutter và Backend Node.js/Express.js.
2.1.4. Cơ sở lý thuyết về xác thực và phân quyền
Xác thực (Authentication) là quá trình kiểm tra danh tính của người dùng trước khi cho phép truy cập vào hệ thống.
Phân quyền (Authorization) là quá trình xác định những chức năng mà người dùng được phép thực hiện sau khi đăng nhập.
Trong hệ thống, người dùng có thể đăng nhập bằng email và mật khẩu hoặc thông qua Google OAuth 2.0. Email có thể được xác thực bằng mã OTP.
Mật khẩu người dùng không được lưu trực tiếp mà cần được băm trước khi lưu vào cơ sở dữ liệu nhằm tăng tính bảo mật.
Hệ thống sử dụng JWT (JSON Web Token) để hỗ trợ xác thực người dùng. Sau khi đăng nhập thành công, Server tạo token và gửi về ứng dụng. Trong các yêu cầu tiếp theo, Client gửi token kèm theo request để Server xác định người dùng.
Về phân quyền, hệ thống có các nhóm quyền cơ bản:
•	User: Sử dụng các chức năng thông thường của ứng dụng.
•	Admin: Quản lý người dùng và các nội dung trong hệ thống.
Trong từng chuyến đi còn có:
•	Trưởng nhóm: Quản lý thông tin chuyến đi, thành viên và lịch trình.
•	Thành viên: Xem lịch trình, đề xuất hoạt động và quản lý các nội dung được phép.
2.1.5. Cơ sở lý thuyết về quản lý chi phí nhóm
Quản lý chi phí nhóm là chức năng hỗ trợ theo dõi các khoản tiền phát sinh trong quá trình đi du lịch.
Mỗi chuyến đi có thể thiết lập một ngân sách dự kiến để người dùng theo dõi tổng chi tiêu.
Một khoản chi có thể bao gồm:
•	Số tiền.
•	Nội dung chi.
•	Người đã thanh toán.
•	Những thành viên cùng sử dụng khoản chi.
Đối với chuyến đi nhóm, hệ thống có thể áp dụng chức năng Split Bill để chia chi phí giữa các thành viên.
Ví dụ, nếu một người thanh toán tiền khách sạn cho cả nhóm, hệ thống sẽ tính phần chi phí mà từng người cần chịu. Sau khi tổng hợp các khoản chi, hệ thống xác định:
•	Mỗi người đã thanh toán bao nhiêu.
•	Mỗi người thực tế phải chịu bao nhiêu.
•	Ai đang nợ ai.
•	Số tiền cần thanh toán giữa các thành viên.
Chức năng này giúp giảm việc tính toán thủ công và giúp quản lý chi phí trong chuyến đi rõ ràng hơn.
2.2. Công nghệ và công cụ sử dụng
2.2.1. Node.js
Node.js là môi trường chạy JavaScript ở phía Server. Node.js được xây dựng trên V8 JavaScript Engine và hỗ trợ mô hình xử lý bất đồng bộ.
Node.js sử dụng cơ chế Non-blocking I/O và Event-driven, giúp Server có thể xử lý nhiều yêu cầu mà không cần chờ từng tác vụ hoàn thành theo thứ tự.
Trong đề tài, Node.js được sử dụng làm nền tảng chính để xây dựng Backend, tiếp nhận yêu cầu từ ứng dụng Flutter, xử lý nghiệp vụ và trả dữ liệu về Client thông qua RESTful API.
2.2.2. Express.js
Express.js là một framework Web được xây dựng trên Node.js, thường được sử dụng để phát triển Web API và Backend.
Express.js hỗ trợ:
•	Xây dựng các Route.
•	Tiếp nhận HTTP Request.
•	Trả HTTP Response.
•	Sử dụng Middleware.
•	Xây dựng Controller.
•	Xử lý lỗi.
Trong đề tài, Express.js được sử dụng cùng Node.js để xây dựng các RESTful API phục vụ các chức năng như quản lý tài khoản, chuyến đi, lịch trình và chi phí.
Middleware có thể được sử dụng cho các chức năng dùng chung như kiểm tra token, xác thực người dùng và kiểm tra dữ liệu đầu vào.
2.2.3. Flutter
Flutter là framework mã nguồn mở được sử dụng để xây dựng ứng dụng đa nền tảng từ một mã nguồn chung.
Flutter sử dụng ngôn ngữ lập trình Dart và xây dựng giao diện thông qua hệ thống Widget.
Một số đặc điểm chính của Flutter gồm:
•	Hỗ trợ xây dựng giao diện linh hoạt.
•	Có thể tái sử dụng Widget.
•	Hỗ trợ phát triển đa nền tảng.
•	Có tính năng Hot Reload giúp quan sát nhanh các thay đổi trong quá trình lập trình.
Trong đề tài, Flutter được sử dụng để xây dựng toàn bộ giao diện của ứng dụng di động và thực hiện giao tiếp với Backend thông qua RESTful API.
2.2.4. PostgreSQL
PostgreSQL là hệ quản trị cơ sở dữ liệu quan hệ mã nguồn mở, sử dụng ngôn ngữ SQL để quản lý và truy vấn dữ liệu.
PostgreSQL hỗ trợ các thành phần quan trọng như:
•	Khóa chính.
•	Khóa ngoại.
•	Transaction.
•	Ràng buộc dữ liệu.
•	View.
•	Trigger.
Trong đề tài, PostgreSQL được sử dụng làm cơ sở dữ liệu chính của hệ thống, lưu trữ các dữ liệu như người dùng, chuyến đi, thành viên, lịch trình, chi phí và các thông tin liên quan.
Việc sử dụng khóa chính, khóa ngoại và các ràng buộc giúp đảm bảo tính toàn vẹn và nhất quán của dữ liệu.
2.2.5. Supabase
Supabase là nền tảng Backend-as-a-Service cung cấp nhiều dịch vụ hỗ trợ phát triển ứng dụng.
Trong đề tài, Supabase được sử dụng chủ yếu cho chức năng Storage, phục vụ việc lưu trữ các tệp và hình ảnh như:
•	Ảnh đại diện người dùng.
•	Ảnh địa điểm.
•	Ảnh liên quan đến chuyến đi.
Supabase Storage cho phép tạo các Bucket để phân loại tệp. Sau khi tệp được tải lên, hệ thống có thể sử dụng URL để truy cập hình ảnh.
Backend chỉ cần lưu đường dẫn URL của tệp trong PostgreSQL thay vì lưu trực tiếp dữ liệu hình ảnh vào cơ sở dữ liệu. Cách này giúp giảm dung lượng lưu trữ trong Database và dễ quản lý hơn.
2.2.6. Cloudinary
Cloudinary là nền tảng quản lý và lưu trữ tệp đa phương tiện trên đám mây (Cloud-based Media Management).
Trong đề tài, Cloudinary được sử dụng để:
•	Lưu trữ ảnh đại diện người dùng (Avatar).
•	Lưu trữ ảnh bìa chuyến đi và ảnh các bài đăng tìm bạn đồng hành.
•	Lưu trữ ảnh hóa đơn chi tiêu phục vụ tính năng Split Bill.
•	Tự động tối ưu hóa dung lượng ảnh, cắt chỉnh tỷ lệ (Crop/Resize) trước khi trả về URL CDN tốc độ cao cho ứng dụng Flutter.
2.2.7. Postman
Postman là công cụ hỗ trợ xây dựng và kiểm thử API.
Postman cho phép lập trình viên gửi các HTTP Request như:
•	GET.
•	POST.
•	PUT.
•	PATCH.
•	DELETE.
Sau khi gửi request, Postman cho phép kiểm tra:
•	Status Code.
•	Response Body.
•	Header.
•	Dữ liệu JSON.
•	Thông tin Authentication.
Ngoài ra, Postman hỗ trợ Collection để nhóm các API và Environment để quản lý các biến cấu hình.
Trong đề tài, Postman được sử dụng để kiểm thử các RESTful API trước khi tích hợp Backend với ứng dụng Flutter.
2.2.8. Git và GitHub
Git là hệ thống quản lý phiên bản mã nguồn, giúp theo dõi các thay đổi trong quá trình phát triển phần mềm.
Một số thao tác thường được sử dụng gồm:
•	Commit: Lưu lại một phiên bản thay đổi.
•	Branch: Tạo nhánh phát triển riêng.
•	Merge: Gộp thay đổi giữa các nhánh.
GitHub là nền tảng hỗ trợ lưu trữ repository Git trực tuyến và hỗ trợ làm việc nhóm.
Khi phát triển dự án, mỗi thành viên có thể làm việc trên các branch riêng. Sau khi hoàn thành chức năng, mã nguồn có thể được kiểm tra và gộp vào nhánh chính thông qua Pull Request.
Việc sử dụng Git và GitHub giúp nhóm quản lý mã nguồn, theo dõi lịch sử thay đổi và hạn chế xung đột trong quá trình làm việc chung.
2.2.9. Railway
Railway là nền tảng hỗ trợ triển khai ứng dụng lên môi trường trực tuyến.
Railway hỗ trợ triển khai:
•	Backend Node.js/Express.js.
•	PostgreSQL.
•	Biến môi trường.
•	Theo dõi Log.
•	Quản lý Deployment.
Trong đề tài, Railway được sử dụng để triển khai Backend và cơ sở dữ liệu PostgreSQL, giúp Server có thể được truy cập thông qua Internet thay vì chỉ chạy trên máy tính cá nhân.
Railway cũng có thể kết nối với repository GitHub để tự động thực hiện quá trình build và triển khai khi có phiên bản mới của hệ thống.
 

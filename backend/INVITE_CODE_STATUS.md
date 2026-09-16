# Trạng thái mã mời một lần

`trips.invite_code_status` độc lập với `trips.status` (trạng thái chuyến đi).

| Trạng thái | Ý nghĩa |
| --- | --- |
| NONE | Không có mã (`invite_code IS NULL`) |
| ACTIVE | Mã hiện tại có thể được dùng nếu người tham gia đủ điều kiện |
| USED | Mã đã được sử dụng, giữ giá trị mã để phân biệt với chưa từng cấp |
| REVOKED | Mã đã bị vô hiệu hóa |

Mỗi chuyến đi vẫn chỉ có một mã hiện tại, không tạo bảng bản ghi mã tăng liên tục.
Trigger tự đặt ACTIVE khi tạo/thay mã, NONE khi xóa mã. Cập nhật thông tin chuyến đi
khác không làm mã USED/REVOKED hoạt động lại. AI Planner cũng ghi ACTIVE khi tạo mã.
Chưa có thời hạn hoặc tự động hết hạn trong thay đổi này.

## Phú tích hợp luồng tham gia

Trong cùng một transaction:
1. Tìm chuyến đi theo `invite_code` với `SELECT ... FOR UPDATE`.
2. Kiểm tra `invite_code_status = 'ACTIVE'` và điều kiện tham gia, bao gồm ngân hàng
   đã liên kết, chưa là thành viên, chuyến đi còn nhận người theo quy tắc đã thống nhất.
3. Thêm thành viên vào `trip_members`.
4. Cập nhật `invite_code_status = 'USED'`, giữ lại mã; commit.

Nếu bất kỳ bước nào thất bại, rollback toàn bộ để mã không bị tiêu hao.
Các request sau phải kiểm tra lại trạng thái sau khi giữ được khóa hàng. Không tự đổi USED
thành ACTIVE với cùng mã. Muốn mời người tiếp theo, sinh mã mới duy nhất.

Schema chỉ cung cấp trạng thái và tính nhất quán mã/trạng thái. Nó không tự triển khai
API join hoặc tự đổi USED chỉ vì có người được thêm vào nhóm (người đó có thể vào qua ghép đoàn).

## Migration

Migration `003_invite_code_status.sql` chuyển mã cũ đang có thành ACTIVE, không có mã thành NONE.
Không có dữ liệu lịch sử để xác định mã cũ từng được sử dụng hay chưa.
Migration không sửa `trips.status`, không xóa chuyến đi/thành viên/mã hiện có.
Chạy toàn bộ migration theo quy trình thông thường với `npm run db:migrate`.
Script `node scripts/apply-invite-code-status.js` chỉ áp dụng 003 lên Supabase đã cấu hình,
không tự chạy các migration khác đang thiếu. Cần có bảng schema_migrations.

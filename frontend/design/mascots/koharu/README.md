# Koharu chibi pixel asset pack

Giải nén rồi mở preview.html bằng trình duyệt. Không cần cài đặt hoặc mạng.

- spritesheets/koharu_all.png: sheet tổng 384×784, 4 cột × 7 hàng.
- Mỗi cell: 96×112 px. Đọc từ trái sang phải, trên xuống dưới.
- Bản @4x: mỗi cell 384×448 px, phóng nearest-neighbor.
- spritesheets/koharu_<name>.png: sheet riêng 4 frame, 384×112.
- frames/koharu_<name>/00.png đến 03.png: frame PNG alpha thật.
- previews/: GIF từng động tác, GIF tổng và contact sheet.
- animations.json: tên, hàng, chỉ số frame, thời lượng.
- source/: ảnh pixel gốc tạo bằng imagegen.
- references/: ảnh nhân vật do người dùng cung cấp.
- tools/build.py: script tách, căn chân và dựng lại sheet/preview (Python, Pillow, numpy).
- validation.json: kết quả kiểm tra cấu trúc.

Thứ tự hàng (đánh số từ 0):
0 koharu_idle
1 koharu_welcome
2 koharu_point_left (bên trái người xem)
3 koharu_point_up
4 koharu_talking
5 koharu_success
6 koharu_explain

Dùng khoảng 4–5 fps; idle có thời gian giữ mở mắt dài hơn. Dùng nearest-neighbor / image-rendering: pixelated để giữ cạnh pixel. Điểm neo gợi ý: giữa cạnh dưới cell (48,112). Chân cách cạnh dưới 9px.

Đây là bộ 7 động tác giao diện theo yêu cầu, 4 keyframe/động tác; có thể còn dao động nhẹ nét tóc và khuôn mặt giữa frame do ảnh nguồn sinh bằng AI. Không phải bộ rig tách lớp hay bộ pet 16 hướng. GIF có nền sáng để xem; PNG mới là nguồn trong suốt.

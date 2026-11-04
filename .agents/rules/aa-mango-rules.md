# AA mango — Hard Rules

### 1. Phân vùng quyền hạn
- `D:\Macro\AA mango`: **PROD (Hệ thống gốc / Cấp cao nhất)**. Trạng thái **READ-ONLY đối với Agent**. Mọi thao tác sửa file PROD bắt buộc phải qua 4 bước: Test ở DEV -> Trình diff & bằng chứng -> Hỏi User -> Chỉ sửa khi User đồng ý.
- `D:\Macro\AA-mango-dev`: **DEV (Sandbox thử nghiệm)**. Agent viết script test, đo đạc tọa độ, tạo probe, chạy mock tại đây. Được phép include thư viện từ PROD.
- AHK Interpreter: `C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe`.
- Chi tiết quy tắc toàn diện: Xem tại `D:\Macro\AGENTS.md`.

### 2. Điều kiện cấm tuyệt đối (Strict Non-Negotiables)
- **CẤM XÓA/SỬA TÍNH NĂNG ĐÃ XÂY DỰNG**:
  - Tuyệt đối cấm xóa tính năng giải/nhập Captcha (`CaptchaDetect`), giải mã OCR, logic click `FixClick`, `FixMove`.
  - Không được viện cớ chính sách an toàn AI hay dọn dẹp code thừa để xóa tính năng của User.
- **Không tự ý refactor / format lại code**: Không format, không đổi tên biến/hàm, không xóa comment khi chưa có yêu cầu.
- **Giữ chuẩn input Roblox**: Bắt buộc giữ `SendMode "Event"` và các helper `FixClick` / `FixMove`. Không dùng `MouseClick` hoặc `SendInput` trực tiếp.

### 3. Nguồn sự thật
- `AgentOnly.md`: Nhãn hàm và trạng thái khóa — User sở hữu, Agent chỉ đọc.
- `context.md`: Nhật ký bằng chứng sau khi User đã duyệt sửa PROD — Agent append.
- `Settings\Configuration.txt`: Cấu hình macro của người dùng.

### 4. Quy trình sửa & Validate PROD
- Chỉ sửa đúng phạm vi User giao và đã được User phê duyệt diff.
- Validate bắt buộc sau mỗi lần sửa PROD:
  `& "C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut /Validate "D:\Macro\AA mango\Main.ahk"`
  (Phải trả về `exit=0` và không có lỗi load-time).
- Cấm tạo file tạm, file log kiểm thử trong cây thư mục PROD (file tạm đưa vào DEV).

---
name: aa-mango-skills
description: Mục lục skill và tài liệu của macro Anime Adventures (AA mango). Đọc khi cần biết file nào là nguồn chuẩn trước khi sửa macro, chạy harness, validate AHK hay cập nhật tài liệu.
---
# AA mango — mục lục skill

Chỉ trỏ tới bản chuẩn. Không chép nội dung skill/tài liệu vào file này.

| Skill | Đường dẫn | Dùng khi |
|---|---|---|
| `aa-macro` (**bản chuẩn**) | `C:\Users\thoan\.config\opencode\skills\aa-macro\SKILL.md` | Mọi việc với macro: protocol, gotcha AHK v2/Roblox, validate, định dạng báo cáo |
| `ahk-v2` | `C:\Users\thoan\.gemini\config\skills\ahk-v2\SKILL.md` | Cú pháp AHK v2, scoping, tham số `&out`, GDI+, `/Validate` |
| `aa-mango-macro` | `C:\Users\thoan\.gemini\config\skills\aa-mango-macro\SKILL.md` | Con trỏ cho Antigravity → trỏ về `aa-macro` |

Tài liệu dự án (project `D:\Macro\AA mango`):

| File | Vai trò | Ai sửa |
|---|---|---|
| `AgentOnly.md` | Bản đồ hàm + nhãn WORKING/BUGGING/SYSTEM | **Chỉ user** — agent chỉ đọc |
| `context.md` | Nhật ký bằng chứng sau khi đã impact thật | Agent append |
| `D:\Macro\AA-mango-dev\README.md` | Snapshot / Calibrate / TestState | User giao |

Đọc theo thứ tự khi làm task code: `context.md` → mục liên quan trong `AgentOnly.md` → đúng skill ở bảng trên.

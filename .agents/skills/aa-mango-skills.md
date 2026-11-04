---
name: aa-mango-skills
description: Mục lục tài liệu và skill của macro Anime Adventures (AA mango). Đọc khi cần biết file nào là nguồn chuẩn trước khi sửa macro, chạy test, validate AHK hay cập nhật tài liệu.
---
# AA mango — mục lục

Chỉ trỏ tới bản chuẩn. Không chép nội dung vào file này.

## Nguồn chuẩn

| File | Vai trò | Ai sửa |
|---|---|---|
| `D:\Macro\AGENTS.md` | **Luật duy nhất**: quyền tự chủ, bất biến, quy trình, định nghĩa xong | User + agent (khi được yêu cầu) |
| `D:\Macro\ARCHITECTURE.md` | Kiến trúc, luồng 5 giai đoạn | User + agent |
| `D:\Macro\context.md` | Nhật ký bằng chứng; agent chỉ đọc 60 dòng cuối | Agent append |
| `D:\Macro\AA-mango-dev\check-invariants.ps1` | Validate + kiểm tra bất biến | Agent |
| `D:\Macro\AA-mango-dev\Tests\` | Test offline | Agent |

`AgentOnly.md` đã bỏ (archive: `AA-mango-dev\archive\AgentOnly-2026-11-04.md`). Không tạo lại bảng nhãn hàm.

## Skill

| Skill | Đường dẫn | Dùng khi |
|---|---|---|
| `aa-macro` | `C:\Users\thoan\.config\opencode\skills\aa-macro\SKILL.md` | Quy trình quan sát, validate, gotcha AHK v2/Roblox |
| `aa-macro` (Codex) | `C:\Users\thoan\.codex\skills\aa-macro\SKILL.md` | Bản sao cho Codex |
| `ahk-v2` | `C:\Users\thoan\.gemini\config\skills\ahk-v2\SKILL.md` | Cú pháp AHK v2, scoping, GDI+, `/Validate` |

## Thứ tự đọc khi làm task code

1. `AGENTS.md`
2. 60 dòng cuối `context.md`
3. `grep` tên hàm trong `D:\Macro\AA mango\Lib\*.ahk`
4. Skill `aa-macro` nếu cần quy trình

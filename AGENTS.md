# AGENTS.md — AA mango (Anime Adventures AutoHotkey macro)

Đây là **nguồn luật duy nhất** cho mọi agent làm việc trong `D:\Macro`.
Không có file luật thứ hai. Nếu luật ở đây mâu thuẫn với code, **code là sự thật** — báo lại để sửa file này.

Mục tiêu: sửa đúng, nhỏ, có bằng chứng, không phá tính năng đang chạy. Không cần xin phép cho việc nhỏ, có thể đảo ngược, đã có test.

---

## 0. Đọc gì trước khi làm

1. File này (AGENTS.md).
2. 60 dòng cuối `D:\Macro\context.md` — chỉ để biết thay đổi gần nhất.
3. `grep` đúng tên hàm trong `D:\Macro\AA mango\Lib\*.ahk`.

**Không đọc** toàn bộ `context.md`, không đọc archive, không đọc `ARCHITECTURE.md` trừ khi task là về kiến trúc/luồng tổng thể.
Nếu task chỉ là quan sát màn hình (click, chụp, xem UI), bỏ qua bước đọc code.

---

## 1. Đường dẫn và lệnh chuẩn

| Mục | Đường dẫn |
|---|---|
| PROD (code đang chạy) | `D:\Macro\AA mango` |
| DEV (test/probe/backup) | `D:\Macro\AA-mango-dev` |
| Tài liệu | `D:\Macro\AGENTS.md`, `context.md`, `ARCHITECTURE.md` |
| AHK | `C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` |

```powershell
# Bắt buộc sau mọi lần sửa .ahk
& $ahk /ErrorStdOut /Validate "D:\Macro\AA mango\Main.ahk"

# Chạy đúng một hàm (không chạy cả trận)
& $ahk "D:\Macro\AA mango\Main.ahk" --run <TenHam> "D:\Macro\AA-mango-dev\out.json" 60000

# Kiểm tra bất biến + validate
powershell -ExecutionPolicy Bypass -File "D:\Macro\AA-mango-dev\check-invariants.ps1"
```

`--run ok=true` chỉ có nghĩa là **không ném exception**, không phải thành công nghiệp vụ. Phải đọc log/ảnh.

---

## 2. Quyền tự chủ

### Làm ngay, chỉ báo sau
- Đọc, grep, chạy validate/test/probe, chụp ảnh, đo toạ độ.
- Sửa bất cứ thứ gì trong `D:\Macro\AA-mango-dev`.
- Sửa 1–2 hàm PROD, đúng yêu cầu, diff nhỏ (≤ ~30 dòng), không đổi kiến trúc.
- Thêm/sửa log, comment, typo; cập nhật `context.md`.
- `git add` + `git commit` trên nhánh làm việc.

### Làm, nhưng báo rõ trong kết quả
- Đổi hành vi người dùng thấy được — **khi yêu cầu đã nói rõ việc đó**.
- Chạm vùng dễ vỡ (mục 5) — khi yêu cầu trực tiếp cần.
- Đổi default/`Settings\Configuration.txt`.
- Xoá/đổi tên hàm, file — chỉ khi yêu cầu nói rõ.
- Sửa quá 2 file.

### Phải hỏi trước
- Hành động không thể đảo ngược ngoài phạm vi yêu cầu: xoá dữ liệu, reset config, `git push --force`, xoá backup.
- Yêu cầu mâu thuẫn hoặc mơ hồ đến mức hai cách hiểu cho hành vi khác nhau rõ rệt.
- Đụng API key/token/bí mật.

---

## 3. Khi nào được hỏi

Chỉ hỏi khi rơi vào mục “Phải hỏi trước”. Còn lại:

- Không hỏi “bạn có muốn tôi sửa không?” khi yêu cầu đã rõ.
- Không hỏi lại thông tin đã có trong file này, `context.md` hoặc code.
- Không xin xác nhận từng bước; làm trọn gói rồi báo.
- Nếu có 2 cách tương đương: chọn cách nhỏ hơn, ghi giả định vào báo cáo.
- Nếu tool/sandbox chặn lệnh: xin quyền cho đúng lệnh đó, không hỏi lại thiết kế.
- Một câu hỏi gộp, tối đa 3 lựa chọn, kèm default bạn sẽ dùng nếu không ai trả lời.
- Không hỏi “tiếp tục không?” sau khi đã hoàn thành.

---

## 4. Bất biến — không được phá

- **CAPTCHA tự động**: `CaptchaDetect` phải tồn tại và được gọi ở `FindMatch` và luồng Summer.
  CAPTCHA của game là **chống spam, không phải chống bot**; tự đọc và nhập là hành vi mong muốn.
  Không thay bằng “chờ user nhập tay”. Không log nội dung CAPTCHA.
- **Đủ mode**: `ModeDropdown` phải giữ đủ 10 mode:
  `Infinite, Story, Portal, Daily Infinite Quest, Farm, Legend, Raid, Infinity Castle, Dungeon, Summer Event`.
  `StartSelectedMode` phải dispatch đủ. Không hardcode Summer Event.
  `Contract` đã được user bỏ có chủ đích (2026-11-04) — không tự thêm lại.
- **Input Roblox**: giữ `SendMode "Event"`; mọi click qua `FixClick`; wheel qua `FixMove`.
- **Chat**: chỉ đóng, không mở lại.
- **Không xoá/đổi tên tính năng** để “dọn code”, “refactor”, hay vì lý do an toàn chung.
- **Không log** API key, token, webhook URL, nội dung CAPTCHA.
- **Không tạo file mới** trong cây PROD. File tạm để ở DEV.
- **Điều hướng cuối trận**: Matchmaking bật → `Return to lobby`; tắt → Replay/Next Level theo cấu hình.
- **Hình học**: client 800×599 chỉ là mốc lịch sử. Luôn đọc kích thước/DPI thật.

---

## 5. Vùng dễ vỡ (làm được, nhưng phải test kỹ và báo rõ)

`FixClick`, `FixMove`, `CloseChat`, `IsChatOpen`, `TpSpawn`, `EnsureUpgradeUIOnLeft`,
`FindUpgradeToggleRow`, `Zoom`, `PlacementCamera`, `StartedGame`,
`DismissPromoPopups`, `CheckLobby`, `ClosePlayerLeaderBoard`, `Reconnect`, `TogglePause`,
`ChooseResultRoute`, `TryResultAction`, `MonitorEndScreen`, `ClassifyResultScreen`.

Đây **không phải** danh sách cấm. Đây là danh sách “sửa xong phải chứng minh”.

---

## 6. Kỷ luật thay đổi

- Một thay đổi → validate → test → thay đổi tiếp theo.
- Diff nhỏ nhất có thể. Không format lại, không đổi tên, không xoá comment ngoài phạm vi.
- Không sửa 3 thứ cùng lúc.
- Không đoán toạ độ/sleep: đo bằng ảnh hoặc log trước khi sửa.
- Nếu test fail, câu hỏi đầu tiên là “test có hợp lệ không?” (panel settings còn mở, macro đang chạy, sai màn hình…).

---

## 7. Xong khi

1. `/Validate Main.ahk` → `exit=0`, output rỗng.
2. `check-invariants.ps1` → pass.
3. Test liên quan trong `AA-mango-dev\Tests` → pass.
4. Nếu đổi hành vi: có log/ảnh live, hoặc ghi rõ **“chưa test live”**.
5. `context.md` thêm 3–6 dòng: ngày, `file:hàm`, đổi gì, bằng chứng, chưa xác nhận.
6. Báo 4 dòng: `Kết quả | Bằng chứng | Chưa xác nhận | Rủi ro`.

---

## 8. Báo cáo

Trả lời tiếng Việt, ngắn, không lan man:

1. **Kết quả** — đã làm gì, file:hàm nào.
2. **Bằng chứng** — validate exit + log/ảnh có timestamp.
3. **Chưa xác nhận** — phần chưa test live, nói thẳng.
4. **Rủi ro** — điều gì có thể hỏng ở lần chạy sau.

Không nói “đã fix” nếu không có bằng chứng. Không dùng “có lẽ”, “chắc là”.

---

## 9. Tài liệu và git

- `context.md`: append-only, ngắn. Không dán cả bài, không chép lại code.
- `ARCHITECTURE.md`: kiến trúc + luồng 5 giai đoạn. Chỉ đọc khi cần.
- `AgentOnly.md`: **đã bỏ** (archive ở `AA-mango-dev\archive\`). Không tạo lại bảng nhãn hàm.
- Git: `main` là bản ổn định; làm việc trên `agent/<chu-de>`; commit nhỏ, message rõ.
- **Chỉ publish folder**: `AA mango/`, `AR mango/`, `AV mango/`, `UTD mango/`, `.agents/`, `AGENTS.md`, `ARCHITECTURE.md`, `README.md`, `context.md`, `.gitignore`.
  `AA-mango-dev/` là cây dev, **không track**; file vẫn nằm trên đĩa và vẫn dùng bình thường.
- Publish một lệnh: `git pub "area: việc đã làm"` (add + commit + push). Không chọn file tay.
- `.githooks/pre-commit` chặn `Settings/`, `Logs/`, `Debug/`, `backup/`, `AA-mango-dev/`, `.zip`, và mọi chuỗi giống webhook/key. Bypass chỉ khi thật sự cần: `--no-verify`.
- Không commit `Settings/`, `Logs/`, `AA-mango-dev/`, `backup/`, file `.json/.png` sinh ra khi test.
- Trước khi commit: `git status` + `git diff` phải đúng phạm vi. Không commit file lạ.
- Không `git push --force` lên `main`. Không commit bí mật.

Skill `aa-macro` chỉ chứa **quy trình/quan sát/validate**; luật nằm ở file này.

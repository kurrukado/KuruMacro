# AA mango dev harness

Công cụ debug nằm **hoàn toàn ngoài** `D:\Macro\AA mango`.
Trong thư mục macro chỉ có 4 file `.ahk` được sửa, không thêm file nào.

```
D:\Macro\AA-mango-dev\
├─ Harness\
│  ├─ Snapshot.ahk      chụp vùng client của Roblox (+ lưới 100px)
│  ├─ Calibrate.ahk     kéo chuột khoanh icon -> PNG + toạ độ client
│  ├─ TestState.ahk     chạy ĐÚNG MỘT state, in JSON kết quả
│  └─ lib\Common.ahk    helper dùng chung
├─ Templates\           PNG + templates.ini do Calibrate sinh ra
├─ Debug\               ảnh + JSON + calibrate.log
├─ backup\              ghi chú revert
├─ states.ini           danh mục state test được + timeout
└─ README.md
```

`DEV_ROOT` / `PROJ_ROOT` hardcode trong `Harness\lib\Common.ahk`. Nếu đổi chỗ
thư mục thì sửa 2 dòng đầu file đó.

---

## Quick start

```powershell
$ahk = "C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$dev = "D:\Macro\AA-mango-dev"

# 1. Xem agent đang thấy gì (chạy xong tự thoát)
& $ahk "$dev\Harness\Snapshot.ahk" --auto
#    -> Debug\latest.json + *_raw.png + *_grid.png

# 2. Khoanh 1 icon để lấy toạ độ (mở cửa sổ, kéo chuột, Esc để thoát)
& $ahk "$dev\Harness\Calibrate.ahk"

# 3. Chạy 1 state duy nhất (~2 giây thay vì 5 phút)
& $ahk "$dev\Harness\TestState.ahk" DetectMap
```

`TestState.ahk` in JSON ra stdout:

```json
{ "state": "DetectMap", "ok": true, "timed_out": false, "ms": 1840,
  "client": {"w": 800, "h": 599}, "error": "" }
```

---

## Vòng lặp debug của agent

```
Snapshot --auto          -> thấy màn hình thật (ảnh 1:1 với toạ độ client)
   |
đọc latest.json          -> client 800x599, dpi 96, window 816x638
   |
Calibrate (1 lần)        -> Templates\chat_icon.png  +  x1,y1,x2,y2
   |
sửa code .ahk            -> dùng đúng toạ độ vừa đo
   |
TestState <State>        -> ok true/false, ms, error + line
   |
lặp lại
```

Điểm mấu chốt: **mỗi vòng lặp vài giây**. Trước đây mỗi lần thử phải chạy
nguyên flow nên 1 ngày chỉ được vài chục lần thử — đó mới là lý do tool không
xong, không phải do MCP.

---

## Đã sửa gì trong `AA mango`

| File | Sửa |
|---|---|
| `Main.ahk` | thêm hook `--run <Fn> [out.json] [timeoutMs]`. Không có tham số thì chạy y như cũ |
| `Lib\GUI.ahk` | `ProcessLog`: `Sleep(50)` -> `Sleep(1)` (hàm này chạy mỗi lần đổi state) |
| `Lib\GameMango.ahk` | `ClosePlayerLeaderBoard`: 2 nhánh in trùng câu "Không tìm thấy" -> log đúng |
| `Lib\Functions.ahk` | `FixClick`: cảnh báo 1 lần nếu `CoordMode Mouse` bị lệch khỏi `Client` |

Không đổi hành vi nào của macro (trừ log). Revert: xem `backup\revert.md`.

---

## Lỗi thật đã tìm thấy (chưa sửa — cần bạn xác nhận hành vi)

1. **`CoordMode` rò rỉ** — `GameMango.ahk` dòng ~1469, ~1519, ~3330 đặt
   `CoordMode "Mouse", "Screen"` rồi restore bằng `oldMouseMode`. Nếu giữa
   chừng có `return`/exception thì mode kẹt ở `Screen` và **mọi `FixClick` sau
   đó click sai chỗ, im lặng**. Đây là nghi phạm số 1 cho kiểu lỗi "lúc được
   lúc không".
2. **`StoryMovement` / `FarmMovement` click bằng toạ độ Screen** (`FixClick(85, 330)`)
   trong khi phần còn lại dùng Client. Nếu cửa sổ Roblox bị dời, click trượt.
3. **Retry mù** — 10 lần × ~7s rồi chờ 5 phút, không lưu ảnh nên không biết vì
   sao fail. Đã có `Snapshot` để bắt đầu sửa cái này.
4. **Toạ độ hardcode** rải khắp nơi (`635,220`, `650,77`, `137,36`...). Đổi
   resolution/DPI là chết. `Calibrate.ahk` sinh ra để thay dần những số này.

---

## Về `pironjulien/NexusWindows-Antigravity`

Repo tốt (MIT, có test, OpenSSF scorecard, emergency stop). **Nhưng không dùng
được cho Roblox:**

- `look` đọc UI Automation tree. Roblox là DirectX canvas -> không có tree,
  không có element.
- `act` map toạ độ sang element trong tree -> không có element -> phải
  `foreground=True`, tức chiếm chuột thật.
- Background keyboard = post `WM_KEYDOWN`. Roblox đọc Raw Input -> **không ăn**.

Giữ Nexus để lái editor / Notepad / file dialog. Cho game thì `windows-mcp`
(dùng `SendInput` thật + screenshot thật) mới đúng — đã cấu hình trong
`~\.gemini\config\mcp_config.json`.

---

## AGENT INSTRUCTIONS (English)

- Never add files inside `D:\Macro\AA mango`. Only edit existing
  `.ahk` files there.
- To see the screen: run `Snapshot.ahk --auto`, then read `Debug\latest.json`
  and the `_raw.png`. Coordinates in that PNG are client coordinates, 1:1.
- To test a change: `TestState.ahk <Section from states.ini>`. Do not run the
  full macro to verify a single fix.
- A pass is decided by the JSON (`ok`, `error`) plus the screenshot, never by
  the tool's own opinion.
- If `TestState.ahk` exits with code 2 and no result file, the script has a
  load-time syntax error; run `check-syntax.ps1` to find which file.

## Skills đã cài cho Antigravity

| Skill | Nội dung |
|---|---|
| `~\.gemini\config\skills\aa-mango-macro\SKILL.md` | luật làm việc trên macro này: đường dẫn, vòng lặp debug, Roblox/DirectX, lỗi đã biết |
| `~\.gemini\config\skills\ahk-v2\SKILL.md` | cú pháp AHK v2, scoping, `&out`, GDI+, `/Validate` |

Skill được nạp theo `description` khi câu hỏi khớp. Phải **restart Antigravity**
(rồi `... > Customizations > Installed`) mới thấy.

## Kiểm tra syntax toàn bộ

```powershell
powershell -ExecutionPolicy Bypass -File "D:\Macro\AA-mango-dev\check-syntax.ps1"
```

Dùng `AutoHotkey64.exe /ErrorStdOut /Validate` — load rồi thoát, **không chạy**,
nên an toàn cả khi macro đang farm.

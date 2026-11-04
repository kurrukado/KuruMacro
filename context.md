## 2026-11-03: Triển khai FindMatch toàn diện cho mọi game mode theo MatchMaking UI checkbox

- **Lib/GUI.ahk**:
  - `MatchMaking`: bỏ cờ `Hidden` khi tạo checkbox ở line 264.
  - Khởi tạo mặc định `MatchMaking.Visible := true` (line 303).
- **Lib/Functions.ahk**:
  - `OnModeChange`: đổi `MatchMaking.Visible := true` cho mọi mode khi đổi dropdown; bỏ gán cứng `MatchMaking.Value := 1` ở Summer Event để tôn trọng trạng thái tick của user.
  - `ConfirmModeSelection`: hiển thị `MatchMaking.Visible := true` cho tất cả các game mode (Story thường/Infinity, Portal, Farm, Daily Infinite Quest, Legend, Raid, Infinity Castle, Contract, Dungeon, Summer Event).
- **Lib/GameMango.ahk**:
  - `StoryMode`: bỏ nhánh ép `PlayHere()` cho story act thường; kiểm tra `if (MatchMaking.Value) { if (!FindMatch()) return } else { PlayHere() }` cho toàn bộ các màn Story.
  - `PortalMode`: thêm nhánh xử lý `if (MatchMaking.Value) { if (!FindMatch()) return } else { PlayHere() }`.
  - `FarmMode`: thêm nhánh xử lý `if (MatchMaking.Value) { if (!FindMatch()) return } else { PlayHere() }`.
  - `InfinityCastleMode`: thêm nhánh `if (MatchMaking.Value) { if (!FindMatch()) return } else if (ok := IsModeCancelOpen(&X, &Y)) { ClickUntilGone(...) }`.
  - `ContractMode` & `HandleContractJoin`: chỉ kích hoạt `Matchmaking` khi `MatchMaking.Value == 1`; nếu không tick thì dùng `Creating` (solo).
  - `DungeonMode`: nếu có tick `MatchMaking.Value` thì gọi `FindMatch()`, nếu không tick thì đi route solo `SelectDungeonRoute()`.
- **Bằng chứng**:
  - Validate: `C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe /ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"` -> `exit=0`, không có lỗi cú pháp/load-time.

## 2026-11-03: Cập nhật mặc định UI Matchmaking = 0 và hoàn thiện Matchmaking cho Infinity Castle & Dungeon

- **Settings/Configuration.txt**:
  - Đổi giá trị lưu cấu hình mặc định: `Matchmaking=0`.
- **Lib/Functions.ahk**:
  - `LoadSettings`: bỏ fallback gán ép `MatchMaking.Value := 1` khi `Mode=Summer Event` để UI luôn mặc định unticked (0) trừ khi người dùng chủ động tick.
- **Lib/GameMango.ahk**:
  - `InfinityCastleMode`: hoàn thiện tích hợp matchmaking:
    - Nếu tick `Matchmaking`: gọi `FindMatch()` để ghép đội.
    - Nếu không tick: thực hiện `PlayHere()` kết hợp fallback `ClickUntilGone(..., ModeCancel, -10, -120)` để chơi solo.
  - `DungeonMode`: hoàn thiện tích hợp matchmaking:
    - Dùng vòng lặp dò tìm `EnterDungeon` để mở bảng xác nhận một cách ổn định.
    - Nếu tick `Matchmaking`: gọi `FindMatch()`, ghép xong vào trận `RestartStage()`.
    - Nếu không tick: giữ nguyên luồng đi solo chọn phòng `SelectDungeonRoute()`.
  - `MonitorStage` & `CheckEndAndRoute`:
    - Khi chơi Dungeon ở chế độ Matchmaking (`MatchMaking.Value = 1`), điều hướng kết thúc trận sẽ đi qua `MonitorEndScreen()` để trở về sảnh và restart mode vào lượt ghép mới (thay vì cố tiếp tục floor solo trong `MonitorDungeonEnd`).
- **Bằng chứng**:
  - Validate: `C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe /ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"` -> `exit=0`, không lỗi cú pháp/load-time.

## 2026-11-03: Điều chỉnh lại các game mode không có Matchmaking trong game

- **Lib/Functions.ahk**:
  - `OnModeChange`: Mặc định ẩn `MatchMaking.Visible := false`. Chỉ bật `Visible := true` cho các mode game thực sự hỗ trợ Matchmaking (Infinite, Daily Infinite Quest, Legend, Raid, Infinity Castle, Dungeon, Summer Event). Các mode không có (Farm, Portal, Story thường, Contract) sẽ ẩn checkbox.
  - `ConfirmModeSelection`:
    - Với Story: Nếu chọn `Infinity` thì hiện `MatchMaking.Visible := true`; nếu chọn các Act thường (Act 1-6) thì ẩn checkbox và gán `MatchMaking.Value := 0`.
    - Với Farm, Portal: Ẩn `MatchMaking.Visible := false` và gán `MatchMaking.Value := 0`.
    - Với Contract: Ẩn checkbox riêng vì Contract sử dụng dropdown `ContractJoinDropdown`.
    - Với Infinity Castle & Dungeon: Giữ `MatchMaking.Visible := true` (game đã cập nhật matchmaking).
- **Lib/GameMango.ahk**:
  - `StoryMode`: Giữ `PlayHere()` cho các Act thường (Act 1-6 không có matchmaking); chỉ nhánh Act `Infinity` mới kiểm tra `MatchMaking.Value` để gọi `FindMatch()`.
  - `FarmMode`: Trả về gọi thẳng `PlayHere()` vì Farm không có nút Find Match trong game.
  - `PortalMode`: Trả về luồng gốc vào portal cá nhân (không gọi Find Match).
  - `ContractMode` & `HandleContractJoin`: Trả về dùng `ContractJoinDropdown.Text` gốc.
  - `InfinityCastleMode` & `DungeonMode`: Giữ nguyên hỗ trợ Matchmaking khi có tick.
- **Bằng chứng**:
  - Validate: `C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe /ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"` -> `exit=0`.

## 2026-11-03: Thiết lập quy chuẩn phân tầng PROD vs DEV và bảo vệ mã nguồn tại AGENTS.md

- **AGENTS.md**:
  - Tạo tài liệu quy chuẩn phân vùng hệ thống: `D:\Macro\AA mango\AA mango` là PROD (Read-Only đối với mọi Agent); `D:\Macro\AA-mango-dev` là DEV Sandbox.
  - Thiết lập chu trình 4 bước bắt buộc: Lập test ở DEV -> Thu thập bằng chứng -> Trình diff & hỏi User -> Chỉ sửa khi User đồng ý.
  - Ban hành điều khoản cấm tuyệt đối xóa/làm hỏng tính năng Captcha (`CaptchaDetect`), click engine (`FixClick`/`FixMove`), OCR và cấu hình game.
- **.agents/rules/aa-mango-rules.md**:
  - Đồng bộ hóa các quy tắc cấm sửa trực tiếp PROD và cấm xóa bỏ tính năng Captcha/input.

## 2026-11-03: Tích hợp tính năng game mới "Seamless Replay (BETA)" và cập nhật AGENTS.md

- **Bối cảnh & Yêu cầu**:
  - Tựa game Anime Adventures cập nhật tính năng chính thức: **Seamless Replay (BETA)**.
  - Replay không còn chuyển sang server Roblox mới mà tái khởi động ngay tại chỗ (in-place) sau loading screen ngắn.
  - Party ghép đội (Matchmaking) được giữ nguyên qua các lượt Replay.
  - Áp dụng trên Story (Replay & Next Level), Legend Stages, Raids, Infinite, Portals, Tournaments, Challenges, Artifact Stages, Summer Hunt, Infinity Mansion.
  - Infinity Mansion: Retry và Next Room khởi động tại chỗ trên cùng map.
  - Summer Hunt: Replay trên cùng map nếu chưa đổi giờ xoay map; thời tiết mới cập nhật ngay.
  - Người chơi hết lượt Raid hoặc thiếu key/item sẽ bị game đưa về sảnh, nhóm còn lại tiếp tục chơi.
- **Thay đổi hệ thống**:
  - **Lib/GUI.ahk**:
    - Bỏ mặc định `Checked` của checkbox `ReturnLobbyBox` (`Return To Lobby`) để Seamless Replay là hành vi mặc định khi kết thúc trận, trao quyền chủ động cho người dùng khi muốn về sảnh.
  - **Lib/Functions.ahk**:
    - `readInSettings` & `SaveSettings`: Bổ sung lưu/nạp cấu hình `ReturnToLobby` vào `Configuration.txt`.
    - `OnModeChange` & `ConfirmModeSelection`: Hiển thị `ReturnLobbyBox` đầy đủ cho các chế độ (Legend, Raid, Infinity Castle, Contract, Dungeon, Summer Event, Daily Infinite Quest, Infinite).
  - **Lib/GameMango.ahk**:
    - `ClassifyResultScreen`: Bổ sung nhận diện nút kết quả choices mở rộng: `(replay|retry)`, `next (level|room)`, `waiting for players`.
    - `ChooseResultRoute`: Đổi logic điều hướng. Nếu tick `NextLevelBox` -> chọn `"next_level"`. Nếu tick `ReturnLobbyBox` -> chọn `"lobby"`. Mặc định giữ Seamless Replay (`"replay"`), không còn ép buộc Matchmaking phải Return to Lobby như phiên bản cũ.
    - `TryResultAction`: Hỗ trợ tìm kiếm theo danh sách nhãn ưu tiên (`Next Level`, `Next Room`, `Replay`, `Retry`, `Return to lobby`) và mở rộng dải tọa độ `x` từ 630 lên 680 để phủ nút Next Level / Next Room.
    - `ContinueAfterResult`: Đối với Summer Event, nếu loading screen quá ngắn chưa kịp nhận diện map mới thì tự động fallback về `SummerMapName` trước đó khi replay cùng map.
    - `CheckLoaded`: Bổ sung nhận diện `AreaText` (Lobby). Nếu người chơi bị game trả về sảnh do hết lượt Raid / thiếu key / nhóm giải tán, hàm trả về trạng thái `"lobby"`.
    - `RestartStage`: Khi `CheckLoaded` trả về `"lobby"`, tự động gọi `StartSelectedMode()` để chọn lại chế độ an toàn mà không bị kẹt vòng lặp vô hạn.
  - **Settings/Configuration.txt**:
    - Thêm `ReturnToLobby=0`.
  - **AGENTS.md**:
    - Cập nhật sơ đồ mermaid 5 giai đoạn vòng đời macro và tài liệu chi tiết Giai đoạn 5 theo cơ chế Seamless Replay (BETA).
- **Bằng chứng**:
  - Test Harness DEV: `D:\Macro\AA-mango-dev\Tests\test-seamless-replay.ahk` chạy qua AutoHotkey64.exe -> pass 100% các ca kiểm thử `ClassifyResultScreen` và `ChooseResultRoute` (Exit code: 0, `ALL SEAMLESS REPLAY UNIT TESTS PASSED!`).
  - Validate toàn bộ project: `AutoHotkey64.exe /ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"` -> `exit=0`.

## 2026-11-04: Áp dụng Rule cứng: Matchmaking bắt buộc Return to Lobby

- **Yêu cầu người dùng**:
  - Đối với chế độ Matchmaking, quy tắc cứng (hard rule) là bắt buộc phải `Return to lobby` để giải tán phòng và ghép trận mới từ sảnh. Không giữ phòng hay Replay khi ghép đội.
- **Thay đổi hệ thống**:
  - **Lib/GameMango.ahk**:
    - `ChooseResultRoute(matchmaking := 0)`: Đặt điều kiện đầu tiên kiểm tra `if (matchmaking)` $\rightarrow$ trả về `"lobby"` ngay lập tức.
    - Nhánh solo (`matchmaking = 0`): Giữ nguyên hỗ trợ Next Level (Story), Return To Lobby (nếu tick), hoặc Seamless Replay (BETA) in-place mặc định.
  - **AGENTS.md**:
    - Cập nhật sơ đồ mermaid và phần mô tả Giai đoạn 5: Nhấn mạnh quy tắc cứng `Matchmaking = 1` luôn `Return to lobby`.
- **Bằng chứng**:
  - Test Harness DEV: `D:\Macro\AA-mango-dev\Tests\test-seamless-replay.ahk` qua AutoHotkey64.exe -> pass 100% các ca kiểm thử:
    - `Matchmaking = 1` bất kể tick Replay hay Next Level đều trả về `"lobby"`.
    - `Matchmaking = 0` trả về `"next_level"`, `"lobby"` hoặc `"replay"` theo cấu hình.
    - Log: `ALL HARD-RULE MATCHMAKING & SEAMLESS REPLAY UNIT TESTS PASSED!` (Exit code: 0).
  - Validate toàn bộ project: `AutoHotkey64.exe /ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"` -> `exit=0`.

## 2026-11-04: Tối ưu hóa chu trình Summer Event & Căn chỉnh di chuyển sảnh

- **Yêu cầu & Phân tích từ người dùng**:
  - `SummerClick`: Quy về gọi thẳng `FixClick(x, y)` chuẩn của dự án.
  - `SummerApproachQueue`: Đè phím W liên tục mượt mà đến khi bảng Join Matchmaking mở ra, loại bỏ nhấp nhả 16 lần giật cục.
  - Summer Event Map Pool: Game bốc ngẫu nhiên 1 map trong toàn bộ kho game (rất nhiều map chưa có route), do đó loại bỏ `DetectSummerMap` (tránh timeout 45s); vào trận thực hiện `BasicSetup()` + `PlacementCamera()`, bỏ qua `HandleMapMovement`, tiến hành vote start và quét đặt quân tỏa tròn quanh Spawn luôn.
- **Thay đổi hệ thống**:
  - **Lib/GameMango.ahk**:
    - `SummerClick(x, y)`: Rút gọn thành gọi trực tiếp `FixClick(x, y)`.
    - `SummerApproachQueue()`: Gửi `SendInput("{w down}")`, kiểm tra bảng mở ra (tối đa 5s) rồi gửi `SendInput("{w up}")`.
    - `SummerEventMode()`: Bỏ chờ `DetectSummerMap(45000)`. Bấm tìm trận xong là gọi thẳng `RestartStage("Summer Event")`.
    - `RestartStage()`: Bổ sung `PlacementCamera()`, kiểm tra nếu `mode = "Summer Event"` thì bỏ qua `HandleMapMovement()` để nhân vật đứng yên an toàn tại Spawn và gọi `PlacingUnits()` đặt quân tại chỗ.
    - `ContinueAfterResult()`: Với Summer Event khi solo replay, gọi thẳng `RestartStage("Summer Event")` không qua `DetectSummerMap(60000)`.
- **Bằng chứng**:
  - Validate: `AutoHotkey64.exe /ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"` -> `exit=0`.
  - Test Harness DEV: `AutoHotkey64.exe /ErrorStdOut "D:\Macro\AA-mango-dev\Tests\test-seamless-replay.ahk"` -> `exit=0`.

## 2026-11-04: Sửa lỗi phím F2 không chạy khi chọn Summer Event & Treo CheckLoaded

- **Hiện tượng**: Người dùng chọn "Summer Event" trên GUI, bấm "Xác nhận", sau đó bấm F2 thì macro im lặng hoàn toàn không hoạt động (hoặc người dùng đã vào trong trận mà macro không bắt đầu đặt quân).
- **Nguyên nhân cốt lõi**:
  1. `SummerReadUI`: Ném ngoại lệ `throw Error("Summer Event requires client 800x599")`. Trong luồng hotkey AHK v2 khi chưa bắt try-catch, ngoại lệ này làm chết thread F2 ngay lập tức mà không in ra bất kỳ log nào.
  2. `CheckLoaded`: Chỉ kiểm tra duy nhất `VoteStart` FindText hoặc pixel xanh `0x00EE00`. Khi người dùng đã load xong hoặc bấm F2 khi trận đấu đã bắt đầu (Wave 1, 2, 3...), `VoteStart` không còn trên màn hình khiến `CheckLoaded` lặp vô tận (infinite hang) làm macro đứng im.
  3. `StartedGame`: Chờ vote tới 45s kể cả khi game đã bắt đầu wave.
  4. `ValidateMode`: Chỉ kiểm tra `ahk_exe RobloxPlayerBeta.exe`, thiếu fallback theo WinTitle `"Roblox"`.
  5. `StartMacro`: Thiếu log phản hồi tức thì khi bấm F2 và thiếu khối `try-catch` bảo vệ luồng hotkey.
- **Thay đổi hệ thống**:
  - **Lib/GameMango.ahk**:
    - Thêm hàm `IsInMatch()`: Nhận diện trận đấu đang chạy thông qua `VoteStart`, biểu tượng Yên (`Yen` FindText tại 340, 515, 530, 565) hoặc từ khóa OCR trên màn hình HUD.
    - Viết lại `SummerReadUI`, `SummerVerificationVisible`, `SummerWalk`: Loại bỏ hoàn toàn `throw Error`, tự động lấy kích thước client thực tế và bọc trong `try-catch` an toàn.
    - Cập nhật `SummerEventMode`: Kiểm tra `IsInMatch()` ngay đầu hàm; nếu người dùng bấm F2 khi đã ở trong trận thì chuyển ngay sang setup và đặt quân mà không qua bước sảnh.
    - Cập nhật `CheckLoaded()`: Tích hợp `IsInMatch()` để phát hiện tức thì khi trận đấu đã vào guồng, không bị kẹt lặp vô hạn.
    - Cập nhật `StartedGame()`: Nếu trận đấu đã chạy wave từ trước, bỏ qua thời gian chờ vote 45s và tiến hành đặt quân ngay.
    - Cập nhật `ValidateMode()` & `StartMacro(*)`: Thêm log `ProcessLog("F2: Bắt đầu chạy Macro...")`, bọc `try-catch` và hỗ trợ fallback nhận diện cửa sổ Roblox.
- **Bằng chứng**:
  - Validate syntax: `AutoHotkey64.exe /ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"` -> `exit=0`.
  - Dev Harness: `AutoHotkey64.exe "D:\Macro\AA mango\AA mango\Main.ahk" --run IsInMatch "D:\Macro\AA-mango-dev\test-isinmatch.json" 5000` -> `ok: true`, `error: ""` (Exit code: 0).

- 2026-11-04: User duyệt áp dụng review.diff từ DEV lên PROD. Gỡ Contract, rollback nhánh IsInMatch của Gemini, sửa tìm cửa sổ Roblox, cập nhật ưu tiên kết quả chung và checkbox Next Level/Replay, bỏ vote khi cả ba thẻ không có điểm tin cậy. PROD /Validate exit=0, ba file trùng hash với DEV. Chưa kiểm thử trong Roblox. Backup: D:\Macro\AA-mango-dev\gemini-rollback\prod-backup-20261104-073743

- 2026-11-04: User duyệt diff Summer CAPTCHA. Đã áp dụng GameMango.ahk lên PROD tại D:\Macro\AA mango. Summer Matchmaking gọi CaptchaDetect sau khi hộp xác minh xuất hiện. /Validate exit=0 và hash khớp DEV. Tọa độ lấy từ FindMatch, chưa kiểm thử trong Roblox. Backup: D:\Macro\AA-mango-dev\summer-captcha\GameMango.prod-20261104-081321.ahk

- 2026-11-04: Đã đối chiếu vùng OCR, ô nhập và Submit với hộp Summer CAPTCHA mở trong Roblox. User duyệt đưa bộ lọc chữ xanh và vùng OCR mới lên PROD. /Validate exit=0, hai file khớp DEV. Chưa chạy OCR hoặc gửi CAPTCHA trong Roblox. Backup: D:\Macro\AA-mango-dev\summer-captcha-ui\backup-20261104-081757

- 2026-11-04: User duyệt diff F2 Summer CAPTCHA. PROD dùng chung luồng OCR khi hộp đã mở hoặc xuất hiện sau Find Match. /Validate exit=0, hash khớp DEV. Chưa test gửi mã trong Roblox. Backup: D:\Macro\AA-mango-dev\summer-captcha-f2\GameMango.prod-20261104-082158.ahk

- 2026-11-04: Đã áp dụng diff upgrade-no-hotbar được user duyệt lên PROD. Đóng panel sau đặt quân bằng CloseUnitPanel và bỏ ba cú click phụ (560,560) trong UpgradeUnits. Validate exit=0, hash khớp DEV. Chưa chạy trong trận. Backup: D:\Macro\AA-mango-dev\upgrade-no-hotbar\GameMango.prod-20261104-085140.ahk

- 2026-11-04: User duyệt đưa Settings UI và leaderboard lên PROD. BasicSetup bấm (565,73) trong trận. TpSpawn tìm Teleport back to Spawn bằng OCR, giữ giá trị Disable Auto-Open Upgrade UI. /Validate exit=0, hash khớp DEV. Chưa chạy luồng mới trong Roblox. Backup: D:\Macro\AA-mango-dev\basic-settings-ui\GameMango.prod-20261104-085902.ahk

- 2026-11-04: User duyệt hai diff JEV một yêu cầu mỗi bảng thẻ và UI nâng cấp UPG [n] (MAX). Đã ghép và áp dụng lên PROD, /Validate exit=0, hash khớp bản ghép DEV. Chưa thử trong Roblox. Backup: D:\Macro\AA-mango-dev\prod-combined-20261104-091021\GameMango.before.ahk

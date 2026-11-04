# AgentOnly.md — Workflow và khóa sửa hàm

> Đọc context.md để biết lịch sử và bằng chứng. File này là bản đồ rút gọn.
> **SỞ HỮU: USER. Agent chỉ đọc, không sửa file này** — không đổi nhãn, không thêm/xóa/format lại dòng.
> User tự ghi `BUGGING` khi phát hiện lỗi và tự ghi lại khi đã hết lỗi. Agent chỉ được đề nghị đổi nhãn trong câu trả lời.
> **MẶC ĐỊNH KHÔNG SỬA CODE. Chỉ sửa đúng phạm vi user giao.**
> Nhãn áp dụng cho chính hàm/bước bên cạnh, không mở quyền sửa hàm con hoặc caller.

## 1. Ý nghĩa nhãn

| Nhãn | Ý nghĩa và quyền sửa |
|---|---|
| WORKING — KHÓA | Đã có bằng chứng trong tài liệu. Cấm tự sửa, refactor, thêm log, đổi sleep/tọa độ. |
| SYSTEM — KHÓA | UI/settings/camera/chat/vote/recovery được bảo vệ. Cần user mở khóa đúng hàm trước khi sửa. |
| BUGGING — CHỜ USER | Có lỗi/nghi vấn được ghi lại. Chỉ sửa khi user giao đúng lỗi. |
| BUGGING (chưa verify) — CHỜ USER | Chưa đủ bằng chứng; không đồng nghĩa đã hỏng. Không tự sửa hoặc tự nhận WORKING. |
| WORKING + SYSTEM — KHÓA | Giữ cả bằng chứng hoạt động và ràng buộc bảo vệ. |

**Không tự đổi WORKING/SYSTEM sang BUGGING để lấy quyền sửa.** Lỗi ở A không mở khóa B.
Muốn chạm hàm khóa → nêu hàm, triệu chứng, bằng chứng → chờ user quyết định.
User mở khóa bằng cách sửa nhãn trong chính file này (hoặc nói rõ trong chat). GAME là loại logic, **không phải quyền sửa**.

Cách user ghi sổ (agent không làm thay):
- Thấy lỗi → thêm dòng vào bảng mục 6 (`B7`, `B8`…) và đổi nhãn hàm liên quan sang `BUGGING — CHỜ USER`.
- Đã hết lỗi → đổi nhãn về `WORKING — KHÓA` và ghi ngày hết lỗi trong dòng bảng mục 6 (hoặc gạch bỏ dòng đó).
- Chưa chắc → giữ `BUGGING (chưa verify)`, không đổi sang `WORKING`.

Ký hiệu: → bước tiếp theo; thụt vào = nhánh/hàm con. Đây là workflow rút gọn.
Tra code theo tên hàm, không dựa vào số dòng cũ.

## 2. Khởi động và vào mode

```text
StartMacro()                       [Working]
 → ValidateMode()                   [Working]
 → StartSelectedMode()              [Working]
    ├ Story / Infinite → StoryMode()
    ├ Legend           → LegendMode()
    ├ Raid             → RaidMode()
    ├ Infinity Castle  → InfinityCastleMode()
    ├ Portal           → PortalMode()
    ├ Farm             → FarmMode()
    ├ Daily Inf Quest  → InfQuestMode()
    ├ Contract         → ContractMode()
    ├ Dungeon          → DungeonMode()
    └ Summer Event     → SummerEventMode()
```

Các hàm vào mode dưới đây: **BUGGING (chưa verify toàn luồng) — CHỜ USER**.
Tài liệu hiện chưa đủ bằng chứng để gắn WORKING cho toàn bộ mode.
Hàm SYSTEM được gọi bên trong vẫn khóa theo mục 5.

| Mode | Workflow tên hàm | Trạng thái |
|---|---|---|
| Story / Infinite | StoryMode → StoryMovement → IsModeCancelOpen → StartStory → SelectStoryAct → PlayHere / FindMatch → RestartStage | Chưa verify — không tự sửa |
| Legend | LegendMode → StoryMovement → IsModeCancelOpen → StartLegend → PlayHere / FindMatch → RestartStage | Chưa verify — không tự sửa |
| Raid | RaidMode → RaidMovement → IsModeCancelOpen → StartRaid → PlayHere / FindMatch → RestartStage | Chưa verify — không tự sửa |
| Infinity Castle | InfinityCastleMode → InfCastleMovement → IsModeCancelOpen → chọn Normal/Hard → ClickUntilGone → RestartStage | Chưa verify — không tự sửa |
| Portal | PortalMode → PortalMovement → IsModeCancelOpen → RestartStage | Chưa verify — không tự sửa |
| Farm | FarmMode → FarmMovement → IsModeCancelOpen → PlayHere → RestartStage | Chưa verify — không tự sửa |
| Daily Inf Quest | InfQuestMode → InfQuestMovement → IsModeCancelOpen → PlayHere / FindMatch → RestartStage | Chưa verify — không tự sửa |
| Contract | ContractMode → HandleContractJoin → HandleNextContract → GetContractPage → RestartStage | Chưa verify — không tự sửa |
| Dungeon | DungeonMode → SelectDungeonRoute → MonitorDungeonEnd | Chưa verify — không tự sửa |
| Summer Event | SummerEventMode → Play → SummerWalk → Join Matchmaking → DetectSummerMap → RestartStage(map) | (not tested) |

Legend: StartLegend → GetNavKeys → GetLegendDownArrows / GetLegendActDownArrows.
Raid: StartRaid → GetNavKeys → GetRaidDownArrows / GetRaidActDownArrows.

## 3. Luồng chung trong trận

```text
RestartStage()                     [BUGGING (chưa verify toàn luồng) — CHỜ USER]
 → DetectMap()                     [BUGGING (chưa verify riêng) — CHỜ USER]
 → CheckLoaded()                   [BUGGING (chưa verify riêng) — CHỜ USER]
 → BasicSetup()                    [SYSTEM — KHÓA]
    → ClosePlayerLeaderBoard()     [SYSTEM — KHÓA]
    → CloseChat()                  [WORKING + SYSTEM — KHÓA]
       → IsChatOpen()              [WORKING + SYSTEM — KHÓA]
    → Zoom()                       [SYSTEM — KHÓA]
    → TpSpawn()                    [SYSTEM — KHÓA; B3/B5/B6]
       → FindUpgradeToggleRow()    [SYSTEM — KHÓA]
       → PlacementCamera()         [SYSTEM — KHÓA; trim cuối chưa verify]
 → HandleMapMovement(map)          [BUGGING (chưa verify từng route) — CHỜ USER]
    → MoveFor<Map>()               [CHỜ USER giao đúng map; xem mục 7]
 → StartedGame()                   [SYSTEM — KHÓA; vote]
 → PlacingUnits()                  [WORKING phần placement/count — KHÓA]
    → UpgradeUnits()               [BUGGING — CHỜ USER; xem B1]
 → MonitorStage()                  [CHƯA VERIFY TOÀN HÀM — không tự sửa]
```

Không coi toàn bộ phần sau HandleMapMovement là được sửa: StartedGame và các nhánh SYSTEM vẫn khóa.

## 4. Đặt unit và nâng cấp

```text
PlacingUnits()                     [WORKING phần placement/count — KHÓA]
 → LoadUnitCoordsFromFile()        [BUGGING (chưa verify riêng) — CHỜ USER]
 → chọn slot bằng phím 1–6         [WORKING — KHÓA; không click hotbar]
 → GenerateCirclePoints()          [WORKING — KHÓA; 64 điểm]
 → PlaceUnit()                     [WORKING phần đã xác nhận — KHÓA]
    → EnsureSolidTemplate()        [WORKING — KHÓA]
    → FindUnitPanel()              [WORKING mẫu nhận diện đã xác nhận — KHÓA]
 → UnitPlaced()                    [WORKING — KHÓA; poll 6 × 250 ms]
 → log số unit đã xác nhận         [WORKING — KHÓA]
 → UpgradeUnits()                  [BUGGING — CHỜ USER]
    → UpgradeUnit()                [BUGGING — CHỜ USER; B1]
       → FindUnitPanel()           [WORKING — KHÓA; B1 không mở khóa helper]
       → MaxUpgrade()              [BUGGING (chưa verify riêng) — CHỜ USER]
       → CheckAbility()            [BUGGING (chưa verify riêng) — CHỜ USER]
          → MahogoraAbility()      [BUGGING (chưa verify riêng) — CHỜ USER]
       → CloseUnitPanel()          [BUGGING (chưa verify riêng) — CHỜ USER]
```

Chi tiết WORKING phải giữ:

- FixClick / FixMove: move → nudge 1 px → click; wheel có FixMove trước. Giữ SendMode "Event".
- GenerateCirclePoints: ringGap 45, arcGap 45, maxRadius 180.
- failedCoordinates khai báo một lần trước vòng slot; điểm fail khóa cả lượt.
- FindUnitPanel: giữ mẫu cũ #3CF500 20×12 / #12C3FD 18×6 cho UI cũ; nhánh Summer dùng FindUpdatedUnitPanel theo chữ panel mới để tránh nhầm màu hiệu ứng. Phần mới (not tested).
- EnsureSolidTemplate: BMP có pad hàng 4 byte.
- Log “Đã đặt X/Y unit” chỉ tính sau UnitPlaced xác nhận.
- Giữ tiêu đề KuruMacro Anime Adventures v2.0.
- GenerateGridPoints / GenerateRandomPoints chưa verify riêng; không tự chuyển sang nhánh này.

## 5. Theo dõi, kết thúc và vùng SYSTEM

```text
MonitorStage()                     [CHƯA VERIFY TOÀN HÀM — không tự sửa]
 ├ CheckForXp()                    [BUGGING (chưa verify riêng) — CHỜ USER]
 ├ Wave40Reached()                 [WORKING + SYSTEM — KHÓA]
 │  → FindUpgradeToggleRow()       [SYSTEM — KHÓA]
 │  → Return to Lobby → CheckLobby()[SYSTEM — KHÓA]
 ├ CardScreenVisible()             [(not tested) toàn vòng; đã bật với tọa độ đo thật]
 │  → WaitForCardChoice()          [(not tested); đóng/verify panel unit trước OCR]
 │     → HandleCardScreen()        [(not tested); một vote, kiểm tra lại offer/focus/deadline]
 └ CheckEndAndRoute()              [SYSTEM — KHÓA]
    ├ HandleContractEnd()          [SYSTEM — KHÓA nhánh kết thúc]
    ├ MonitorDungeonEnd()          [SYSTEM — KHÓA nhánh kết thúc]
    └ MonitorEndScreen()           [(not tested) nhánh user giao 2026-11-02]
       → ReadResultScreen / ClassifyResultScreen
       → TryResultAction: summary → Next đã xác nhận
       → ChooseResultRoute(MatchMaking.Value)
          ├ true  → Return to lobby → ContinueAfterResult → StartSelectedMode
          └ false → Replay → ContinueAfterResult → nhận lại map nếu Summer → RestartStage
       → Không đọc được Victory/Defeat: chỉ xử lý khi cụm UI kết quả đã xác nhận; outcome unknown, không tự cộng thắng/thua
```

| Nhóm | Hàm | Trạng thái |
|---|---|---|
| Input | FixClick, FixMove | WORKING — KHÓA |
| Settings | TpSpawn, EnsureUpgradeUIOnLeft, FindUpgradeToggleRow, ToggleIsOn, IsControlPixel, ArrowNear, UpgradeUIToggleGreen, IsUpgradeUIToggleOn | SYSTEM — KHÓA |
| Camera | Zoom, PlacementCamera | SYSTEM — KHÓA |
| Chat | IsChatOpen, CloseChat | WORKING + SYSTEM — KHÓA; không mở lại chat |
| Vote | StartedGame | SYSTEM — KHÓA |
| Popup / recovery | DismissPromoPopups, ClosePlayerLeaderBoard, Reconnect, CheckLobby, TogglePause | SYSTEM — KHÓA |

Dungeon: MonitorDungeonEnd → CheckDungeonSpecials / HandleShop / HandleChestScreen → IsChestScreenVisible → ClaimChestReward / CheckForFinishDungeon.
Các helper Dungeon chưa có bằng chứng riêng — CHỜ USER; không sửa nhánh kết thúc SYSTEM.

Card picker: CardScreenVisible → ReadCardNames → ChooseCard → FixClick → verify.
ChooseCard / TestCardPicker đã có bằng chứng offline trong context; chưa verify toàn luồng live.
CARD_ENABLED := true cho UI Summer 800×599 đã chụp thật: tâm thẻ client `(224,320)`, `(400,320)`, `(577,320)`; OCR nội dung ở y210–405. Gate đọc `Choose a card` hoặc `The weather shifts`; WaitForCardChoice chỉ gửi một vote rồi chờ panel đóng, đóng panel unit nếu nó che thẻ. OCR màu được tăng tương phản, không suy đoán dấu còn thiếu. Giữ **(not tested)** vì OCR/live toàn vòng chưa ổn định.

Mốc settings lịch sử: gear (26,570), panel 209–591 × 135–447, đóng (581,157), cột x=524, hàng cách 53 px.
Đây không phải số đo mới; không áp dụng khi cửa sổ/DPI khác.

## 6. Lỗi và phần chưa verify — chỉ tra cứu, không tự sửa

| ID | Hàm / phần | Ghi nhận | Quyền |
|---|---|---|---|
| B1 | UpgradeUnit / panel UPD21 | Đã thấy unit thật có sát thương nhưng xác nhận placement cũ fail. Panel mới dùng gradient và `UPG [n]`; thêm FindUpdatedUnitPanel và đọc header tương phản | UI mới (not tested); không coi B1 đã hết |
| B2 | EnsureUpgradeUIOnLeft | Có thể fail khi panel scroll lạ | SYSTEM khóa; cần user mở đúng hàm |
| B3 | TpSpawn | Chưa guard settings đã mở, click gear có thể đóng panel | SYSTEM khóa |
| B4 | 6 mode thiếu WaitForModeDialog | Ghi nhận cũ; đối chiếu code trước khi kết luận | Chờ user giao mode cụ thể |
| B5 | Setup trước vote / trim cuối | Chưa đo lại live; mục tiêu cũ dưới 6 giây | SYSTEM khóa; không tự giảm sleep |
| B6 | Toggle OFF #640000 | Chưa verify nhánh OFF | SYSTEM khóa |
| C1 | Card picker / Jev blueprint | Blueprint buff-only, API key trong Settings; đã đo UI thẻ thật và gửi vote. OCR hiệu ứng nhỏ/dấu còn hạn chế; CARD_ENABLED true | User đã giao 2026-11-02; (not tested) |
| S1 | Summer Event / nhận diện map | Đã ghép trận sau CAPTCHA do user làm. Template cũ + OCR tên map; đọc lại tên trong trận, không suy từ board lobby. Replay có thể đổi tên map | (not tested) |
| S2 | Movement Summer courtyard | MoveForSummerCourtyard → SummerResetSpawn → PlacementCamera → giữ A 1200ms; tách khỏi route map thường. Có lượt probe 6625ms không exception; lượt gameplay đã đặt unit nhưng hết thời gian khi xác nhận slot 4 | (not tested) |
| S3 | Kết thúc trận / safe fallback | Matchmaking bật → Return lobby rồi vào lại mode; tắt → Replay. ResultScreenReady dùng XP/statistics/Next hoặc cụm Return lobby/Replay/Waiting for Players; không cần chữ Victory/Defeat | (not tested) |

B1: probe offset [[0,-3],[0,-14],[-12,-6],[12,-6]] × 4 × 200 ms đã thử không hiệu quả.
Khi được giao, xem ảnh trước/sau click unit; không lặp probe khi chưa có bằng chứng mới.

## 7. Hàm di chuyển theo map

HandleMapMovement → hàm tương ứng dưới đây.
**Tất cả route: BUGGING (chưa verify riêng) — CHỜ USER giao đúng map.**

| Map | Hàm | Map | Hàm |
|---|---|---|---|
| Planet Greenie | MoveForGreenie | Haunted Academy | MoveForHauntedAcademy |
| Snowy Town | MoveForSnowyTown | Space Center | MoveForSpaceCenter |
| Navy Bay | MoveForNavyBay | Mountain Temple | MoveForMountainTemple |
| Fiend City | MoveForFiendCity | Cursed Festival | MoveForCursedFestival |
| Spirit World | MoveForSpiritWorld | Nightmare Train | MoveForNightmareTrain |
| Ant Kingdom | MoveForAntKingdom | Air Craft | MoveForAirCraft |
| Magic Town | MoveForMagicTown | Hellish | MoveForHellish |
| Magic Hill | MoveForMagicHill | Shibuya | MoveForShibuya |

PortalSearch / EnterNavMode: tài liệu cũ ghi không có call site. Không tự dùng lại hoặc xóa để dọn.

Summer courtyard mới: `HandleMapMovement` chỉ chọn `MoveForSummerCourtyard` khi mode là Summer Event và tên là Planet Greenie / Cursed Festival đã quan sát cùng sân đền/sàn gỗ. `SummerResetSpawn` xác nhận hàng Teleport back to Spawn bằng OCR, đóng settings, rồi dùng camera chuẩn và đi A 1200ms ra cạnh đường quái. Không đổi MoveForGreenie/MoveForCursedFestival của mode cũ. Route này vẫn **(not tested)** toàn vòng.

## 8. File và quy trình tối thiểu

| File | Vai trò |
|---|---|
| Main.ahk | Entry; hook --run <Fn> [out.json] [timeoutMs] |
| Lib/GameMango.ahk | Logic game, card picker |
| Lib/Functions.ahk | Input helper, settings, tọa độ |
| Lib/GUI.ahk | GUI, hotkey, ProcessLog |
| Lib/Image.ahk | Pattern nhận diện |
| context.md | Lịch sử và bằng chứng |
| `D:\Macro\AA-mango-dev\Harness` | Snapshot, Calibrate, TestState |

1. Đọc context → tìm đúng hàm và nhãn → đối chiếu phạm vi user giao.
2. Xem thật → một thao tác → xem lại ngay → xác nhận hiệu ứng trước bước tiếp theo.
3. Nếu được sửa: diff nhỏ → validate Main.ahk → kiểm tra đúng hàm → ảnh/log chứng minh. JSON ok=true chỉ là không ném exception.
4. User đã cho phép lấy focus và dùng chuột/phím thật cho thao tác/test được giao (2026-10-30), kể cả đang chơi; không hỏi lại riêng về input. Task chỉ quan sát thì không gửi input. --run thay instance macro do SingleInstance Force: quyền dùng chuột không tự cho phép ngắt/restart macro. Tôn trọng user takeover/emergency stop; khóa sửa hàm vẫn giữ.
5. Chỉ đánh WORKING khi có bằng chứng, ghi rõ phạm vi đã xác nhận. Không tự hạ nhãn khóa.
6. Không tạo file mới trong cây AA mango. Mã sửa trong .ahk hiện có; tài liệu chỉ sửa khi user yêu cầu. File tạm để ngoài project.

AHK: C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe.
Root: D:\Macro\AA mango\AA mango.
Validate: AutoHotkey64.exe /ErrorStdOut /Validate Main.ahk (đúng working directory); không validate Lib riêng.
Client 800×599 là mốc lịch sử; đọc kích thước/DPI thật, phân biệt Client/Screen.
AHK v2: dùng Mod(), RawWrite đúng API; giữ input/helper WORKING.

## 9. UI / Jev / Summer Event — 2026-11-02 — (not tested)

User giao sửa đúng các phần dưới đây và yêu cầu giữ nhãn **(not tested)**. Đây không phải xác nhận WORKING toàn luồng.

| Phần | Hàm / thay đổi | Trạng thái |
|---|---|---|
| GUI đè app khác | Chroma dành riêng `#FF00FE`, không dùng đen làm màu trong suốt; giữ bố cục. Settings mở giữa cửa sổ macro | (not tested) |
| Jev API key | ShowSettingsGUI → JevKeyBox (Password) → SaveJevSettings → Settings/JevKey.txt; cache chỉ cập nhật sau khi ghi thành công, không log key | (not tested) |
| Blueprint chọn buff | JevBuffBlueprint → JevScore → JevParseBuffScores → ChooseCard. Chỉ gửi 3 nội dung thẻ; buff tốt nhất / nerf nhẹ nhất; unknown thận trọng; API lỗi dùng local | (not tested) |
| Summer Event | SummerEventMode → SummerVerificationVisible → SummerReadUI / SummerClick / SummerWalk → DetectSummerMap → FindSummerMapTemplate / ParseSummerMapName → RestartStage(map) → MoveForSummerCourtyard (sân mới) | (not tested) |
| Map cũ | GetCurrentMapName dùng SummerMapName; LoadUnitCoordsFromFile ưu tiên cấu hình Summer, nếu thiếu thì đọc Infinite/Story/Legend cùng map; không đổi route cũ | (not tested) |
| Panel unit mới | FindUpdatedUnitPanel (OCR Upgrade + First/Sell hoặc header UPG), CloseUnitPanel dùng tọa độ Client; ReadUnitUpgradeLevel đọc riêng header tương phản. Summer không dùng mảng màu gameplay để suy ra đã mở panel | (not tested) |
| Điều hướng kết quả | ChooseResultRoute / ClassifyResultScreen / ReadResultScreen / ResultScreenReady / TryResultAction / ContinueAfterResult / MonitorEndScreen; lưu Matchmaking trong Configuration.txt, Confirm không tự bật lại lựa chọn solo | (not tested) |

**Bằng chứng từng phần:** Main.ahk validate exit 0; test key/persistence/password; test blueprint và API thật; GUI mới đã quan sát được chữ dropdown nguyên vẹn. Game đã vào Summer Event và ghép trận với người bằng FixClick sau CAPTCHA do user làm. Trận cùng người kết thúc wave 28; đã thấy unit Chuuni gây sát thương và kill. PollSummerCards gửi một vote thật (OCR 78ms/API438ms), sau đó cải thiện OCR và xử lý panel che thẻ. Replay solo dùng để kiểm tra route; không gọi các lượt thất bại là pass toàn luồng.

**Chưa xác nhận:** Nhận diện mọi map loading/font/màu; mọi movement Summer; placement/count/upgrade full vòng với panel mới; OCR mọi ký hiệu dấu của hiệu ứng thẻ; replay tự động khi map đổi. Probe gameplay 145s đã timeout khi slot 4 tiếp tục thử mặc dù hotbar hiển thị 3/3; đã sửa detector/đóng panel nhưng chưa coi toàn luồng ổn định. Xem context.md để biết log và kiểm tra cụ thể.

**Quy tắc cuối trận user chốt:** Matchmaking quyết định Return lobby/Replay. Safe fallback không click ngẫu nhiên: cần xác nhận cụm result UI và đúng nhãn nút trong vùng tọa độ đã đo, kiểm tra lại trạng thái trước click. Không xác nhận được nút thì dừng sau thời hạn; không giả định thắng/thua và không gửi webhook kết quả giả. Đã test Return lobby thật: `Result UI: lobby (matchmaking=1)`, JSON probe 1375ms không exception, ảnh sau thao tác là hub. Trạng thái tổng thể vẫn **(not tested)**.

# Settings — mẫu trống

Thư mục này trên GitHub **chỉ chứa file mẫu** (`*.example.txt`).
Không có webhook, API key, ID Discord, private server hay toạ độ đặt quân của ai.

File thật do macro tự tạo trong cùng thư mục này khi bạn bấm **Save** trong GUI
(hoặc ở lần chạy đầu tiên). Chúng nằm trong `.gitignore`, nên không bao giờ bị push.

| File mẫu | File thật | Nội dung |
|---|---|---|
| `Configuration.example.txt` | `Configuration.txt` | Mode, map, 6 unit, matchmaking |
| `Keybinds.example.txt` | `Keybinds.txt` | Phím tắt F1–F4 |
| `UINavigation.example.txt` | `UINavigation.txt` | Phím điều hướng UI |
| `SendActivityLogs.example.txt` | `SendActivityLogs.txt` | `1` = gửi log hoạt động, `0` = tắt |
| `WebhookURL.example.txt` | `WebhookURL.txt` | Webhook Discord (để trống) |
| `DiscordUSERID.example.txt` | `DiscordUSERID.txt` | ID Discord để tag (để trống) |
| `PrivateServer.example.txt` | `PrivateServer.txt` | Link private server (để trống) |
| `JevKey.example.txt` | `JevKey.txt` | API key Jev (để trống) |
| `Cards.example.txt` | `Cards.txt` | Thuộc tính thẻ bài |
| `UnitCoordinates.example.txt` | `<Map>_<Mode>.txt` | Toạ độ đặt 6 unit |

## Cách dùng

Trong GUI, nhập API key ở **JEV → Save key**, webhook và Discord ID ở **Discord → Save**. Để cấu hình bằng file, sao chép mẫu tương ứng rồi điền vào bản sao. Ví dụ từ thư mục `AA mango`, chạy `Copy-Item Settings\JevKey.example.txt Settings\JevKey.txt` khi chưa có `JevKey.txt`. Giữ bốn mẫu JevKey, WebhookURL, DiscordUSERID và PrivateServer trống hoàn toàn trong Git.

Đừng commit file thật: `pre-commit` sẽ chặn mọi file trong `Settings/`
trừ `*.example.txt` và `README.example.md`.

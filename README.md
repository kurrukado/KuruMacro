# ⚡ Welcome to KuruMacro

> An open-source auto-play macro tool for my favorite Roblox games.  
> *Polished on April 23, 2025 — Built upon community macros.*

![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0-green?style=flat-square&logo=autohotkey)

---

## 🎮 Supported Games

| Game | Status |
| :--- | :---: |
| **Anime Adventures** | Active / Ongoing |
| **Anime Rangers** | Outdated |
| **Anime Vanguards** | Outdated |
| **Anime Universal Tower Defense** | Discontinued (Game Closed) |

---

## 📥 Download

Each game lives in its own folder (`AA mango/`, `AR mango/`, `AV mango/`, `UTD mango/`).
Open a folder to browse or read the `.ahk` source directly on GitHub.

To grab everything as a single archive, use the green **Code → Download ZIP** button.
Runtime folders (`Settings/`, `Logs/`) are intentionally not included — they hold
webhooks and account-specific config, so create them on first launch.

Only these paths are published:

```
AA mango/  AR mango/  AV mango/  UTD mango/  .agents/
AGENTS.md  ARCHITECTURE.md  README.md  context.md  .gitignore
```

`AA-mango-dev/` (test harness, probes, backups) and anything under `Settings/`
or `Logs/` stays local. `.githooks/pre-commit` refuses those paths and any
secret-looking string, so `git pub "message"` (add + commit + push) is safe
without picking files by hand.

---

## 🛠️ Technical Details
- **Core Engine:** Powered by **AutoHotkey v2 (AHK v2)**.
- **Interface:** Includes a clean, user-friendly **Custom GUI**.
- **Transparency:** 100% functional and **open-source**.

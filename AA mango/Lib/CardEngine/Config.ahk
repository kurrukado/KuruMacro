; Module runtime defaults. User data paths are relative to this application Settings/Logs.
global CARD_ENABLED := true            ; measured on live Summer UI, 800x599 (not tested end-to-end)
global CARD_DEADLINE_MS := 5000        ; man hinh the tu dong dong
global CARD_READ_BUDGET_MS := 4000     ; measured local Paddle batch; offer deadline still caps total time
global CARD_UNKNOWN_SCORE := -101      ; unknown sau tat ca the da biet (-100..100)
global CARD_X := [224, 400, 577]        ; client coordinates, live Summer cards
global CARD_Y := 320
global CARD_STRIP := {x1: 143, y1: 210, x2: 658, y2: 405} ; all text/effects, client coordinates
global CARD_GATE := {x: 0, y: 0, color: 0x000000, tol: 12} ; pixel nhan biet - CHUA DO
global CARD_TABLE := 0
global CARD_LEARNED := 0
global CARD_LEARNING := true

global JEV_ENABLED := true
global JEV_URL := "https://api.typesafe.ai/v1/systemone"
global JEV_MODEL := "jev-latest"
global JEV_TIMEOUT_MS := 1200
global JEV_KEY := ""
global JEV_LAST_MS := 0
global JEV_MIN_UNDERSTOOD := 0.85       ; khong hoc/chon OCR mo ho nhu mot buff

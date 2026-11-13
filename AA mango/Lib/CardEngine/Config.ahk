; Module runtime configuration. Data paths remain under DEV Settings/Logs.
global CARD_ENABLED := true            ; measured on live Summer UI, 800x599 (not tested end-to-end)
global CARD_PADDLE_ENABLED := false    ; Windows OCR avoids a resident Python worker and models.
global CARD_DEADLINE_MS := 10000        ; man hinh the tu dong dong
global CARD_READ_BUDGET_MS := 4000     ; measured local Paddle batch; offer deadline still caps total time
global CARD_UNKNOWN_SCORE := -101      ; unknown sau tat ca the da biet (-100..100)
global CARD_X := [224, 400, 577]        ; client coordinates, live Summer cards
global CARD_Y := 320
global CARD_STRIP := {x1: 143, y1: 210, x2: 658, y2: 405} ; all text/effects, client coordinates
global CARD_GATE := {x: 0, y: 0, color: 0x000000, tol: 12} ; pixel nhan biet - CHUA DO
global CARD_TABLE := 0
global CARD_LEARNED := 0
global CARD_LEARNING := true

global JEV_MODEL := "jev-latest"

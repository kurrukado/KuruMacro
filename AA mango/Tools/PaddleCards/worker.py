"""Local, card-ROI-only PaddleOCR worker. No screen capture or game input."""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent
os.environ.setdefault("PADDLE_PDX_CACHE_HOME", str(ROOT / "models"))
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
import argparse
import base64
from copy import deepcopy
import hashlib
import io
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

READY = False
ENGINE = None
BUSY = threading.Lock()
SLOT_LEFT = (5, 182, 359)


class OfferCache:
    """Exact new-frame equality only; never reuse across offers or after expiry."""
    def __init__(self, clock=time.monotonic):
        self.clock, self.offer, self.entries = clock, "", {}

    def get(self, offer, slot, digest):
        if not offer:
            return None
        if offer != self.offer:
            self.offer, self.entries = offer, {}
        entry = self.entries.get(slot)
        if entry and entry[0] == digest and self.clock()-entry[1] < 5:
            result = deepcopy(entry[2])
            result["cache"] = True
            return result
        return None

    def put(self, offer, slot, digest, details):
        if not offer or not details["accepted"]:
            return
        if offer != self.offer:
            self.offer, self.entries = offer, {}
        self.entries[slot] = (digest, self.clock(), deepcopy(details))


CACHE = OfferCache()


def initialize():
    global READY, ENGINE
    from paddleocr import PaddleOCR
    ENGINE = PaddleOCR(
        text_detection_model_name="PP-OCRv5_mobile_det",
        text_recognition_model_name="en_PP-OCRv5_mobile_rec",
        use_doc_orientation_classify=False, use_doc_unwarping=False,
        use_textline_orientation=False, device="cpu",
        cpu_threads=max(1, min(4, (os.cpu_count() or 4)//4)),
        enable_mkldnn=True,
    )
    READY = True


def split_board(image):
    """Input is ONLY client [143,210,515,195], scaled to actual client size."""
    w, h = image.size
    if not (200 <= w <= 2060 and 70 <= h <= 780):
        raise ValueError("Expected a cropped card board, not a full screen")
    if abs(w / h - 515 / 195) > 0.06:
        raise ValueError("Unexpected card-board aspect ratio")
    return [image.crop((round(left*w/515), 0, round((left+152)*w/515), h))
            for left in SLOT_LEFT]


def recognize(image, only_slot=0, offer=""):
    import cv2
    import numpy as np
    import re
    cards = split_board(image)
    width, height = image.size
    requested = [only_slot] if only_slot else [1,2,3]
    digests = {slot: hashlib.blake2b(cards[slot-1].convert("RGB").tobytes(),digest_size=16).digest() for slot in requested} if offer else {}
    cached = {slot: CACHE.get(offer,slot,digests[slot]) for slot in requested} if offer else {}
    needed = [slot for slot in requested if not cached.get(slot)]
    if not needed:
        names = ["", "", ""]
        for slot in requested:
            names[slot-1] = cached[slot]["text"]
        return names, [cached[slot] for slot in requested]
    if only_slot:
        source = cards[only_slot-1].convert("RGB")
    else:
        from PIL import Image
        source = Image.new("RGB", image.size, "black")
        for slot in needed:
            source.paste(cards[slot-1], (round(SLOT_LEFT[slot-1]*width/515), 0))
    scaled = cv2.resize(np.asarray(source), None, fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
    prediction = list(ENGINE.predict(cv2.cvtColor(scaled, cv2.COLOR_RGB2BGR),
                      text_det_limit_side_len=960, text_det_limit_type="max"))
    grouped = [[], [], []]
    for data in prediction:
        for text, confidence, polygon in zip(data["rec_texts"], data["rec_scores"], data["rec_polys"]):
            center = sum(float(p[0]) for p in polygon)/len(polygon)/3
            slot = only_slot or next((i for i,left in enumerate(SLOT_LEFT,1)
                         if left*width/515 <= center <= (left+152)*width/515), 0)
            if not slot:
                continue
            raw = text.strip()
            # Re-read only ambiguous numeric lines using colored ink on white.
            # Never manufacture '+' from '*'; require independent visual recognition.
            if re.search(r"\d", raw) and not re.search(r"[+-]\s*\d", raw):
                x1=max(0,int(min(p[0] for p in polygon))-3)
                x2=min(scaled.shape[1],int(max(p[0] for p in polygon))+4)
                y1=max(0,int(min(p[1] for p in polygon))-3)
                y2=min(scaled.shape[0],int(max(p[1] for p in polygon))+4)
                crop=scaled[y1:y2,x1:x2]
                if crop.size and hasattr(ENGINE,"paddlex_pipeline"):
                    r,g,b=[crop[:,:,i].astype("int16") for i in range(3)]
                    ink=((r>110)&(r>g*1.4)&(r>b*1.2)) | ((g>110)&(g>r*1.3)&(g>b*1.3)) | ((r>160)&(g>110)&(b<130)) | ((r>180)&(g>180)&(b>180))
                    clean=np.where(ink,0,255).astype("uint8")
                    clean=cv2.copyMakeBorder(clean,8,8,8,8,cv2.BORDER_CONSTANT,value=255)
                    clean=cv2.cvtColor(clean,cv2.COLOR_GRAY2BGR)
                    corrected=list(ENGINE.paddlex_pipeline.text_rec_model([clean]))[0]
                    candidate=corrected["rec_text"]
                    if (re.search(r"[+-]\s*\d",candidate) and
                        re.findall(r"\d+(?:\.\d+)?",candidate)==re.findall(r"\d+(?:\.\d+)?",raw)
                        and float(corrected["rec_score"])>=0.65):
                        # Only transfer the visually re-read sign; retain the
                        # original words so a binary pass cannot corrupt a stat.
                        signed=re.search(r"([+-])\s*\d",candidate)
                        number=re.search(r"\*?\s*(\d+(?:\.\d+)?)",raw)
                        text=raw[:number.start()]+signed[1]+number[1]+raw[number.end():]
                        confidence=min(float(confidence),float(corrected["rec_score"]))
            offset = 0 if only_slot else SLOT_LEFT[slot-1]*width/515
            grouped[slot-1].append({"text":text.strip(),"raw":raw,"confidence":float(confidence),
                       "box":[[float(x)/3-offset,float(y)/3] for x,y in polygon]})
    names, details = ["", "", ""], []
    for slot, lines in enumerate(grouped,1):
        if only_slot and slot!=only_slot:
            continue
        if cached.get(slot):
            names[slot-1] = cached[slot]["text"]
            details.append(cached[slot])
            continue
        lines.sort(key=lambda row:(min(p[1] for p in row["box"]),min(p[0] for p in row["box"])))
        accepted=bool(lines) and all(row["confidence"]>=0.65 for row in lines)
        text=" ".join(row["text"] for row in lines)
        if accepted:
            names[slot-1]=text
        entry={"slot":slot,"accepted":accepted,"text":text,"lines":lines,"cache":False}
        details.append(entry)
        if offer:
            CACHE.put(offer,slot,digests[slot],entry)
    return names, details

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def respond(self, code, value):
        body = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass

    def do_GET(self):
        self.respond(200 if self.path == "/health" else 404,
                     {"engine": "paddleocr", "ready": READY})

    def do_POST(self):
        if self.path != "/cards":
            return self.respond(404, {"error": "unknown endpoint"})
        if not READY or not BUSY.acquire(blocking=False):
            return self.respond(503, {"error": "not ready or busy"})
        started = time.monotonic()
        try:
            from PIL import Image
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 3_000_000:
                raise ValueError("Invalid request size")
            request = json.loads(self.rfile.read(size))
            slot = request.get("onlySlot", 0)
            if type(slot) is not int or slot not in range(4):
                raise ValueError("Invalid slot")
            offer = request.get("offer", "")
            if type(offer) is not str or len(offer) > 128:
                raise ValueError("Invalid offer identity")
            image = Image.open(io.BytesIO(base64.b64decode(request["image"], validate=True)))
            names, details = recognize(image, slot, offer)
            self.respond(200, {"id": request["id"], "names": names, "details": details,
                               "elapsedMs": round((time.monotonic()-started)*1000)})
        except Exception:
            self.respond(400, {"error": "invalid card crop or inference failed"})
        finally:
            BUSY.release()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=48192)
    parser.add_argument("--image")
    parser.add_argument("--output")
    args = parser.parse_args()
    if args.image:
        from PIL import Image
        initialize()
        started = time.monotonic()
        names, details = recognize(Image.open(args.image))
        Path(args.output).write_text(json.dumps({"names": names, "details": details,
                    "elapsedMs": round((time.monotonic()-started)*1000)}, ensure_ascii=False, indent=2), encoding="utf-8")
        return
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    threading.Thread(target=initialize, daemon=True).start()
    server.serve_forever()


if __name__ == "__main__":
    main()

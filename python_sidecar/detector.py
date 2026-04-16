"""
FocusOS — Phone Detection Sidecar
==================================
Reads webcam frames via OpenCV, detects phones with MediaPipe ObjectDetector,
and watches for the "hands-raise" dismissal gesture (both hands raised above
nose level, face centred in frame).

Communication with Flutter via stdin/stdout line-delimited JSON:

  FLUTTER → SIDECAR (stdin):
    {"cmd": "ARM"}    — start monitoring
    {"cmd": "DISARM"} — stop monitoring (keep process alive)
    {"cmd": "QUIT"}   — exit process

  SIDECAR → FLUTTER (stdout):
    {"event": "READY"}
    {"event": "STATUS", "msg": "..."}
    {"event": "PHONE_DETECTED"}
    {"event": "ALARM_DISMISSED"}
    {"event": "ERROR", "msg": "..."}

Detection logic:
  • Phone must appear in 3 consecutive ~500 ms scans before PHONE_DETECTED.
  • When alarm is active, every frame is checked for the dismissal gesture.
  • Dismissal: MediaPipe Hands finds ≥2 hands & both wrists are above the nose
    landmark from FaceMesh, AND the face nose tip is in the middle 50% of the
    frame width.
"""

import sys
import json
import time
import threading
import traceback

import cv2
import mediapipe as mp

# ── Constants ──────────────────────────────────────────────────────────────────

SCAN_INTERVAL_SEC   = 0.5   # check cycle
PHONE_BUFFER        = 3     # consecutive detections before alarm
PHONE_CONFIDENCE    = 0.15  # Extra low confidence to debug detection
DISMISS_HOLD_FRAMES = 2     # consecutive frames hands must be raised to dismiss

# MediaPipe model paths (bundled or downloaded automatically by mediapipe)
# We use the legacy `solutions` API which ships bundled models — no extra files.

# ── Helpers ────────────────────────────────────────────────────────────────────

def emit(obj: dict):
    """Write a JSON line to stdout (Flutter reads this)."""
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def log(msg: str):
    emit({"event": "STATUS", "msg": msg})


# ── Detector class ─────────────────────────────────────────────────────────────

class PhoneDetector:
    def __init__(self):
        # State
        self._armed          = False
        self._alarm_active   = False
        self._phone_count    = 0          # consecutive phone detections
        self._dismiss_count  = 0          # consecutive hands-raised frames
        self._running        = False
        self._lock           = threading.Lock()

        # MediaPipe solutions
        mp_hands  = mp.solutions.hands
        mp_face   = mp.solutions.face_mesh
        mp_objdet = mp.solutions.objectron  # not available in all builds
        self._mp_obj = mp.solutions.object_detection if hasattr(mp.solutions, 'object_detection') else None

        self._hands = mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=2,
            min_detection_confidence=0.6,
            min_tracking_confidence=0.5,
        )
        self._face_mesh = mp_face.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=False,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )

        # For phone detection we use the Objectron or fall back to a simple
        # COCO SSD via the object_detection Tasks API.  Because MediaPipe
        # solutions.object_detection was removed in newer versions we use the
        # Tasks API (mediapipe >= 0.10).
        self._obj_detector = self._init_object_detector()

    # ── Object detector initialisation ────────────────────────────────────────

    def _init_object_detector(self):
        """
        Try to initialise MediaPipe Tasks ObjectDetector.
        Downloads the EfficientDet-Lite0 model on first run.
        Falls back gracefully if unavailable.
        """
        try:
            import urllib.request, os, tempfile
            from mediapipe.tasks import python as mp_python
            from mediapipe.tasks.python import vision as mp_vision

            model_url = (
                "https://storage.googleapis.com/mediapipe-models/"
                "object_detector/efficientdet_lite0/float32/1/"
                "efficientdet_lite0.tflite"
            )
            model_dir  = os.path.join(os.path.expanduser("~"), "Documents", "FocusOS", "sidecar")
            os.makedirs(model_dir, exist_ok=True)
            model_path = os.path.join(model_dir, "efficientdet_lite0.tflite")

            if not os.path.exists(model_path):
                log("Downloading phone-detection model (~13 MB)…")
                urllib.request.urlretrieve(model_url, model_path)
                log("Model downloaded.")

            BaseOptions   = mp_python.BaseOptions
            ObjectDetector = mp_vision.ObjectDetector
            DetectorOpts  = mp_vision.ObjectDetectorOptions
            RunningMode   = mp_vision.RunningMode

            options = DetectorOpts(
                base_options=BaseOptions(model_asset_path=model_path),
                running_mode=RunningMode.IMAGE,
                score_threshold=PHONE_CONFIDENCE,
                category_allowlist=["cell phone"],
            )
            detector = ObjectDetector.create_from_options(options)
            log("ObjectDetector ready (EfficientDet-Lite0).")
            return detector
        except Exception as exc:
            emit({"event": "ERROR", "msg": f"Object detector init failed: {exc}. Phone detection disabled."})
            return None

    # ── Public control ─────────────────────────────────────────────────────────

    def arm(self):
        with self._lock:
            self._armed       = True
            self._phone_count = 0
            self._alarm_active = False
            self._dismiss_count = 0
        log("Armed — watching for phone.")

    def disarm(self):
        with self._lock:
            self._armed       = False
            self._alarm_active = False
            self._phone_count = 0
            self._dismiss_count = 0
        log("Disarmed.")

    # ── Per-frame processing ───────────────────────────────────────────────────

    def process_frame(self, frame_bgr):
        """Called once per scan cycle. Returns nothing — emits events."""
        with self._lock:
            armed        = self._armed
            alarm_active = self._alarm_active

        if not armed:
            return

        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)

        # ── 1. Phone detection ──────────────────────────────────────────────
        phone_seen = self._detect_phone(rgb, frame_bgr)

        with self._lock:
            if not self._alarm_active:
                # Temporal buffer logic
                if phone_seen:
                    self._phone_count += 1
                    log(f"Phone scan {self._phone_count}/{PHONE_BUFFER}")
                else:
                    if self._phone_count > 0:
                        log("Phone gone — buffer reset.")
                    self._phone_count = 0

                if self._phone_count >= PHONE_BUFFER:
                    self._alarm_active = True
                    self._dismiss_count = 0
                    emit({"event": "PHONE_DETECTED"})
                    log("ALARM ON — phone detected 3× in a row.")
                return  # don't run dismissal check this cycle

        # ── 2. Dismissal gesture check (only when alarm is active) ──────────
        dismissed = self._check_dismissal(rgb, frame_bgr)

        with self._lock:
            if dismissed:
                self._dismiss_count += 1
                log(f"Dismissal gesture held {self._dismiss_count}/{DISMISS_HOLD_FRAMES}")
                if self._dismiss_count >= DISMISS_HOLD_FRAMES:
                    self._alarm_active  = False
                    self._phone_count   = 0
                    self._dismiss_count = 0
                    emit({"event": "ALARM_DISMISSED"})
                    log("ALARM OFF — hands raised & face centred.")
            else:
                if self._dismiss_count > 0:
                    log("Dismissal gesture broken — hold steady.")
                self._dismiss_count = 0

    # ── Phone detection helper ─────────────────────────────────────────────────

    def _detect_phone(self, rgb, bgr) -> bool:
        """Returns True if a cell phone is confidently detected."""
        if self._obj_detector is not None:
            try:
                import mediapipe as mp_inner
                mp_image = mp_inner.Image(
                    image_format=mp_inner.ImageFormat.SRGB, data=rgb
                )
                result = self._obj_detector.detect(mp_image)
                for det in result.detections:
                    for cat in det.categories:
                        if cat.score >= 0.3:
                            log(f"Debug: saw {cat.category_name} ({cat.score:.2f})")
                        if "phone" in cat.category_name.lower() and cat.score >= PHONE_CONFIDENCE:
                            return True
                return False
            except Exception as e:
                emit({"event": "ERROR", "msg": f"ObjDet error: {e}"})
                return False
        else:
            # Fallback: no detector available
            return False

    # ── Dismissal check helper ─────────────────────────────────────────────────

    def _check_dismissal(self, rgb, bgr) -> bool:
        """
        Returns True if:
          - MediaPipe detects ≥2 hands
          - Both wrists are above (i.e. lower y-value than) the nose tip
          - The nose tip x-coordinate is within the middle 50% of frame width
        MediaPipe landmark coords are normalised [0,1], origin = top-left.
        So "above" means LOWER y value.
        """
        h, w = rgb.shape[:2]

        # Face detection
        face_result = self._face_mesh.process(rgb)
        if not face_result.multi_face_landmarks:
            return False

        face_lm   = face_result.multi_face_landmarks[0].landmark
        # Landmark 1 = nose tip in FaceMesh 468-point model
        nose_y    = face_lm[1].y
        nose_x    = face_lm[1].x

        # Nose must be in middle 50% horizontally (facing camera, not turned away)
        if nose_x < 0.25 or nose_x > 0.75:
            return False

        # Hand detection
        hand_result = self._hands.process(rgb)
        if not hand_result.multi_hand_landmarks or len(hand_result.multi_hand_landmarks) < 2:
            return False

        # Check both wrists (landmark 0) are above nose
        for hand_lm in hand_result.multi_hand_landmarks:
            wrist_y = hand_lm.landmark[0].y
            if wrist_y >= nose_y:   # wrist is BELOW nose → not raised
                return False

        return True

    def close(self):
        self._hands.close()
        self._face_mesh.close()
        if self._obj_detector:
            self._obj_detector.close()


# ── Main loop ──────────────────────────────────────────────────────────────────

def main():
    detector = PhoneDetector()
    cap      = None

    def open_camera():
        nonlocal cap
        for idx in range(3):  # try indices 0, 1, 2
            c = cv2.VideoCapture(idx)
            if c.isOpened():
                c.set(cv2.CAP_PROP_FRAME_WIDTH,  640)
                c.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap = c
                log(f"Camera opened (index {idx}).")
                return True
        emit({"event": "ERROR", "msg": "No camera found."})
        return False

    if not open_camera():
        emit({"event": "ERROR", "msg": "Could not open any camera."})
        sys.exit(1)

    emit({"event": "READY"})

    # ── stdin reader thread ────────────────────────────────────────────────────
    def read_stdin():
        for raw in sys.stdin:
            raw = raw.strip()
            if not raw:
                continue
            try:
                msg = json.loads(raw)
                cmd = msg.get("cmd", "")
                if   cmd == "ARM":    detector.arm()
                elif cmd == "DISARM": detector.disarm()
                elif cmd == "QUIT":
                    log("Quit command received.")
                    detector.close()
                    if cap:
                        cap.release()
                    import os
                    os._exit(0)
            except Exception:
                emit({"event": "ERROR", "msg": f"Bad stdin: {raw}"})
        
        # If we break out of the loop, the parent process closed the stdin pipe.
        log("Stdin closed. Exiting.")
        import os
        os._exit(0)

    t = threading.Thread(target=read_stdin, daemon=True)
    t.start()

    # ── Main scan loop ─────────────────────────────────────────────────────────
    while True:
        try:
            ret, frame = cap.read()
            if not ret:
                log("Camera read failed — retrying…")
                time.sleep(1.0)
                cap.release()
                time.sleep(0.5)
                if not open_camera():
                    time.sleep(3.0)
                continue

            detector.process_frame(frame)
            time.sleep(SCAN_INTERVAL_SEC)

        except KeyboardInterrupt:
            break
        except Exception:
            emit({"event": "ERROR", "msg": traceback.format_exc()})
            time.sleep(1.0)

    detector.close()
    if cap:
        cap.release()


if __name__ == "__main__":
    main()

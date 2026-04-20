"""
FocusOS — Face Monitor Sidecar v5 (Production Quality)
=======================================================
All improvements from the v4 analysis applied:

  ✅ #1  Gaze smoothing — 5-frame rolling average before threshold check
  ✅ #2  Blink guard    — skip gaze when eye-span < MIN_EYE_SPAN (closed/squinting)
  ✅ #3  Leaky bucket   — replaces strict consecutive counter (+2 / -1)
  ✅ #4  Cause payload  — PHONE_DISTRACTION carries "cause" field for Flutter logs
  ✅ #5  Corrected yaw  — landmarks 127/356 (stable ear-side) not 234/454
  ✅ #6  Lower YOLO     — crops bottom half at higher sens when pitch already high
  ✅ #7  CLAHE          — lighting normalisation before MediaPipe + YOLO
  ✅ #8  Pitch smoothing — 5-frame rolling average (same as gaze)

Communication with Flutter via stdin/stdout (line-delimited JSON):

  FLUTTER → SIDECAR:
    {"cmd": "ARM"}    — start monitoring
    {"cmd": "DISARM"} — stop, emit SESSION_SUMMARY, keep process alive
    {"cmd": "QUIT"}   — exit process

  SIDECAR → FLUTTER:
    {"event": "READY"}
    {"event": "STATUS", "msg": "..."}
    {"event": "PHONE_DISTRACTION", "cause": "<yolo_phone|gaze_pitch|head_yaw>"}
    {"event": "ALARM_DISMISSED"}
    {"event": "NO_FACE", "seconds": N}
    {"event": "FACE_BACK"}
    {"event": "FOCUS_SCORE", "score": 0-100, "logs": [...]}
    {"event": "SESSION_SUMMARY", "score": 0-100, "logs": [...]}
    {"event": "ERROR", "msg": "..."}
    {"event": "FRAME", "b64": "..."}
"""

import sys
import json
import time
import threading
import traceback
import base64
from collections import deque

import cv2
import mediapipe as mp
import numpy as np
from ultralytics import YOLO

# ── Tuning constants ───────────────────────────────────────────────────────────

SCAN_INTERVAL_SEC    = 0.15   # ~6-7 FPS processing
YOLO_INTERVAL_SEC    = 1.5    # YOLO full-frame scan frequency
YOLO_LOWER_INTERVAL  = 0.8    # more frequent lower-half scan when pitching
YOLO_RESULT_TTL      = 3.0    # seconds a YOLO phone detection stays valid
YOLO_CONF_FULL       = 0.55   # confidence threshold — full frame
YOLO_CONF_LOWER      = 0.42   # confidence threshold — lower half (lap area)
NO_FACE_THRESHOLD    = 5.0    # seconds before NO_FACE event fires
DISMISS_HOLD_FRAMES  = 3      # frames hands must be raised to dismiss
SCORE_INTERVAL_SEC   = 60     # periodic FOCUS_SCORE emit interval

# ── Leaky bucket thresholds ────────────────────────────────────────────────────
#   On each distracted frame: bucket += BUCKET_FILL
#   On each clean frame:      bucket -= BUCKET_DRAIN  (floor 0)
#   Alarm fires when:         bucket >= BUCKET_CAPACITY
#
#   At 6-7 FPS a sustained 2-second distraction fills the bucket:
#     2s × 6fps × FILL(2) = 24  ≥  CAPACITY(20)  → alarm
#   A single bad frame takes 10 clean frames to drain fully (no false alarm).

BUCKET_CAPACITY      = 20
BUCKET_FILL          = 2      # added per distracted frame
BUCKET_DRAIN         = 1      # removed per clean frame

# ── Gaze / pose thresholds ────────────────────────────────────────────────────
#
#   pitch_norm  — nose y-offset from face-midpoint, normalised by face height.
#                 Level head ≈ 0.  Looking down at phone ≈ 0.10-0.20.
#
#   gaze_rel    — iris centre as fraction of eye opening (top → bottom eyelid).
#                 Straight ahead ≈ 0.50.  Clearly down ≈ 0.65+.
#
#   yaw_ratio   — nose x as fraction of ear-side span (lm127 → lm356).
#                 Straight ≈ 0.50.  Hard left/right turn → < 0.25 or > 0.75.
#
HEAD_PITCH_THRESHOLD = 0.08   # smoothed pitch_norm above this = looking down
GAZE_DOWN_THRESHOLD  = 0.62   # smoothed gaze_rel above this  = eyes down
MIN_EYE_SPAN         = 0.008  # normalised — below this = eye closed / blink skip
YAW_THRESHOLD_LO     = 0.25
YAW_THRESHOLD_HI     = 0.75
YAW_SUSTAIN_FRAMES   = 4      # yaw must persist this many frames before counting
SMOOTH_WINDOW        = 5      # frames for rolling average on pitch + gaze

# ── Helpers ────────────────────────────────────────────────────────────────────

def emit(obj: dict):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def log(msg: str):
    emit({"event": "STATUS", "msg": msg})


_clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))

def enhance_frame(bgr):
    """Apply CLAHE lighting normalisation — improves FaceMesh in dim/backlit rooms."""
    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    lab[:, :, 0] = _clahe.apply(lab[:, :, 0])
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)


def _timestamp() -> str:
    t = time.localtime()
    return f"{t.tm_hour:02d}:{t.tm_min:02d}:{t.tm_sec:02d}"


# ── Detector ───────────────────────────────────────────────────────────────────

class FaceMonitor:
    def __init__(self):
        # ── state ────────────────────────────────────────────────────────────
        self._armed               = False
        self._alarm_active        = False
        self._force_camera_reconnect = False
        self._alarm_start_time    = None
        self._distraction_bucket  = 0     # leaky bucket value
        self._dismiss_count       = 0
        self._no_face_start       = None
        self._no_face_fired       = False
        self._face_was_present    = False
        self._lock                = threading.Lock()

        # ── smoothing windows ────────────────────────────────────────────────
        self._pitch_window  = deque(maxlen=SMOOTH_WINDOW)
        self._gaze_window   = deque(maxlen=SMOOTH_WINDOW)
        self._yaw_sustained = 0

        # ── session stats ────────────────────────────────────────────────────
        self._session_start       = None
        self._distraction_secs    = 0.0
        self._no_face_secs        = 0.0
        self._distraction_start   = None
        self._no_face_event_start = None
        self._logs: list[dict]    = []
        self._last_score_emit     = 0

        # ── MediaPipe ────────────────────────────────────────────────────────
        mp_face  = mp.solutions.face_mesh
        mp_hands = mp.solutions.hands

        self._face_mesh = mp_face.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,          # enables iris landmarks 468-477
            min_detection_confidence=0.6,
            min_tracking_confidence=0.6,
        )
        self._hands = mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=2,
            min_detection_confidence=0.6,
            min_tracking_confidence=0.6,
        )

        # ── YOLO ─────────────────────────────────────────────────────────────
        log("Loading YOLOv8s detector…")
        self._yolo = YOLO('yolov8s.pt')

        self._last_yolo_full_time  = 0.0
        self._last_yolo_lower_time = 0.0
        self._yolo_phone_detected  = False
        self._yolo_detection_time  = 0.0

        log("MediaPipe FaceMesh + Hands + YOLOv8 ready.")

    def arm(self, force_camera_reconnect=False):
        with self._lock:
            self._armed               = True
            self._alarm_active        = False
            self._alarm_start_time    = None
            self._distraction_bucket  = 0
            self._dismiss_count       = 0
            self._no_face_fired       = False
            self._no_face_start       = None
            self._face_was_present    = False
            self._session_start       = time.monotonic()
            self._distraction_secs    = 0.0
            self._no_face_secs        = 0.0
            self._distraction_start   = None
            self._no_face_event_start = None
            self._logs                = []
            self._last_score_emit     = time.monotonic()
            self._yaw_sustained       = 0
            self._yolo_phone_detected = False
            self._pitch_window.clear()
            self._gaze_window.clear()
        self._force_camera_reconnect = force_camera_reconnect
        log("Armed — watching face.")

    def disarm(self):
        summary = None
        with self._lock:
            if self._armed:
                self._armed        = False
                self._alarm_active = False
                now = time.monotonic()
                if self._distraction_start is not None:
                    self._distraction_secs += now - self._distraction_start
                    self._distraction_start = None
                if self._no_face_event_start is not None:
                    self._no_face_secs += now - self._no_face_event_start
                    self._no_face_event_start = None
                score, logs = self._compute_score_and_logs()
                summary = {"event": "SESSION_SUMMARY", "score": score, "logs": logs}
        if summary:
            emit(summary)
        log("Disarmed.")

    # ── Per-frame processing ───────────────────────────────────────────────────

    def process_frame(self, frame_bgr):
        annotated = frame_bgr.copy()

        with self._lock:
            if not self._armed:
                cv2.putText(annotated, "DISARMED", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (150, 150, 150), 2)
                return annotated

        # ── lighting normalisation (improves detection in dim/backlit rooms) ─
        enhanced = enhance_frame(frame_bgr)
        rgb = cv2.cvtColor(enhanced, cv2.COLOR_BGR2RGB)
        h, w = rgb.shape[:2]
        now  = time.monotonic()

        face_result = self._face_mesh.process(rgb)
        hand_result = self._hands.process(rgb)

        face_present = (face_result.multi_face_landmarks is not None
                        and len(face_result.multi_face_landmarks) > 0)

        with self._lock:
            if not self._armed:
                cv2.putText(annotated, "DISARMED", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (150, 150, 150), 2)
                return annotated

            # ── periodic focus score ─────────────────────────────────────────
            if now - self._last_score_emit >= SCORE_INTERVAL_SEC:
                self._last_score_emit = now
                score, logs = self._compute_score_and_logs()
                emit({"event": "FOCUS_SCORE", "score": score, "logs": logs})

            # ── no-face tracking ─────────────────────────────────────────────
            if not face_present:
                cv2.putText(annotated, "NO FACE DETECTED", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                if self._face_was_present or self._no_face_start is None:
                    self._no_face_start    = now
                    self._face_was_present = False

                absence = now - self._no_face_start
                if absence >= NO_FACE_THRESHOLD and not self._no_face_fired:
                    self._no_face_fired       = True
                    self._no_face_event_start = now
                    ts = _timestamp()
                    self._logs.append({"ts": ts, "event": "no_face",
                                       "msg": "Left desk / not visible"})
                    emit({"event": "NO_FACE", "seconds": round(absence, 1)})
                return annotated

            # face returned
            if self._no_face_fired:
                if self._no_face_event_start is not None:
                    self._no_face_secs += now - self._no_face_event_start
                    self._no_face_event_start = None
                emit({"event": "FACE_BACK"})
                self._no_face_fired = False
            self._no_face_start    = None
            self._face_was_present = True

            # ── distraction detection ────────────────────────────────────────
            face_lm = face_result.multi_face_landmarks[0].landmark

            # ── ALWAYS run YOLO scan (even during alarm) to detect phone removal ──
            if now - self._last_yolo_full_time >= YOLO_INTERVAL_SEC:
                self._last_yolo_full_time = now
                phone_found, annotated = self._run_yolo(
                    rgb, annotated, conf=YOLO_CONF_FULL, crop=None)
                if phone_found:
                    self._yolo_phone_detected  = True
                    self._yolo_detection_time  = now
                else:
                    self._yolo_phone_detected  = False

            # ── Expire stale YOLO hit (TTL) ──────────────────────────────
            if self._yolo_phone_detected:
                if now - self._yolo_detection_time > YOLO_RESULT_TTL:
                    self._yolo_phone_detected = False
                else:
                    cv2.putText(annotated, "PHYSICAL PHONE VISIBLE!",
                                (w - 320, 30), cv2.FONT_HERSHEY_SIMPLEX,
                                0.6, (255, 0, 255), 2)

            if not self._alarm_active:

                # ── FaceMesh behaviour check ─────────────────────────────────
                distracted, pitch_s, gaze_s, yaw_ratio, cause = \
                    self._is_distracted(face_lm, w, h)

                # ── Lower-half YOLO when head is pitched down (lap scan) ──────
                if pitch_s > HEAD_PITCH_THRESHOLD:
                    if now - self._last_yolo_lower_time >= YOLO_LOWER_INTERVAL:
                        self._last_yolo_lower_time = now
                        lower_rgb = rgb[h // 2:, :]
                        phone_lower, annotated = self._run_yolo(
                            lower_rgb, annotated,
                            conf=YOLO_CONF_LOWER,
                            crop_offset_y=h // 2)
                        if phone_lower:
                            self._yolo_phone_detected  = True
                            self._yolo_detection_time  = now
                        if phone_lower:
                            self._yolo_phone_detected  = True
                            self._yolo_detection_time  = now
                            cause = "yolo_phone_lap"

                # Final distraction flag
                if self._yolo_phone_detected and not distracted:
                    distracted = True
                    cause      = "yolo_phone"

                # ── Leaky bucket ──────────────────────────────────────────────
                if distracted:
                    self._distraction_bucket = min(
                        BUCKET_CAPACITY + BUCKET_FILL,
                        self._distraction_bucket + BUCKET_FILL
                    )
                else:
                    if self._distraction_bucket > 0:
                        if self._distraction_bucket == BUCKET_FILL:
                            log("Signal gone — bucket draining.")
                        self._distraction_bucket = max(
                            0, self._distraction_bucket - BUCKET_DRAIN)
                    if self._distraction_start is not None:
                        self._distraction_secs += now - self._distraction_start
                        self._distraction_start = None

                # ── Annotate preview ──────────────────────────────────────────
                pcolor = (0, 0, 255) if pitch_s > HEAD_PITCH_THRESHOLD else (0, 220, 0)
                gcolor = (0, 0, 255) if gaze_s  > GAZE_DOWN_THRESHOLD  else (0, 220, 0)
                ycolor = (0, 0, 255) if (yaw_ratio < YAW_THRESHOLD_LO or yaw_ratio > YAW_THRESHOLD_HI) else (0, 220, 0)
                bcolor = (0, 0, 255) if distracted else (0, 220, 0)

                bucket_pct = int(self._distraction_bucket / BUCKET_CAPACITY * 100)
                cv2.putText(annotated, f"Pitch: {pitch_s:.3f}",   (10, 30),  cv2.FONT_HERSHEY_SIMPLEX, 0.55, pcolor, 2)
                cv2.putText(annotated, f"Gaze:  {gaze_s:.3f}",    (10, 58),  cv2.FONT_HERSHEY_SIMPLEX, 0.55, gcolor, 2)
                cv2.putText(annotated, f"Yaw:   {yaw_ratio:.3f}", (10, 86),  cv2.FONT_HERSHEY_SIMPLEX, 0.55, ycolor, 2)
                cv2.putText(annotated, f"Bucket:{bucket_pct}%",   (10, 114), cv2.FONT_HERSHEY_SIMPLEX, 0.55, bcolor, 2)
                cv2.putText(annotated, f"Cause: {cause}",         (10, 142), cv2.FONT_HERSHEY_SIMPLEX, 0.5,  bcolor, 2)

                # ── Alarm trigger — only for YOLO phone detection, NOT gaze/yaw ───────
                has_active_phone = self._yolo_phone_detected
                is_phone_cause = cause in ("yolo_phone", "yolo_phone_lap")
                
                # Only trigger alarm if phone is detected (not for gaze_pitch or head_yaw)
                if self._distraction_bucket >= BUCKET_CAPACITY and has_active_phone:
                    self._alarm_active       = True
                    self._alarm_start_time    = now
                    self._distraction_bucket = 0
                    self._dismiss_count      = 0
                    self._distraction_start  = now
                    ts = _timestamp()
                    self._logs.append({"ts": ts, "event": "phone_distraction",
                                       "msg": f"Distraction: {cause}"})
                    emit({"event": "PHONE_DISTRACTION", "cause": cause})
                    return annotated
                
                # If phone is gone and we had accumulated bucket, drain faster
                if not has_active_phone and not distracted and self._distraction_bucket > 0:
                    self._distraction_bucket = max(0, self._distraction_bucket - BUCKET_DRAIN * 3)

            else:
                # ── ALARM ACTIVE — wait for dismissal ─────────────────────────
                has_phone = self._yolo_phone_detected
                alarm_age = now - (self._alarm_start_time or now)
                auto_dismiss_delay = 1.5  # seconds before auto-dismiss kicks in
                
                if has_phone:
                    cv2.putText(annotated, "ALARM — RAISE HANDS TO DISMISS",
                                (10, 30), cv2.FONT_HERSHEY_SIMPLEX,
                                0.6, (0, 0, 255), 2)
                    dismissed = self._check_dismissal(face_lm, hand_result, w, h)
                    if dismissed:
                        self._dismiss_count += 1
                        if self._dismiss_count >= DISMISS_HOLD_FRAMES:
                            self._alarm_active       = False
                            self._alarm_start_time   = None
                            self._distraction_bucket = 0
                            self._dismiss_count      = 0
                            if self._distraction_start is not None:
                                self._distraction_secs += now - self._distraction_start
                                self._distraction_start = None
                            ts = _timestamp()
                            self._logs.append({"ts": ts, "event": "dismissed",
                                               "msg": "Alarm dismissed (hands raised)"})
                            emit({"event": "ALARM_DISMISSED"})
                    else:
                        if self._dismiss_count > 0:
                            log("Dismissal broken — hold steady.")
                        self._dismiss_count = 0
                else:
                    # Phone is gone — show countdown to auto-dismiss
                    remaining = max(0, auto_dismiss_delay - alarm_age)
                    cv2.putText(annotated, "PHONE GONE — LOOKING AT SCREEN",
                                (10, 30), cv2.FONT_HERSHEY_SIMPLEX,
                                0.6, (0, 200, 0), 2)
                    if remaining > 0:
                        cv2.putText(annotated, f"Auto-clear in {remaining:.1f}s",
                                    (10, 60), cv2.FONT_HERSHEY_SIMPLEX,
                                    0.5, (200, 200, 0), 2)
                    else:
                        # Auto-dismiss — phone gone, no hands needed
                        self._alarm_active       = False
                        self._alarm_start_time   = None
                        self._distraction_bucket = 0
                        self._dismiss_count      = 0
                        if self._distraction_start is not None:
                            self._distraction_secs += now - self._distraction_start
                            self._distraction_start = None
                        ts = _timestamp()
                        self._logs.append({"ts": ts, "event": "dismissed",
                                           "msg": "Alarm auto-cleared (phone removed)"})
                        emit({"event": "ALARM_DISMISSED"})
                        log("Alarm auto-cleared — phone removed.")

        return annotated

    # ── YOLO helper ────────────────────────────────────────────────────────────

    def _run_yolo(self, rgb_crop, annotated, conf: float, crop=None, crop_offset_y: int = 0):
        """Run YOLO on rgb_crop (class 67 = cell phone). Draw boxes on annotated.
        Returns (phone_found: bool, annotated_frame)."""
        results  = self._yolo(rgb_crop, verbose=False, classes=[67], conf=conf)
        found    = False
        for box in results[0].boxes:
            conf_val  = float(box.conf[0])
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            y1 += crop_offset_y
            y2 += crop_offset_y
            cv2.rectangle(annotated, (x1, y1), (x2, y2), (255, 0, 255), 3)
            cv2.putText(annotated, f"PHONE {conf_val:.0%}", (x1, max(0, y1 - 10)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 255), 2)
            found = True
        return found, annotated

    # ── Behaviour helpers ──────────────────────────────────────────────────────

    def _is_distracted(self, face_lm, w, h):
        """
        Returns (distracted, smoothed_pitch, smoothed_gaze, yaw_ratio, cause_str).

        Improvements over v4:
          • Smooth pitch + gaze over SMOOTH_WINDOW frames (eliminates jitter).
          • Skip gaze when eye is closed (eye_span < MIN_EYE_SPAN).
          • Use landmarks 127/356 for yaw (stable ear-side, not jaw-side 234/454).
        """
        try:
            # ── Landmarks ─────────────────────────────────────────────────────
            #  1   nose tip
            #  10  forehead centre (glabella)
            #  152 chin tip
            #  127 left ear-side (stable for yaw width)
            #  356 right ear-side
            #  159 left upper eyelid centre
            #  145 left lower eyelid centre
            #  386 right upper eyelid centre
            #  374 right lower eyelid centre
            #  468 left iris centre  (refine_landmarks=True)
            #  473 right iris centre

            nose      = face_lm[1]
            forehead  = face_lm[10]
            chin      = face_lm[152]
            l_ear     = face_lm[127]   # fixed: was 234 (jaw-side, drifts)
            r_ear     = face_lm[356]   # fixed: was 454
            l_eye_top = face_lm[159]
            l_eye_bot = face_lm[145]
            r_eye_top = face_lm[386]
            r_eye_bot = face_lm[374]
            l_iris    = face_lm[468]
            r_iris    = face_lm[473]

            # ── Head pitch ────────────────────────────────────────────────────
            face_h_v   = chin.y - forehead.y + 1e-6
            mid_y      = (forehead.y + chin.y) / 2.0
            pitch_raw  = (nose.y - mid_y) / face_h_v

            self._pitch_window.append(pitch_raw)
            pitch_s = sum(self._pitch_window) / len(self._pitch_window)
            head_pitched_down = pitch_s > HEAD_PITCH_THRESHOLD

            # ── Gaze down (iris within eye opening) ───────────────────────────
            def eye_gaze(top_lm, bot_lm, iris_lm):
                eye_span = bot_lm.y - top_lm.y + 1e-6
                if eye_span < MIN_EYE_SPAN:
                    return 0.5   # blink / squint — treat as neutral
                return (iris_lm.y - top_lm.y) / eye_span

            lg = eye_gaze(l_eye_top, l_eye_bot, l_iris)
            rg = eye_gaze(r_eye_top, r_eye_bot, r_iris)
            gaze_raw = (lg + rg) / 2.0

            self._gaze_window.append(gaze_raw)
            gaze_s    = sum(self._gaze_window) / len(self._gaze_window)
            gaze_down = gaze_s > GAZE_DOWN_THRESHOLD

            # ── Head yaw ─────────────────────────────────────────────────────
            face_w     = r_ear.x - l_ear.x + 1e-6
            yaw_ratio  = (nose.x - l_ear.x) / face_w
            yaw_extreme = (yaw_ratio < YAW_THRESHOLD_LO or yaw_ratio > YAW_THRESHOLD_HI)

            if yaw_extreme:
                self._yaw_sustained += 1
            else:
                self._yaw_sustained = max(0, self._yaw_sustained - 1)

            yaw_distracted = self._yaw_sustained >= YAW_SUSTAIN_FRAMES

            # ── Face exit (completely turned away from camera) ────────────────
            if nose.x < 0.04 or nose.x > 0.96:
                return False, pitch_s, gaze_s, yaw_ratio, "none"

            # ── Determine cause ───────────────────────────────────────────────
            gaze_distracted = head_pitched_down and gaze_down
            cause = "none"
            if gaze_distracted:
                cause = "gaze_pitch"
            elif yaw_distracted:
                cause = "head_yaw"

            return (gaze_distracted or yaw_distracted), pitch_s, gaze_s, yaw_ratio, cause

        except Exception:
            return False, 0.0, 0.5, 0.5, "error"

    def _check_dismissal(self, face_lm, hand_result, w, h) -> bool:
        """Dismissal: ≥2 hands detected + both wrists above nose + nose centred."""
        try:
            nose_y = face_lm[1].y
            nose_x = face_lm[1].x
            if nose_x < 0.25 or nose_x > 0.75:
                return False
            if (not hand_result.multi_hand_landmarks
                    or len(hand_result.multi_hand_landmarks) < 2):
                return False
            for hand_lm in hand_result.multi_hand_landmarks:
                if hand_lm.landmark[0].y >= nose_y:
                    return False
            return True
        except (IndexError, AttributeError):
            return False

    # ── Scoring ────────────────────────────────────────────────────────────────

    def _compute_score_and_logs(self):
        if self._session_start is None:
            return 100, []
        total = time.monotonic() - self._session_start
        if total < 1:
            return 100, []
        now  = time.monotonic()
        dist = self._distraction_secs
        nf   = self._no_face_secs
        if self._distraction_start is not None:
            dist += now - self._distraction_start
        if self._no_face_event_start is not None:
            nf   += now - self._no_face_event_start
        bad   = dist + nf
        score = max(0, round((1.0 - bad / total) * 100))
        return score, list(self._logs)

    def close(self):
        self._face_mesh.close()
        self._hands.close()


# ── Main loop ──────────────────────────────────────────────────────────────────

def main():
    monitor = FaceMonitor()
    cap     = None

    def open_camera():
        nonlocal cap
        if cap is not None:
            cap.release()
            time.sleep(0.2)
        for idx in range(3):
            c = cv2.VideoCapture(idx)
            if c.isOpened():
                c.set(cv2.CAP_PROP_FRAME_WIDTH,  640)
                c.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap = c
                log(f"Camera opened (index {idx}).")
                return True
        return False

    if not open_camera():
        emit({"event": "ERROR", "msg": "No camera found."})
        sys.exit(1)

    emit({"event": "READY"})

    def read_stdin():
        for raw in sys.stdin:
            raw = raw.strip()
            if not raw:
                continue
            try:
                msg = json.loads(raw)
                cmd = msg.get("cmd", "")
                if   cmd == "ARM":
                    reconnect = getattr(monitor, '_force_camera_reconnect', False)
                    if reconnect:
                        log("Reconnecting camera on ARM…")
                        if not open_camera():
                            emit({"event": "ERROR", "msg": "Camera reconnect failed."})
                            continue
                    monitor.arm()
                elif cmd == "DISARM": monitor.disarm()
                elif cmd == "QUIT":
                    log("Quit received.")
                    monitor.close()
                    if cap:
                        cap.release()
                    import os; os._exit(0)
            except Exception:
                emit({"event": "ERROR", "msg": f"Bad stdin: {raw}"})
        log("Stdin closed.")
        import os; os._exit(0)

    threading.Thread(target=read_stdin, daemon=True).start()

    while True:
        try:
            ret, frame = cap.read()
            if not ret:
                log("Camera read failed — retrying…")
                cap.release()
                time.sleep(0.5)
                if not open_camera():
                    time.sleep(3.0)
                continue

            frame_out = monitor.process_frame(frame)

            small = cv2.resize(frame_out, (320, 240))
            ok, buf = cv2.imencode('.jpg', small,
                                   [int(cv2.IMWRITE_JPEG_QUALITY), 45])
            if ok:
                emit({"event": "FRAME",
                      "b64": base64.b64encode(buf).decode('utf-8')})

            time.sleep(SCAN_INTERVAL_SEC)

        except KeyboardInterrupt:
            break
        except Exception:
            emit({"event": "ERROR", "msg": traceback.format_exc()})
            time.sleep(1.0)

    monitor.close()
    if cap:
        cap.release()


if __name__ == "__main__":
    main()

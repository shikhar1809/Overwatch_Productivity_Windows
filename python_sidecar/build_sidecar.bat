@echo off
REM ══════════════════════════════════════════════════════════════════
REM  FocusOS — Build Sidecar  (v5)
REM  Packages detector.py + MediaPipe + YOLO into a standalone .exe
REM  Run from inside python_sidecar\ directory
REM ══════════════════════════════════════════════════════════════════

echo.
echo [FocusOS] Installing / upgrading dependencies...
pip install -r requirements.txt --upgrade --quiet
pip install pyinstaller --upgrade --quiet

echo.
echo [FocusOS] Downloading YOLOv8n weights (if not already cached)...
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt')"

echo.
echo [FocusOS] Building detector.exe...
pyinstaller ^
  --onefile ^
  --collect-datas mediapipe ^
  --collect-datas ultralytics ^
  --copy-metadata ultralytics ^
  --hidden-import=ultralytics ^
  --hidden-import=ultralytics.models ^
  --hidden-import=ultralytics.models.yolo ^
  --hidden-import=cv2 ^
  --hidden-import=numpy ^
  --name detector ^
  --distpath "%USERPROFILE%\Documents\FocusOS\sidecar" ^
  detector.py

echo.
echo [FocusOS] Copying YOLOv8n weights next to the exe...
copy /Y "%USERPROFILE%\.cache\Ultralytics\assets\yolov8n.pt" ^
     "%USERPROFILE%\Documents\FocusOS\sidecar\yolov8n.pt" 2>nul || (
  REM fallback — look in current directory
  if exist yolov8n.pt (
    copy /Y yolov8n.pt "%USERPROFILE%\Documents\FocusOS\sidecar\yolov8n.pt"
  )
)

echo.
echo [FocusOS] ✓ Build complete!
echo   Exe  : %USERPROFILE%\Documents\FocusOS\sidecar\detector.exe
echo   Model: %USERPROFILE%\Documents\FocusOS\sidecar\yolov8n.pt
echo.
pause

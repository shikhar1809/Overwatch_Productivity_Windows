@echo off
REM Build the FocusOS phone detection sidecar into a standalone .exe
REM Requires: pip install pyinstaller mediapipe opencv-python

echo [FocusOS] Installing dependencies...
pip install -r requirements.txt
pip install pyinstaller

echo [FocusOS] Building detector.exe...
pyinstaller ^
  --onefile ^
  --collect-datas mediapipe ^
  --name detector ^
  --distpath "%USERPROFILE%\Documents\FocusOS\sidecar" ^
  detector.py

echo.
echo [FocusOS] Build complete!
echo Output: %USERPROFILE%\Documents\FocusOS\sidecar\detector.exe

@echo off
REM Opens this project in the Godot editor. Adjust GODOT if your install path changes.
set "GODOT=C:\Godot\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot not found at: %GODOT%
  echo Edit launch-editor.bat and set GODOT to your Godot executable.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0"

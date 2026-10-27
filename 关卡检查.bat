@echo off
rem ============================================================
rem  Ice Tower Jump - Level Reachability Check
rem  (Bing Ta Tiao Yue - level check)
rem
rem  This is the most useful tool in this project.
rem  Platformers rarely crash. They just become IMPOSSIBLE to finish,
rem  and the editor never warns you about that. This script takes the
rem  player's REAL jump physics and verifies that every level can be
rem  walked from the spawn point to the finish flag. It also checks
rem  that no flame sits on walkable ground, and that every door has a button.
rem
rem  Run this after changing ANY level.
rem ============================================================

setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

rem --- locate the Godot executable ---
rem handles both extraction styles: exe directly in ..\Godot\,
rem or the whole folder renamed to the exe name, with the real exe inside.
set "GODOT="
for %%F in ("%~dp0..\Godot\Godot_v*_win64.exe") do (
  set "ATTR=%%~aF"
  if "!ATTR:~0,1!" neq "d" set "GODOT=%%~fF"
)
if not defined GODOT (
  for /d %%D in ("%~dp0..\Godot\*") do (
    for %%F in ("%%~fD\Godot_v*_win64.exe") do (
      set "ATTR=%%~aF"
      if "!ATTR:~0,1!" neq "d" set "GODOT=%%~fF"
    )
  )
)

if not defined GODOT (
  echo [x] Godot exe not found. Put it in: %~dp0..\Godot\
  pause
  exit /b 1
)

echo Engine: %GODOT%
echo Project: %PROJECT_DIR%
echo.
"%GODOT%" --headless --path "%PROJECT_DIR%" res://scenes/verify_levels.tscn
set "CODE=%ERRORLEVEL%"
echo.
if "%CODE%"=="0" (echo [OK] All levels are reachable.) else (echo [FAIL] Some level is impossible to finish.)
pause
exit /b %CODE%
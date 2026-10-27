@echo off
rem ============================================================
rem  Ice Tower Jump - Project Self Check
rem
rem  Loads every .gd script and every .tscn scene, then verifies the
rem  input map, the autoload singletons and the main scene.
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
"%GODOT%" --headless --path "%PROJECT_DIR%" --quit res://scenes/check.tscn
set "CODE=%ERRORLEVEL%"
echo.
if "%CODE%"=="0" (echo [OK] Self check passed.) else (echo [FAIL] Self check failed.)
pause
exit /b %CODE%
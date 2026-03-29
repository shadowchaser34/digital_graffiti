@echo off
setlocal
cd /d "%~dp0.."
set "PY_EXE="
set "VENV_PY=%~dp0..\.venv\Scripts\python.exe"

if exist "%VENV_PY%" (
    set "PY_EXE=%VENV_PY%"
	goto :run_dashboard
)

where py >nul 2>nul
if not errorlevel 1 (
	set "PY_EXE=py -3"
)

if not defined PY_EXE (
	for /f "delims=" %%I in ('where python 2^>nul ^| findstr /V /I "WindowsApps"') do (
		set "PY_EXE=%%I"
		goto :run_dashboard
	)
)

if not defined PY_EXE (
	echo Python was not found on PATH.
	echo Install Python 3.10+ from python.org and make sure the real interpreter is on PATH.
	exit /b 1
)

:run_dashboard
%PY_EXE% -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
endlocal

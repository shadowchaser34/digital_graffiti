from __future__ import annotations

import json
import os
import re
import subprocess
import threading
from shutil import which
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel


APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parent
FLUTTER_EXE = which("flutter") or r"C:\flutter\bin\flutter.bat"


class LaunchRequest(BaseModel):
    device_id: str


class EmulatorLaunchRequest(BaseModel):
    emulator_id: str


class ProcessState:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._process: subprocess.Popen[str] | None = None
        self._device_id: str | None = None
        self._command: list[str] | None = None

    def current(self) -> dict[str, Any]:
        with self._lock:
            running = self._process is not None and self._process.poll() is None
            pid = self._process.pid if running and self._process else None
            return {
                "running": running,
                "pid": pid,
                "device_id": self._device_id,
                "command": self._command,
            }

    def start(self, process: subprocess.Popen[str], device_id: str, command: list[str]) -> None:
        with self._lock:
            self._process = process
            self._device_id = device_id
            self._command = command

    def stop(self) -> dict[str, Any]:
        with self._lock:
            process = self._process
            device_id = self._device_id
            command = self._command

        if process is None:
            return {"stopped": False, "reason": "no_process"}

        if process.poll() is not None:
            with self._lock:
                self._process = None
                self._device_id = None
                self._command = None
            return {"stopped": False, "reason": "already_exited", "returncode": process.returncode}

        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(process.pid)], check=False)
        else:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()

        with self._lock:
            self._process = None
            self._device_id = None
            self._command = None

        return {"stopped": True, "device_id": device_id, "command": command, "pid": process.pid}


state = ProcessState()
app = FastAPI(title="Digital Graffiti Wall Dashboard", version="0.1.0")


def _run_flutter(args: list[str]) -> str:
    command = [FLUTTER_EXE, *args]
    result = subprocess.run(
        command,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    output = (result.stdout or "").strip()
    error_output = (result.stderr or "").strip()

    if result.returncode != 0:
        raise HTTPException(
            status_code=500,
            detail={
                "command": command,
                "stdout": output,
                "stderr": error_output,
            },
        )

    return output


def _run_flutter_json(args: list[str]) -> Any:
    output = _run_flutter(args)
    if not output:
        return []

    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Flutter command did not return JSON",
                "error": str(exc),
                "output": output,
            },
        ) from exc


def _run_flutter_text(args: list[str]) -> str:
    return _run_flutter(args)


def _normalize_device(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": item.get("id") or item.get("deviceId") or item.get("emulatorId"),
        "name": item.get("name"),
        "category": item.get("category"),
        "platform": item.get("platform"),
        "targetPlatform": item.get("targetPlatform"),
        "emulator": item.get("emulator"),
        "isSupported": item.get("isSupported"),
        "emulatorId": item.get("emulatorId"),
        "ephemeral": item.get("ephemeral"),
    }


def _normalize_emulator(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": item.get("id"),
        "name": item.get("name"),
        "manufacturer": item.get("manufacturer"),
        "platformType": item.get("platformType"),
        "category": item.get("category"),
        "isRunning": item.get("isRunning"),
        "deviceId": item.get("deviceId"),
    }


@app.get("/", response_class=HTMLResponse)
def dashboard() -> str:
    return DASHBOARD_HTML


@app.get("/api/devices")
def list_devices() -> dict[str, Any]:
    data = _run_flutter_json(["devices", "--machine"])
    devices = data if isinstance(data, list) else data.get("devices", [])
    return {"devices": [_normalize_device(item) for item in devices]}


@app.get("/api/emulators")
def list_emulators() -> dict[str, Any]:
    emulators_output = _run_flutter_text(["emulators"])
    devices_output = _run_flutter_json(["devices", "--machine"])
    devices = devices_output if isinstance(devices_output, list) else devices_output.get("devices", [])
    running_emulator_ids = {
        item.get("emulatorId")
        for item in devices
        if isinstance(item, dict) and item.get("emulator") and item.get("emulatorId")
    }

    emulators: list[dict[str, Any]] = []
    for line in emulators_output.splitlines():
      if "Android Studio" in line or "flutter emulators" in line.lower():
        continue
      parts = [part.strip() for part in re.split(r"\s*(?:•|â€¢)\s*", line) if part.strip()]
      if len(parts) < 4 or parts[0].lower() == "id":
        continue
      emulator_id, name, manufacturer, platform = parts[:4]
      emulators.append(
        {
          "id": emulator_id,
          "name": name,
          "manufacturer": manufacturer,
          "platformType": platform,
          "category": "android",
          "isRunning": emulator_id in running_emulator_ids,
          "deviceId": emulator_id if emulator_id in running_emulator_ids else None,
        }
      )

    return {"emulators": [_normalize_emulator(item) for item in emulators]}


@app.post("/api/emulators/start")
def start_emulator(request: EmulatorLaunchRequest) -> dict[str, Any]:
    output = _run_flutter(["emulators", "--launch", request.emulator_id])
    return {"started": True, "emulator_id": request.emulator_id, "output": output}


@app.get("/api/state")
def get_state() -> dict[str, Any]:
    return state.current()


@app.post("/api/launch")
def launch_app(request: LaunchRequest) -> dict[str, Any]:
    current = state.current()
    if current["running"]:
        raise HTTPException(status_code=409, detail="A Flutter run process is already active. Stop it first.")

    command = ["flutter", "run", "-d", request.device_id]
    popen_kwargs: dict[str, Any] = {
        "cwd": REPO_ROOT,
        "stdout": None,
        "stderr": None,
        "text": True,
    }
    if os.name == "nt":
        popen_kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        popen_kwargs["start_new_session"] = True

    process = subprocess.Popen(command, **popen_kwargs)
    state.start(process, request.device_id, command)
    return {"started": True, "device_id": request.device_id, "pid": process.pid}


@app.post("/api/stop")
def stop_launch() -> dict[str, Any]:
    return state.stop()


DASHBOARD_HTML = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Digital Graffiti Wall Launcher</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0f1115;
      --panel: #171b22;
      --panel-soft: #1e2430;
      --text: #f2f5fa;
      --muted: #98a2b3;
      --accent: #4dd4ac;
      --accent-strong: #25b18d;
      --danger: #ff6b6b;
      --border: rgba(255, 255, 255, 0.08);
    }
    body {
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background: radial-gradient(circle at top, #1b2330 0, var(--bg) 45%);
      color: var(--text);
    }
    .wrap {
      max-width: 1100px;
      margin: 0 auto;
      padding: 24px;
    }
    .hero {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      padding: 20px;
      border: 1px solid var(--border);
      border-radius: 18px;
      background: linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.02));
      box-shadow: 0 16px 40px rgba(0, 0, 0, 0.28);
    }
    h1 { margin: 0 0 8px; font-size: 30px; }
    p { margin: 0; color: var(--muted); line-height: 1.5; }
    .actions {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 16px;
    }
    button {
      border: 0;
      border-radius: 999px;
      padding: 10px 14px;
      font-weight: 700;
      cursor: pointer;
    }
    .primary { background: var(--accent); color: #04110c; }
    .primary:hover { background: var(--accent-strong); }
    .ghost { background: var(--panel-soft); color: var(--text); border: 1px solid var(--border); }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
      margin-top: 18px;
    }
    .card {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 16px;
    }
    .card h2 {
      margin: 0 0 10px;
      font-size: 18px;
    }
    .item {
      padding: 12px 0;
      border-top: 1px solid var(--border);
    }
    .item:first-child { border-top: 0; }
    .row {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      align-items: center;
    }
    .muted { color: var(--muted); font-size: 13px; }
    .badge {
      display: inline-block;
      margin-left: 8px;
      padding: 3px 8px;
      border-radius: 999px;
      font-size: 12px;
      background: rgba(77, 212, 172, 0.12);
      color: var(--accent);
    }
    .status {
      margin-top: 16px;
      padding: 12px 14px;
      border: 1px solid var(--border);
      border-radius: 14px;
      background: rgba(255, 255, 255, 0.03);
      color: var(--muted);
      white-space: pre-wrap;
    }
    .danger { background: rgba(255, 107, 107, 0.12); color: #ffb3b3; }
    @media (max-width: 720px) {
      .hero { flex-direction: column; }
      .row { align-items: flex-start; flex-direction: column; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <section class="hero">
      <div>
        <h1>Digital Graffiti Wall Launcher</h1>
        <p>Use this dashboard to discover Flutter targets and start the app on a connected Android device or emulator.</p>
        <div class="actions">
          <button class="primary" onclick="refreshAll()">Refresh targets</button>
          <button class="ghost" onclick="refreshState()">Refresh run state</button>
          <button class="ghost" onclick="launchFirstMobile()">Run on mobile</button>
          <button class="ghost" onclick="launchFirstEmulator()">Run on emulator</button>
          <button class="ghost danger" onclick="stopLaunch()">Stop last launch</button>
        </div>
      </div>
      <div class="muted">Repo root is resolved automatically. Flutter must be on PATH.</div>
    </section>

    <div class="grid">
      <section class="card">
        <h2>Devices</h2>
        <div id="devices">Loading...</div>
      </section>
      <section class="card">
        <h2>Emulators</h2>
        <div id="emulators">Loading...</div>
      </section>
      <section class="card">
        <h2>Run state</h2>
        <div id="state">Loading...</div>
      </section>
    </div>

    <div id="message" class="status">Ready.</div>
  </div>

  <script>
    const messageBox = document.getElementById('message');

    function setMessage(text) {
      messageBox.textContent = text;
    }

    async function fetchJson(url, options) {
      const response = await fetch(url, options || {});
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(typeof payload.detail === 'string' ? payload.detail : JSON.stringify(payload.detail || payload));
      }
      return payload;
    }

    function renderItems(target, items, emptyText, isEmulator) {
      if (!items.length) {
        target.innerHTML = '<div class="muted">' + emptyText + '</div>';
        return;
      }

      target.innerHTML = items.map((item) => {
        const launchId = item.deviceId || item.id;
        const deviceButton = !isEmulator && launchId
          ? '<button class="primary" onclick=\'launchApp(' + JSON.stringify(String(launchId)) + ')\'>Launch</button>'
          : '';
        const emulatorButton = isEmulator
          ? (item.isRunning && item.deviceId
              ? '<button class="primary" onclick=\'launchApp(' + JSON.stringify(String(item.deviceId)) + ')\'>Launch app</button>'
              : '<button class="primary" onclick=\'startEmulator(' + JSON.stringify(String(item.id)) + ')\'>Start emulator</button>')
          : '';
        const status = isEmulator
          ? (item.isRunning ? '<span class="badge">running</span>' : '<span class="badge">not running</span>')
          : '';
        const targetId = item.deviceId || item.id || 'missing id';

        return [
          '<div class="item">',
          '<div class="row">',
          '<div>',
          '<strong>' + (item.name || 'Unnamed') + '</strong>' + status,
          '<div class="muted">' + targetId + '</div>',
          isEmulator ? '<div class="muted">Flutter device target: ' + (item.deviceId || 'not available until the emulator is running') + '</div>' : '',
          '<div class="muted">' + [item.platform, item.category, item.targetPlatform].filter(Boolean).join(' | ') + '</div>',
          '</div>',
          deviceButton || emulatorButton ? '<div>' + (deviceButton || emulatorButton) + '</div>' : '',
          '</div>',
          '</div>'
        ].join('');
      }).join('');
    }

    async function refreshDevices() {
      const payload = await fetchJson('/api/devices');
      renderItems(document.getElementById('devices'), payload.devices || [], 'No Flutter devices found.', false);
      return payload.devices || [];
    }

    async function refreshEmulators() {
      const payload = await fetchJson('/api/emulators');
      renderItems(document.getElementById('emulators'), payload.emulators || [], 'No Flutter emulators found.', true);
      return payload.emulators || [];
    }

    async function refreshState() {
      const payload = await fetchJson('/api/state');
      document.getElementById('state').innerHTML = [
        '<div><strong>Running:</strong> ' + payload.running + '</div>',
        '<div><strong>PID:</strong> ' + (payload.pid || 'none') + '</div>',
        '<div><strong>Device:</strong> ' + (payload.device_id || 'none') + '</div>',
        '<div class="muted" style="margin-top: 8px; word-break: break-all;">' + ((payload.command || []).join(' ') || 'No active Flutter run process.') + '</div>'
      ].join('');
    }

    async function refreshAll() {
      setMessage('Refreshing targets...');
      const results = await Promise.allSettled([refreshDevices(), refreshEmulators(), refreshState()]);
      const failures = results.filter((result) => result.status === 'rejected');
      if (failures.length) {
        setMessage('Refresh completed with ' + failures.length + ' error(s).');
      } else {
        setMessage('Targets refreshed.');
      }
    }

    async function launchFirstMobile() {
      try {
        setMessage('Looking for a mobile device...');
        const devices = await refreshDevices();
        const mobile = devices.find((device) => device.targetPlatform === 'android-arm64' && !device.emulator);
        if (!mobile) {
          setMessage('No connected mobile device found.');
          return;
        }
        await launchApp(mobile.id);
      } catch (error) {
        setMessage('Mobile launch failed: ' + error.message);
      }
    }

    async function launchFirstEmulator() {
      try {
        setMessage('Looking for an emulator...');
        const emulators = await refreshEmulators();
        const emulator = emulators.find((item) => item.id);
        if (!emulator) {
          setMessage('No emulator found. Start one first.');
          return;
        }
        if (!emulator.isRunning) {
          await startEmulator(emulator.id);
        }
        const refreshedEmulators = await refreshEmulators();
        const runningEmulator = refreshedEmulators.find((item) => item.id === emulator.id);
        await launchApp((runningEmulator && runningEmulator.deviceId) || emulator.id);
      } catch (error) {
        setMessage('Emulator launch failed: ' + error.message);
      }
    }

    async function launchApp(deviceId) {
      try {
        setMessage('Launching on ' + deviceId + '...');
        await fetchJson('/api/launch', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ device_id: deviceId })
        });
        setMessage('Launch started on ' + deviceId + '.');
        await refreshState();
      } catch (error) {
        setMessage('Launch failed: ' + error.message);
      }
    }

    async function startEmulator(emulatorId) {
      try {
        setMessage('Starting emulator ' + emulatorId + '...');
        await fetchJson('/api/emulators/start', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ emulator_id: emulatorId })
        });
        setMessage('Emulator start requested for ' + emulatorId + '. Refresh after it boots.');
        await refreshAll();
      } catch (error) {
        setMessage('Emulator start failed: ' + error.message);
      }
    }

    async function stopLaunch() {
      try {
        setMessage('Stopping last launch...');
        const payload = await fetchJson('/api/stop', { method: 'POST' });
        setMessage(payload.stopped ? 'Stopped the last Flutter run process.' : 'Nothing active to stop.');
        await refreshState();
      } catch (error) {
        setMessage('Stop failed: ' + error.message);
      }
    }

    refreshAll();
  </script>
</body>
</html>
"""

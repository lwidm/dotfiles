#!/usr/bin/env python3
# Emits JSON: { "MONITOR-NAME": [ {name,id,num,class,active}, ... ], ... }
# Uses hyprctl -j monitors to determine which workspace is active on each monitor.

import json
import os
import sys
import glob
import subprocess
import socket
import time
import re

XDG = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
HIS = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", None)

def find_socket2():
    if HIS:
        p = os.path.join(XDG, "hypr", HIS, ".socket2.sock")
        if os.path.exists(p):
            return p
    candidates = glob.glob(os.path.join(XDG, "hypr", "*", ".socket2.sock"))
    return candidates[0] if candidates else None

def run_json(cmd):
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        return json.loads(out)
    except Exception:
        return None

def hyprctl_workspaces_json():
    return run_json(["hyprctl", "-j", "workspaces"])

def hyprctl_monitors_json():
    return run_json(["hyprctl", "-j", "monitors"])

def build_active_map_from_monitors():
    """
    Return { monitor_name: active_workspace_id_or_name_or_None }
    Be defensive: hyprctl monitors JSON may represent the active workspace in different shapes.
    """
    mons = hyprctl_monitors_json()
    if not mons:
        return {}
    amap = {}
    for m in mons:
        # try several likely keys for monitor name
        mname = m.get("name") or m.get("monitor") or m.get("id")
        active = None
        # common possible keys to look for; content might be int or object
        for k in ("activeWorkspace", "activeworkspace", "active_workspace", "active"):
            if k in m:
                active = m[k]
                break
        # if the monitor object has an "workspaces" entry we might infer the active one from it
        # (rare), otherwise leave None
        if isinstance(active, dict):
            # object -> try id or name
            a_id = active.get("id") or active.get("workspace") or active.get("name")
        elif isinstance(active, (int, str)):
            a_id = active
        else:
            a_id = None

        # normalize simple numeric strings to int
        if isinstance(a_id, str) and a_id.isdigit():
            try:
                a_id = int(a_id)
            except Exception:
                pass

        amap[str(mname)] = a_id
    return amap

def extract_num(name, wid):
    if not name:
        return str(wid) if wid is not None else ""
    m = re.match(r'^\s*(\d+)', str(name))
    if m:
        return m.group(1)
    if isinstance(wid, int):
        return str(wid)
    return str(name)

def build_monitor_map(ws_list):
    """
    Given hyprctl -j workspaces (list), return map:
      { "MON": [ {name,id,num,class,active}, ... ] }
    Uses monitors->active map to set the class/active flag.
    Workspaces are sorted by ascending id.
    """
    monitors = {}
    active_map = build_active_map_from_monitors()

    for w in ws_list:
        name = str(w.get("name", ""))               # e.g. "1" or "1:term"
        wid = w.get("id", None)                     # typically an int
        monitor = w.get("monitor", w.get("monitorName", "unknown"))
        num = extract_num(name, wid)

        # determine if this workspace is the active one for this monitor
        is_active = False
        if monitor is not None:
            am = active_map.get(str(monitor))
            if am is not None:
                # compare ints when possible
                try:
                    if isinstance(am, str) and am.isdigit():
                        am_val = int(am)
                    else:
                        am_val = am
                except Exception:
                    am_val = am
                if isinstance(am_val, int) and isinstance(wid, int):
                    is_active = (am_val == wid)
                else:
                    # fallback: compare string forms (name/id)
                    is_active = (str(am_val) == str(wid) or str(am_val) == str(name) or str(am_val) == str(num))

        cls = "active" if is_active else "inactive"
        obj = {
            "name": name,
            "id": wid,
            "num": num,
            "class": cls,
            "active": bool(is_active)
        }
        monitors.setdefault(monitor, []).append(obj)

    # Sort each monitor's workspace list by ascending id
    for mon in monitors:
        monitors[mon].sort(key=lambda ws: ws["id"] if ws["id"] is not None else float("inf"))

    return monitors

def print_json(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":"), ensure_ascii=False) + "\n")
    sys.stdout.flush()

def socket2_listener(sockpath):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sockpath)
        f = s.makefile("r", encoding="utf-8", newline="\n")
    except Exception:
        return False

    ws = hyprctl_workspaces_json()
    if ws:
        print_json(build_monitor_map(ws))

    for line in f:
        line = line.strip()
        if not line:
            continue
        ev = line.split(">>", 1)
        if not ev:
            continue
        name = ev[0]
        if name in ("workspace", "workspacev2", "focusedmon", "monitor", "activeworkspace"):
            ws = hyprctl_workspaces_json()
            if ws:
                print_json(build_monitor_map(ws))
    return True

def polling_loop(interval=1.0):
    last = None
    while True:
        ws = hyprctl_workspaces_json()
        if ws is not None:
            cur = build_monitor_map(ws)
            if cur != last:
                print_json(cur)
                last = cur
        time.sleep(interval)

def main():
    sock2 = find_socket2()
    if sock2:
        ok = socket2_listener(sock2)
        if ok:
            return
    polling_loop()

if __name__ == "__main__":
    main()

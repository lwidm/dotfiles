#!/usr/bin/env python3
import json
import subprocess

def get_monitors():
    try:
        out = subprocess.check_output(["hyprctl", "-j", "monitors"], encoding="utf-8")
        monitors = json.loads(out)
        # return list of monitor names
        return [m["name"] for m in monitors if "name" in m]
    except Exception:
        return []

if __name__ == "__main__":
    print(json.dumps(get_monitors()))

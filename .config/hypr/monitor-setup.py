#!/usr/bin/env python3
"""
Auto-detect monitors and configure Hyprland + EWW bars.

Identifies connected monitors by description/model, applies known layouts
for recognized combinations, and falls back to auto-placement for unknown
configurations. Generates dynamic EWW bar definitions.

Usage:
  monitor-setup.py              # One-shot: detect, configure, generate eww bars
  monitor-setup.py --daemon     # One-shot + listen for hotplug events
  monitor-setup.py --eww-only   # Only regenerate dynamic_bars.yuck + restart eww
  monitor-setup.py --dry-run    # Print what would be done without executing
  monitor-setup.py --dump-monitors  # Print detected monitor info as JSON
"""

import argparse
import glob
import json
import os
import re
import socket
import subprocess
import sys
import time
from dataclasses import dataclass


# ---------------------------------------------------------------------------
# Known Monitor Database
# ---------------------------------------------------------------------------

@dataclass
class MonitorProfile:
    """Settings for a single known monitor model."""
    match_description: str  # substring to match in hyprctl "description" field
    resolution: str         # e.g. "2560x1440@59.95"
    scale: float = 1.0
    transform: int = 0      # 0=none, 1=90, 2=180, 3=270
    disable: bool = False
    is_builtin: bool = False  # True for eDP-* built-in panels


KNOWN_MONITORS: dict[str, MonitorProfile] = {
    "dell_u2724d": MonitorProfile(
        match_description="DELL U2724D",
        resolution="2560x1440@59.95",
        scale=1.0,
    ),
    "dell_u2723qe": MonitorProfile(
        match_description="DELL U2723QE",
        resolution="3840x2160@60",
        scale=1.6,
    ),
    "dell_s2719dgf": MonitorProfile(
        match_description="DELL S2719DGF",
        resolution="2560x1440@60",
        scale=1.0,
        transform=3,  # 270 degrees
    ),
    "pikvm": MonitorProfile(
        # TODO : Adjust this string after checking `hyprctl -j monitors` with PiKVM connected
        match_description="PiKVM",
        resolution="1920x1080@60",
    ),
    "dummy_bbc": MonitorProfile(
        match_description="BBC",
        resolution="",
        disable=True,
    ),
    "laptop_edp": MonitorProfile(
        match_description="__eDP__",  # sentinel; matched via special case
        resolution="2880x1800@120",
        scale=2.0,
        is_builtin=True,
    ),
    "thinkvision_m14t": MonitorProfile(
        # Adjust after checking actual description string
        match_description="M14t",
        resolution="1920x1080@60",
    ),
    "ucsb_hdmi": MonitorProfile(
        match_description="Dell Inc. DELL P2412H KG49T2A734FU",
        resolution="1920x1080@60",
    ),
}


# ---------------------------------------------------------------------------
# Known Layouts Database
# ---------------------------------------------------------------------------

@dataclass
class MonitorPlacement:
    """Position for one monitor within a layout."""
    profile_key: str
    position: str  # e.g. "2560x560"


@dataclass
class KnownLayout:
    """A recognized combination of monitors with exact positions."""
    name: str
    required: frozenset[str]  # set of profile_keys that must ALL be present
    placements: dict[str, MonitorPlacement]  # profile_key -> placement
    primary_key: str  # which profile_key is primary


KNOWN_LAYOUTS: list[KnownLayout] = [
    # Desktop: triple monitors + PiKVM (most specific first)
    KnownLayout(
        name="desktop_triple_pikvm",
        required=frozenset({"dell_u2724d", "dell_u2723qe", "dell_s2719dgf", "pikvm"}),
        placements={
            "dell_u2724d":   MonitorPlacement("dell_u2724d",   "0x560"),
            "dell_u2723qe":  MonitorPlacement("dell_u2723qe",  "2560x560"),
            "dell_s2719dgf": MonitorPlacement("dell_s2719dgf", "4960x0"),
            "pikvm":         MonitorPlacement("pikvm",         "6560x740"),
        },
        primary_key="dell_u2723qe",
    ),
    # Desktop: triple monitors without PiKVM
    KnownLayout(
        name="desktop_triple",
        required=frozenset({"dell_u2724d", "dell_u2723qe", "dell_s2719dgf"}),
        placements={
            "dell_u2724d":   MonitorPlacement("dell_u2724d",   "0x560"),
            "dell_u2723qe":  MonitorPlacement("dell_u2723qe",  "2560x560"),
            "dell_s2719dgf": MonitorPlacement("dell_s2719dgf", "4960x0"),
        },
        primary_key="dell_u2723qe",
    ),
    # Laptop + UCSB HDMI monitor (external above laptop)
    KnownLayout(
        name="laptop_ucsb",
        required=frozenset({"laptop_edp", "ucsb_hdmi"}),
        placements={
            "laptop_edp": MonitorPlacement("laptop_edp", "0x0"),
            "ucsb_hdmi":  MonitorPlacement("ucsb_hdmi",  "-240x-1080"),
        },
        primary_key="laptop_edp",
    ),
    # Laptop + ThinkVision M14t (M14t on the left)
    KnownLayout(
        name="laptop_thinkvision",
        required=frozenset({"laptop_edp", "thinkvision_m14t"}),
        placements={
            "laptop_edp":       MonitorPlacement("laptop_edp",       "1920x90"),
            "thinkvision_m14t": MonitorPlacement("thinkvision_m14t", "0x0"),
        },
        primary_key="laptop_edp",
    ),
    # Laptop alone
    KnownLayout(
        name="laptop_alone",
        required=frozenset({"laptop_edp"}),
        placements={
            "laptop_edp": MonitorPlacement("laptop_edp", "0x0"),
        },
        primary_key="laptop_edp",
    ),
]

# Sorted by number of required monitors descending (most specific first)
KNOWN_LAYOUTS.sort(key=lambda l: len(l.required), reverse=True)


# ---------------------------------------------------------------------------
# Monitor Detection
# ---------------------------------------------------------------------------

DRY_RUN: bool = False


def run_cmd(cmd: list[str]) -> subprocess.CompletedProcess:
    """Run a command, or just print it in dry-run mode."""
    if DRY_RUN:
        print(f"  [dry-run] {' '.join(cmd)}")
        return subprocess.CompletedProcess(cmd, 0, "", "")
    return subprocess.run(cmd, capture_output=True, text=True)


def try_set_xrandr_primary(monitor_name: str):
    """Try to set the X primary output via xrandr. Warns on failure."""
    try:
        result = run_cmd(["xrandr", "--output", monitor_name, "--primary"])
        if result.returncode != 0:
            print(f"WARNING: xrandr --primary failed for {monitor_name}", file=sys.stderr)
    except FileNotFoundError:
        print("WARNING: xrandr not found, skipping primary output setting", file=sys.stderr)


def hyprctl_keyword_monitor(value: str):
    """Apply a hyprctl keyword monitor command."""
    run_cmd(["hyprctl", "keyword", "monitor", value])


def get_connected_monitors() -> list[dict]:
    """Return list of monitor dicts from hyprctl -j monitors."""
    for attempt in range(10):
        try:
            out = subprocess.check_output(
                ["hyprctl", "-j", "monitors"], encoding="utf-8", stderr=subprocess.DEVNULL
            )
            return json.loads(out)
        except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError):
            if attempt < 9:
                time.sleep(0.5)
    print("ERROR: Could not query hyprctl monitors after retries", file=sys.stderr)
    return []


def identify_monitor(mon: dict) -> str | None:
    """Match a hyprctl monitor dict to a KNOWN_MONITORS key, or return None."""
    name: str = mon.get("name", "")
    desc: str = mon.get("description", "")
    make: str = mon.get("make", "")
    model: str = mon.get("model", "")
    combined: str = f"{make} {model} {desc}"

    # Special case: eDP-* is always the laptop built-in panel
    if name.startswith("eDP"):
        return "laptop_edp"

    for key, profile in KNOWN_MONITORS.items():
        if profile.is_builtin:
            continue  # handled above
        if profile.match_description is None:
            continue
        if profile.match_description == "":
            continue
        if profile.match_description.lower() in combined.lower():
            return key

    return None


def match_layout(identified_keys: set[str]) -> KnownLayout | None:
    """Find the best matching layout (most-specific-first)."""
    layout: KnownLayout
    for layout in KNOWN_LAYOUTS:
        if layout.required.issubset(identified_keys):
            return layout
    return None


# ---------------------------------------------------------------------------
# Resolution Parsing Helpers
# ---------------------------------------------------------------------------

def parse_resolution(res: str) -> tuple[int, int]:
    """Parse '2560x1440@59.95' into (2560, 1440)."""
    m: re.Match[str] | None = re.match(r"(\d+)x(\d+)", res)
    if m is not None:
        return int(m.group(1)), int(m.group(2))
    return 1920, 1080  # fallback


def logical_width(profile: MonitorProfile) -> int:
    """Get the logical width of a monitor (accounting for scale and rotation)."""
    w: int
    h: int
    w, h = parse_resolution(profile.resolution)
    if profile.transform in (1, 3):  # 90 or 270 rotation
        w, h = h, w
    return int(w / profile.scale)


# ---------------------------------------------------------------------------
# Monitor Configuration
# ---------------------------------------------------------------------------

def apply_monitor_config(monitors: list[dict]) -> None:
    """Main logic: identify monitors, find layout, apply hyprctl commands."""
    if not monitors:
        print("No monitors detected.", file=sys.stderr)
        return

    # Step 1: Identify all connected monitors
    identified: dict[str, str] = {}   # profile_key -> hyprctl name
    unidentified: list[dict] = []     # monitors we don't recognize
    disabled: list[str] = []          # monitors to disable

    mon: dict
    for mon in monitors:
        key: str | None = identify_monitor(mon)
        if key is not None:
            profile: MonitorProfile = KNOWN_MONITORS[key]
            if profile.disable:
                disabled.append(mon["name"])
                continue
            # Handle duplicate models: first one wins, rest are unidentified
            if key in identified:
                print(f"WARNING: Duplicate monitor model '{key}' detected "
                      f"({mon['name']}), treating as unknown", file=sys.stderr)
                unidentified.append(mon)
                continue
            identified[key] = mon["name"]
        else:
            print(f"INFO: Unrecognized monitor: {mon['name']} "
                  f"(desc: {mon.get('description', 'N/A')})", file=sys.stderr)
            unidentified.append(mon)

    # Disable monitors that should be disabled (e.g., dummy)
    for name in disabled:
        print(f"Disabling monitor: {name}")
        hyprctl_keyword_monitor(f"{name},disable")

    # Step 2: Try to match a known layout
    layout: KnownLayout | None = match_layout(set(identified.keys()))

    if layout is not None:
        print(f"Matched layout: {layout.name}")
        _apply_known_layout(layout, identified)
        # Auto-place any extra monitors not in the layout
        if unidentified:
            _auto_place_extra(unidentified, layout, identified)
    else:
        # Full fallback: auto-place everything
        print("Fallback: auto-placement for all monitors")
        _auto_place_all(identified, unidentified)

    # Step 3: Apply system settings based on detected hardware
    apply_system_settings("laptop_edp" in identified)

    # Step 4: Generate and apply EWW bars
    all_names: list[str] = [identified[k] for k in identified]
    all_names += [m["name"] for m in unidentified]
    primary_name: str | None = None
    if layout:
        primary_name = identified.get(layout.primary_key)
    if not primary_name:
        primary_name = identified.get("laptop_edp")
    if not primary_name and all_names:
        primary_name = all_names[0]

    generate_eww_bars(all_names, primary_name)
    restart_eww(all_names)

    # Step 5: Set X primary (for XWayland apps)
    if primary_name:
        try_set_xrandr_primary(primary_name)

    print("Monitor configuration complete.")


def _apply_known_layout(layout: KnownLayout, identified: dict[str, str]) -> None:
    """Apply exact positions from a known layout."""
    profile_key: str
    placement: MonitorPlacement
    for profile_key, placement in layout.placements.items():
        if profile_key not in identified:
            continue
        hypr_name: str = identified[profile_key]
        profile: MonitorProfile = KNOWN_MONITORS[profile_key]
        cmd = f"{hypr_name},{profile.resolution},{placement.position},{profile.scale}"
        if profile.transform:
            cmd += f",transform,{profile.transform}"
        print(f"  {hypr_name}: {profile.resolution} @ {placement.position} "
              f"scale={profile.scale} transform={profile.transform}")
        hyprctl_keyword_monitor(cmd)


def _auto_place_extra(unidentified: list[dict], layout: KnownLayout,
                      identified: dict[str, str]):
    """Auto-place monitors that aren't part of the matched layout."""
    # Find the rightmost edge of the layout
    max_x: int = 0
    profile_key: str
    placement: MonitorPlacement
    for profile_key, placement in layout.placements.items():
        if profile_key not in identified:
            continue
        profile: MonitorProfile = KNOWN_MONITORS[profile_key]
        px: int = int(placement.position.split("x")[0])
        max_x = max(max_x, px + logical_width(profile))

    mon: dict
    for mon in unidentified:
        name: str = mon["name"]
        key: str | None = identify_monitor(mon)
        if key is not None and key in KNOWN_MONITORS:
            profile = KNOWN_MONITORS[key]
            cmd: str = f"{name},{profile.resolution},{max_x}x0,{profile.scale}"
            if profile.transform:
                cmd += f",transform,{profile.transform}"
            hyprctl_keyword_monitor(cmd)
            max_x += logical_width(profile)
        else:
            hyprctl_keyword_monitor(f"{name},preferred,{max_x}x0,1")
            max_x += mon.get("width", 1920)
        print(f"  {name}: auto-placed at {max_x}x0")


def _auto_place_all(identified: dict[str, str], unidentified: list[dict]) -> None:
    """Auto-place all monitors left-to-right."""
    x_offset: int = 0
    pos: str

    profile_key: str
    hypr_name: str
    for profile_key, hypr_name in identified.items():
        profile: MonitorProfile = KNOWN_MONITORS[profile_key]
        pos = f"{x_offset}x0"
        cmd: str = f"{hypr_name},{profile.resolution},{pos},{profile.scale}"
        if profile.transform:
            cmd += f",transform,{profile.transform}"
        print(f"  {hypr_name}: {profile.resolution} @ {pos} scale={profile.scale}")
        hyprctl_keyword_monitor(cmd)
        x_offset += logical_width(profile)

    for mon in unidentified:
        name: str = mon["name"]
        pos = f"{x_offset}x0"
        print(f"  {name}: preferred @ {pos}")
        hyprctl_keyword_monitor(f"{name},preferred,{pos},1")
        x_offset += mon.get("width", 1920)



# ---------------------------------------------------------------------------
# System Settings
# ---------------------------------------------------------------------------

def apply_system_settings(has_laptop_panel: bool) -> None:
    """Apply system-specific non-monitor settings based on detected hardware."""
    if has_laptop_panel:
        print("Detected laptop panel - applying laptop settings")
        run_cmd(["hyprctl", "keyword", "input:kb_options", "caps:swapescape"])
        run_cmd(["hyprctl", "keyword", "input:touchpad:scroll_factor", "0.5"])


# ---------------------------------------------------------------------------
# EWW Bar Generation
# ---------------------------------------------------------------------------

EWW_DIR: str = os.path.expanduser("~/.config/eww")
DYNAMIC_BARS_FILE: str = os.path.join(EWW_DIR, "dynamic_bars.yuck")


def generate_eww_bars(monitor_names: list[str], primary_name: str | None) -> None:
    """Write dynamic_bars.yuck with one defwindow per connected monitor."""
    if not monitor_names:
        return

    windows: list[tuple[str, str]] = []
    for i, mon_name in enumerate(monitor_names):
        is_primary: bool = (mon_name == primary_name)
        bar_id: str = f"bar{i}"

        widget: str
        if is_primary:
            widget = f'(bar_layout_main :monitor "{mon_name}")'
        else:
            widget = f'(bar_layout :monitor "{mon_name}")'

        window_def: str = f"""(defwindow {bar_id}
  :exclusive true
  :monitor "{mon_name}"
  :geometry (geometry
    :x "0px"
    :y "0px"
    :width "100%"
    :height "10px"
    :anchor "bottom center")
  :stacking "fg"
  :windowtype "dock"
  {widget})"""
        windows.append((bar_id, window_def))

    content: str = ";; AUTO-GENERATED by monitor-setup.py -- do not edit manually\n\n"
    content += "\n\n".join(wdef for _, wdef in windows) + "\n"

    if DRY_RUN:
        print(f"\n  [dry-run] Would write {DYNAMIC_BARS_FILE}:")
        for line in content.splitlines():
            print(f"    {line}")
        return

    os.makedirs(os.path.dirname(DYNAMIC_BARS_FILE), exist_ok=True)
    with open(DYNAMIC_BARS_FILE, "w") as f:
        f.write(content)
    print(f"Generated {DYNAMIC_BARS_FILE} with {len(windows)} bar(s)")


def restart_eww(monitor_names: list[str]) -> None:
    """Kill eww, restart daemon, open all generated bar windows."""
    bar_ids: list[str]
    if DRY_RUN:
        bar_ids = [f"bar{i}" for i in range(len(monitor_names))]
        print(f"  [dry-run] Would restart eww and open: {', '.join(bar_ids)}")
        return

    bar_ids = [f"bar{i}" for i in range(len(monitor_names))]

    # Kill existing eww
    subprocess.run(["pkill", "-x", "eww"], capture_output=True)
    time.sleep(0.1)

    # Start daemon
    subprocess.Popen(
        ["setsid", "eww", "daemon"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )

    # Wait for daemon to be ready
    for _ in range(20):
        time.sleep(0.1)
        result = subprocess.run(["pgrep", "-x", "eww"], capture_output=True)
        if result.returncode == 0:
            break

    time.sleep(0.3)  # grace period for daemon initialization

    # Open all bars
    for bar_id in bar_ids:
        subprocess.run(
            ["eww", "open", bar_id],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    print(f"Opened EWW bars: {', '.join(bar_ids)}")


# ---------------------------------------------------------------------------
# Hotplug Daemon
# ---------------------------------------------------------------------------

def find_socket2() -> str | None:
    """Find the Hyprland IPC socket2 path."""
    xdg: str = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    his: str | None = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if his is not None:
        p = os.path.join(xdg, "hypr", his, ".socket2.sock")
        if os.path.exists(p):
            return p
    candidates: list[str] = glob.glob(os.path.join(xdg, "hypr", "*", ".socket2.sock"))
    return candidates[0] if candidates else None


def run_daemon() -> None:
    """Run initial config, then listen for monitor hotplug events."""
    # Initial configuration
    monitors: list[dict] = get_connected_monitors()
    if monitors:
        apply_monitor_config(monitors)

    # Find and connect to IPC socket
    sock_path: str | None = find_socket2()
    if sock_path is None:
        print("WARNING: Could not find Hyprland socket2, falling back to polling",
              file=sys.stderr)
        poll_daemon()
        return

    print(f"Listening for monitor events on {sock_path}")
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        f = s.makefile("r", encoding="utf-8", newline="\n")
    except OSError as e:
        print(f"WARNING: Could not connect to socket: {e}, falling back to polling",
              file=sys.stderr)
        poll_daemon()
        return

    line: str
    for line in f:
        line = line.strip()
        if not line:
            continue
        event: str = line.split(">>", 1)[0]
        if event in ("monitoradded", "monitoraddedv2", "monitorremoved"):
            print(f"Monitor event: {line}")
            time.sleep(0.5)  # debounce - let hardware settle
            monitors = get_connected_monitors()
            if monitors:
                apply_monitor_config(monitors)


def poll_daemon(interval: float = 5.0) -> None:
    """Fallback: poll monitor list periodically."""
    last_names: set[str] = set()
    while True:
        monitors: list[dict] = get_connected_monitors()
        current_names: set[str] = {m["name"] for m in monitors} # type: ignore
        if current_names != last_names:
            apply_monitor_config(monitors)
            last_names = current_names
        time.sleep(interval)


# ---------------------------------------------------------------------------
# Dump Monitors (debugging)
# ---------------------------------------------------------------------------

def dump_monitors() -> None:
    """Print all detected monitor info as formatted JSON."""
    monitors: list[dict] = get_connected_monitors()
    if not monitors:
        print("No monitors detected.")
        return

    mon: dict
    for mon in monitors:
        key = identify_monitor(mon)
        print(f"\n--- {mon.get('name', 'unknown')} ---")
        print(f"  description: {mon.get('description', 'N/A')}")
        print(f"  make:        {mon.get('make', 'N/A')}")
        print(f"  model:       {mon.get('model', 'N/A')}")
        print(f"  serial:      {mon.get('serial', 'N/A')}")
        print(f"  width:       {mon.get('width', 'N/A')}")
        print(f"  height:      {mon.get('height', 'N/A')}")
        print(f"  refreshRate: {mon.get('refreshRate', 'N/A')}")
        print(f"  scale:       {mon.get('scale', 'N/A')}")
        print(f"  transform:   {mon.get('transform', 'N/A')}")
        print(f"  identified:  {key or 'UNKNOWN'}")
        if key:
            profile = KNOWN_MONITORS.get(key)
            if profile:
                print(f"  profile:     {profile.resolution}, scale={profile.scale}, "
                      f"transform={profile.transform}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    global DRY_RUN

    parser = argparse.ArgumentParser(description="Auto-detect and configure Hyprland monitors")
    parser.add_argument("--daemon", action="store_true",
                        help="Run one-shot config then listen for hotplug events")
    parser.add_argument("--eww-only", action="store_true",
                        help="Only regenerate EWW bars (no monitor reconfiguration)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be done without executing")
    parser.add_argument("--dump-monitors", action="store_true",
                        help="Print detected monitor info for debugging")
    args = parser.parse_args()

    DRY_RUN = args.dry_run
    monitors: list[dict]

    if args.dump_monitors:
        dump_monitors()
        return

    if args.eww_only:
        monitors = get_connected_monitors()
        if not monitors:
            print("No monitors detected.", file=sys.stderr)
            sys.exit(1)
        # Determine monitor names and primary
        all_names: list[str] = [m["name"] for m in monitors]
        # Try to identify primary
        identified: dict[str, str] = {}
        for mon in monitors:
            key: str | None = identify_monitor(mon)
            if key is not None:
                identified[key] = mon["name"]
        layout: KnownLayout | None = match_layout(set(identified.keys()))
        primary: str | None = None
        if layout is not None:
            primary = identified.get(layout.primary_key)
        if primary is None:
            primary = identified.get("laptop_edp")
        if not primary and all_names:
            primary = all_names[0]
        generate_eww_bars(all_names, primary)
        restart_eww(all_names)
        return

    if args.daemon:
        run_daemon()
    else:
        monitors = get_connected_monitors()
        if monitors:
            apply_monitor_config(monitors)
        else:
            print("No monitors detected.", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()

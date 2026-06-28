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

import yaml

# ---------------------------------------------------------------------------
# Data Classes
# ---------------------------------------------------------------------------


@dataclass
class MonitorProfile:
    """Settings for a single known monitor model."""

    match_description: str  # substring to match in hyprctl "description" field
    resolution: str  # e.g. "2560x1440@59.95"
    scale: float = 1.0
    transform: int = 0  # 0=none, 1=90, 2=180, 3=270
    is_builtin: bool = False  # True for eDP-* built-in panels
    default_workspace: int | None = None  # workspace to pin to this monitor on init


@dataclass
class MonitorPlacement:
    """Position for one monitor within a layout."""

    profile_key: str
    position: str  # e.g. "2560x560"


@dataclass
class KnownLayout:
    """A recognized combination of monitors with exact positions."""

    name: str
    required: list[str]  # profile_keys that must ALL be present
    placements: dict[str, MonitorPlacement]  # profile_key -> placement
    primary_key: str  # which profile_key is primary
    priority_order: list[str] | None = (
        None  # apply order: first gets workspace 1. defaults to placements order
    )
    disabled: list[str] | None = (
        None  # profile_keys to explicitly disable in this layout
    )
    # Per-layout overrides for the default monitor profile. Each entry maps a
    # profile_key to a dict that may contain "resolution", "scale", "transform".
    # Used when a layout needs different settings than the monitor's default
    # (e.g. dropping resolution to fit shared USB-C DP bandwidth).
    overrides: dict[str, dict] | None = None

    def __post_init__(self):
        if self.priority_order is None:
            self.priority_order = list(self.placements.keys())
        if self.disabled is None:
            self.disabled = []
        if self.overrides is None:
            self.overrides = {}


# ---------------------------------------------------------------------------
# YAML Loading
# ---------------------------------------------------------------------------

SCRIPT_DIR: str = os.path.dirname(os.path.abspath(__file__))


def _load_monitors(path: str) -> dict[str, MonitorProfile]:
    data: dict
    with open(path) as f:
        data = yaml.safe_load(f)
    return {
        key: MonitorProfile(
            match_description=attrs["match_description"],
            resolution=attrs.get("resolution", ""),
            scale=float(attrs.get("scale", 1.0)),
            transform=int(attrs.get("transform", 0)),
            is_builtin=bool(attrs.get("is_builtin", False)),
            default_workspace=int(attrs["default_workspace"]) if "default_workspace" in attrs else None,
        )
        for key, attrs in data.items()
    }


def _load_layouts(path: str) -> list[KnownLayout]:
    data: list[dict]
    with open(path) as f:
        data = yaml.safe_load(f)
    layouts: list[KnownLayout] = []
    for item in data:
        placements = {
            key: MonitorPlacement(key, str(pos))
            for key, pos in item["placements"].items()
        }
        layouts.append(
            KnownLayout(
                name=item["name"],
                required=item["required"],
                placements=placements,
                primary_key=item["primary_key"],
                priority_order=item.get("priority_order"),
                disabled=item.get("disabled"),
                overrides=item.get("overrides"),
            )
        )
    layouts.sort(key=lambda l: len(l.required), reverse=True)
    return layouts


KNOWN_MONITORS: dict[str, MonitorProfile] = _load_monitors(
    os.path.join(SCRIPT_DIR, "monitors.yaml")
)
KNOWN_LAYOUTS: list[KnownLayout] = _load_layouts(
    os.path.join(SCRIPT_DIR, "layouts.yaml")
)


# ---------------------------------------------------------------------------
# Monitor Detection
# ---------------------------------------------------------------------------

DRY_RUN: bool = False

# Monitors this process has explicitly disabled. Used by the daemon to skip
# monitorremoved events that we ourselves triggered (disabling causes an event
# that would otherwise send the daemon into a configure→disable→event loop).
_SELF_DISABLED: set[str] = set()


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
            print(
                f"WARNING: xrandr --primary failed for {monitor_name}", file=sys.stderr
            )
    except FileNotFoundError:
        print(
            "WARNING: xrandr not found, skipping primary output setting",
            file=sys.stderr,
        )


def hyprctl_keyword_monitor(value: str):
    """Apply a hyprctl keyword monitor command."""
    run_cmd(["hyprctl", "keyword", "monitor", value])


def get_connected_monitors(include_disabled: bool = True) -> list[dict]:
    """Return list of monitor dicts from hyprctl -j monitors.

    By default uses `monitors all` (not just `monitors`) so that monitors
    disabled by a previous layout (e.g. laptop_edp under laptop_4k_left) are
    still visible to the matcher — otherwise the layout that disabled them
    stops matching on subsequent runs and a less-specific layout takes over.

    Pass include_disabled=False to get only the *active* monitors. This is what
    bar generation must use: a disabled/stale monitor left in `monitors all`
    would otherwise get a phantom eww bar that eww renders on the primary
    output, producing duplicate bars on a single screen."""
    cmd: list[str] = ["hyprctl", "-j", "monitors"]
    if include_disabled:
        cmd.append("all")
    for attempt in range(10):
        try:
            out = subprocess.check_output(
                cmd,
                encoding="utf-8",
                stderr=subprocess.DEVNULL,
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
        if not profile.match_description:
            continue
        if profile.match_description.lower() in combined.lower():
            return key

    return None


def match_layout(identified_keys: set[str]) -> KnownLayout | None:
    """Find the best matching layout (most-specific-first)."""
    layout: KnownLayout
    for layout in KNOWN_LAYOUTS:
        if all(k in identified_keys for k in layout.required):
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


def find_nearest_mode(available_modes: list[str], requested: str) -> str:
    """Snap requested WxH[@Hz] to the nearest mode the monitor actually supports.

    Minimises Euclidean distance in (W, H) space first, then fps distance.
    Returns a 'WxH@fps' string (no Hz suffix) ready for hyprctl keyword monitor.
    """
    m_fps: re.Match[str] | None = re.match(r"(\d+)x(\d+)@([\d.]+)", requested)
    m_res: re.Match[str] | None = re.match(r"(\d+)x(\d+)", requested)
    if m_fps:
        req_w, req_h = int(m_fps.group(1)), int(m_fps.group(2))
        req_fps: float | None = float(m_fps.group(3))
    elif m_res:
        req_w, req_h = int(m_res.group(1)), int(m_res.group(2))
        req_fps = None
    else:
        return requested  # unparseable, pass through as-is

    parsed: list[tuple[int, int, float]] = []
    for mode in available_modes:
        mm: re.Match[str] | None = re.match(r"(\d+)x(\d+)@([\d.]+)", mode.strip())
        if mm:
            parsed.append((int(mm.group(1)), int(mm.group(2)), float(mm.group(3))))

    if not parsed:
        return requested

    def _score(t: tuple[int, int, float]) -> tuple[int, float]:
        w, h, fps = t
        return (
            (w - req_w) ** 2 + (h - req_h) ** 2,
            abs(fps - req_fps) if req_fps is not None else 0.0,
        )

    best_w, best_h, best_fps = min(parsed, key=_score)
    return f"{best_w}x{best_h}@{best_fps:.2f}"


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
    identified: dict[str, str] = {}  # profile_key -> hyprctl name
    unidentified: list[dict] = []  # monitors we don't recognize

    mon: dict
    for mon in monitors:
        key: str | None = identify_monitor(mon)
        if key is not None:
            # Handle duplicate models: first one wins, rest are unidentified
            if key in identified:
                print(
                    f"WARNING: Duplicate monitor model '{key}' detected "
                    f"({mon['name']}), treating as unknown",
                    file=sys.stderr,
                )
                unidentified.append(mon)
                continue
            identified[key] = mon["name"]
        else:
            print(
                f"INFO: Unrecognized monitor: {mon['name']} "
                f"(desc: {mon.get('description', 'N/A')})",
                file=sys.stderr,
            )
            unidentified.append(mon)

    # Step 2: Try to match a known layout
    layout: KnownLayout | None = match_layout(set(identified.keys()))

    if layout is not None:
        print(f"Matched layout: {layout.name}")
        if layout.disabled is None:
            raise ValueError(f'Disabled list in layout "{layout.name}" returend None')
        # Pop disabled monitors before applying layout (so they aren't positioned)
        to_disable: dict[str, str] = {}
        for profile_key in layout.disabled:
            if profile_key in identified:
                to_disable[profile_key] = identified.pop(profile_key)
        _apply_known_layout(layout, identified)
        # Auto-place any extra monitors not in the layout
        if unidentified:
            _auto_place_extra(unidentified, layout, identified)
        # Disable after active monitors are configured: Hyprland re-evaluates rules
        # on each keyword call, so disabling last prevents the catchall from re-enabling.
        # Register in _SELF_DISABLED first so the daemon filters the monitorremoved
        # event this generates and doesn't loop back into apply_monitor_config.
        for profile_key, hypr_name in to_disable.items():
            print(f"  Disabling {profile_key} ({hypr_name}) per layout")
            _SELF_DISABLED.add(hypr_name)
            hyprctl_keyword_monitor(f"{hypr_name},disable")
    else:
        # Full fallback: auto-place everything
        print("Fallback: auto-placement for all monitors")
        _auto_place_all(identified, unidentified)

    # Step 3: Apply default workspace bindings for monitors that declare one.
    # Set the workspace rule first (so Hyprland knows the binding), then dispatch
    # moveworkspacetomonitor to apply it immediately even if already initialised.
    profile_key: str
    hypr_name: str
    for profile_key, hypr_name in identified.items():
        ws: int | None = KNOWN_MONITORS[profile_key].default_workspace
        if ws is not None:
            print(f"  Workspace {ws} → {hypr_name}")
            run_cmd(["hyprctl", "keyword", "workspace",
                     f"{ws}, monitor:{hypr_name}, default:true"])
            run_cmd(["hyprctl", "dispatch", "moveworkspacetomonitor",
                     f"{ws} {hypr_name}"])

    # Step 4: Apply system settings based on detected hardware
    apply_system_settings("laptop_edp" in identified)

    # Step 4: Generate and apply EWW bars.
    # Re-query the ACTIVE monitor set (without `all`) so that disabled or stale
    # monitors still listed in `monitors all` don't each get a bar. eww renders
    # a bar for an inactive monitor on the primary output instead, which is what
    # produces "two bars on one screen". Filtering to active monitors avoids it.
    active_names: set[str] = {
        m["name"] for m in get_connected_monitors(include_disabled=False)
    }
    all_names: list[str] = [
        identified[k] for k in identified if identified[k] in active_names
    ]
    all_names += [m["name"] for m in unidentified if m["name"] in active_names]
    primary_name: str | None = None
    if layout:
        primary_name = identified.get(layout.primary_key)
    if primary_name not in active_names:
        primary_name = None
    if not primary_name and identified.get("laptop_edp") in active_names:
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
    """Apply exact positions from a known layout, in priority_order so that
    Hyprland assigns workspace 1 to the first-initialized (highest-priority) monitor."""
    profile_key: str
    placement: MonitorPlacement
    if layout.priority_order is None:
        raise ValueError(f'Priority order in layout "{layout.name}" returend None')
    for profile_key in layout.priority_order:
        if profile_key not in identified:
            continue
        placement = layout.placements[profile_key]
        hypr_name: str = identified[profile_key]
        profile: MonitorProfile = KNOWN_MONITORS[profile_key]
        ov: dict = (layout.overrides or {}).get(profile_key, {})
        resolution: str = ov.get("resolution", profile.resolution)
        scale: float = float(ov.get("scale", profile.scale))
        transform: int = int(ov.get("transform", profile.transform))
        cmd: str = f"{hypr_name},{resolution},{placement.position},{scale}"
        if transform:
            cmd += f",transform,{transform}"
        print(
            f"  {hypr_name}: {resolution} @ {placement.position} "
            f"scale={scale} transform={transform}"
            + (" (override)" if ov else "")
        )
        hyprctl_keyword_monitor(cmd)


def _auto_place_extra(
    unidentified: list[dict], layout: KnownLayout, identified: dict[str, str]
):
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

# Keyboards that already have Caps and Escape physically swapped.
# Substring match against hyprctl device names (lowercase).
PHYSICALLY_SWAPPED_KEYBOARDS: list[str] = [
    "keychron-keychron-q2-max",
    "keychron--keychron-link--keyboard",
]


def has_physically_swapped_keyboard() -> bool:
    """Check if any connected keyboard already has Caps/Esc physically swapped."""
    try:
        out = subprocess.check_output(
            ["hyprctl", "-j", "devices"], encoding="utf-8", stderr=subprocess.DEVNULL
        )
        devices = json.loads(out)
        for kb in devices.get("keyboards", []):
            name: str = kb.get("name", "").lower()
            if any(s in name for s in PHYSICALLY_SWAPPED_KEYBOARDS):
                return True
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError):
        pass
    return False


def apply_system_settings(has_laptop_panel: bool) -> None:
    """Apply system-specific non-monitor settings based on detected hardware."""
    if has_physically_swapped_keyboard():
        print("Detected physically swapped keyboard - skipping caps:swapescape")
        run_cmd(["hyprctl", "keyword", "input:kb_options", ""])
    else:
        print("No physically swapped keyboard - applying caps:swapescape")
        run_cmd(["hyprctl", "keyword", "input:kb_options", "caps:swapescape"])
    if has_laptop_panel:
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
        is_primary: bool = mon_name == primary_name
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

    # Kill all existing eww instances and wait for them to fully exit
    subprocess.run(["pkill", "-9", "-x", "eww"], capture_output=True)
    for _ in range(50):
        if subprocess.run(["pgrep", "-x", "eww"], capture_output=True).returncode != 0:
            break
        time.sleep(0.1)

    # Start daemon
    subprocess.Popen(
        ["setsid", "eww", "daemon"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
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
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
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
        print(
            "WARNING: Could not find Hyprland socket2, falling back to polling",
            file=sys.stderr,
        )
        poll_daemon()
        return

    print(f"Listening for monitor events on {sock_path}")
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        f = s.makefile("r", encoding="utf-8", newline="\n")
    except OSError as e:
        print(
            f"WARNING: Could not connect to socket: {e}, falling back to polling",
            file=sys.stderr,
        )
        poll_daemon()
        return

    line: str
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts: list[str] = line.split(">>", 1)
        event: str = parts[0]
        data: str = parts[1] if len(parts) > 1 else ""
        if event == "monitorremoved" and data in _SELF_DISABLED:
            _SELF_DISABLED.discard(data)
            print(f"INFO: Skipping self-triggered monitorremoved for {data}")
            continue
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
        current_names: set[str] = {m["name"] for m in monitors}  # type: ignore
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
                print(
                    f"  profile:     {profile.resolution}, scale={profile.scale}, "
                    f"transform={profile.transform}"
                )


# ---------------------------------------------------------------------------
# Remote Desktop Mode
# ---------------------------------------------------------------------------


def apply_remote_desktop_mode(resolution: str | None) -> None:
    """Configure only the HDMI dummy for Sunshine/Moonlight remote desktop.

    Kills the monitor daemon so it does not restore the other monitors.
    To return to normal: python3 monitor-setup.py --daemon &
    """
    subprocess.run(
        ["pkill", "-9", "-f", "monitor-setup.py --daemon"], capture_output=True
    )
    time.sleep(0.3)

    monitors: list[dict] = get_connected_monitors(include_disabled=True)
    if not monitors:
        print("No monitors detected.", file=sys.stderr)
        sys.exit(1)

    dummy_name: str | None = None
    dummy_modes: list[str] = []
    others: list[str] = []
    mon: dict
    for mon in monitors:
        key: str | None = identify_monitor(mon)
        if key == "hdmi_dummy":
            dummy_name = mon["name"]
            modes_raw = mon.get("availableModes", [])
            dummy_modes = (
                modes_raw.split() if isinstance(modes_raw, str) else modes_raw
            )
        else:
            others.append(mon["name"])

    if dummy_name is None:
        print("ERROR: No HDMI dummy monitor found (Synaptics).", file=sys.stderr)
        sys.exit(1)

    res_str: str
    if not resolution:
        res_str = "preferred"
    elif "${" in resolution:
        print(
            "WARNING: resolution contains unexpanded shell variables "
            f"({resolution!r}). Sunshine variables are only expanded when the "
            "command is run via a shell. Use:\n"
            "  bash -c 'python3 ... --remote-desktop "
            '\"${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}\"'
            "'\nFalling back to preferred.",
            file=sys.stderr,
        )
        res_str = "preferred"
    else:
        res_str = resolution
        if dummy_modes:
            nearest: str = find_nearest_mode(dummy_modes, res_str)
            req_w, req_h = parse_resolution(res_str)
            near_w, near_h = parse_resolution(nearest)
            if (req_w, req_h) != (near_w, near_h):
                print(f"  {res_str} not available on dummy, snapping to {nearest}")
            res_str = nearest

    print(f"Remote desktop: {dummy_name} → {res_str}")
    hyprctl_keyword_monitor(f"{dummy_name},{res_str},0x0,1.0")

    name: str
    for name in others:
        print(f"  Disabling {name}")
        hyprctl_keyword_monitor(f"{name},disable")

    apply_system_settings(False)
    generate_eww_bars([dummy_name], dummy_name)
    restart_eww([dummy_name])
    print("Remote desktop mode active.")
    print("To restore normal layout: python3 ~/.config/hypr/monitor-setup.py --daemon &")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    global DRY_RUN

    parser = argparse.ArgumentParser(
        description="Auto-detect and configure Hyprland monitors"
    )
    parser.add_argument(
        "--daemon",
        action="store_true",
        help="Run one-shot config then listen for hotplug events",
    )
    parser.add_argument(
        "--eww-only",
        action="store_true",
        help="Only regenerate EWW bars (no monitor reconfiguration)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be done without executing",
    )
    parser.add_argument(
        "--dump-monitors",
        action="store_true",
        help="Print detected monitor info for debugging",
    )
    parser.add_argument(
        "--remote-desktop",
        metavar="RES",
        nargs="?",
        const="",
        help=(
            "Remote desktop mode (Sunshine/Moonlight): activate only the HDMI dummy. "
            "Optional RES: WxH or WxH@Hz (e.g. 1920x1080 or 1920x1080@60). "
            "Snaps to the nearest mode the dummy supports. "
            "Kills the monitor daemon to prevent it from restoring other monitors."
        ),
    )
    args = parser.parse_args()

    DRY_RUN = args.dry_run
    monitors: list[dict]

    if args.dump_monitors:
        dump_monitors()
        return

    if args.remote_desktop is not None:
        apply_remote_desktop_mode(args.remote_desktop or None)
        return

    if args.eww_only:
        # Active monitors only — a disabled/stale monitor would otherwise get a
        # phantom bar that eww renders on the primary (duplicate-bar bug).
        monitors = get_connected_monitors(include_disabled=False)
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

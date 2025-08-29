#!/usr/bin/env python3
import itertools
import subprocess
import time
import re
from dataclasses import dataclass

# =========================
# User-configurable knobs
# =========================

# Focus
FOCUS_TOGGLE_XY = (1848, 958)
FOCUS_X = 1805
FOCUS_Y = 428
FOCUS_PCTS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]  # 10%..100%

# Shutter (seconds). Fractions auto-evaluate.
SHUT_TOGGLE_XY = (660, 995)
SHUT_X = 1904
SHUT_Y = 511
SHUT_PCTS = [
    1/12000, 1/8000, 1/6000, 1/4000, 1/3000, 1/2000, 1/1500, 1/1000,
    1/750, 1/500, 1/350, 1/250, 1/180, 1/125, 1/90, 1/60, 1/50, 1/45,
    1/30, 1/20, 1/15, 1/10, 1/8, 1/6, 1/4, 0.3, 0.5, 1, 2, 4, 8, 10, 15, 20, 30
]

# ISO
ISO_TOGGLE_XY = (888, 995)
ISO_X = 1900
ISO_Y = 485
ISO_PCTS = [50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1600, 3200]

# White Balance (Kelvin)
WB_TOGGLE_XY = (1260, 995)
WB_X = 1904
WB_Y = 518
WB_PCTS = list(range(2300, 10001, 100))

REPEAT_SHOTS = 1
SWEEP_MODE = "single"  # "single" or "product"

# Timing
REVEAL_PAUSE = 0.45   # wait after tapping toggle to reveal control
SETTLE_SEC   = 0.50   # wait after setting a control
POST_SHOT_TAP = (1000, 510)  # set to None to disable
CAPTURE_BASELINE = True
BASELINE_PER_CONTROL = True

DRY_RUN = False  # see how it runs without touching the device

# =========================
# ADB helpers and IO waits
# =========================

def sh(cmd: str):
    if DRY_RUN:
        print(f"[DRY] {cmd}")
        return
    subprocess.run(cmd, shell=True, check=True)

def adb_out(cmd: str) -> str:
    """Run an adb command and return stdout (text)."""
    if DRY_RUN:
        print(f"[DRY OUT] {cmd}")
        return ""
    return subprocess.check_output(cmd, shell=True, text=True).strip()

def tap(x: int | float, y: int | float):
    x = int(round(x)); y = int(round(y))
    sh(f"adb shell input tap {x} {y}")

def shutter():
    """KEYCODE_CAMERA."""
    sh("adb shell input keyevent 27")

def ensure_device_and_open():
    sh("adb get-state")
    # Launch Samsung Expert RAW (adjust package if needed)
    sh("adb shell monkey -p com.samsung.android.app.galaxyraw -c android.intent.category.LAUNCHER 1")
    time.sleep(1.0)

def latest_image_row():
    """
    Query MediaStore for newest image.
    Returns (id:int|None, name:str|None, ts:int|None).
    """
    q = ("adb shell content query "
         "--uri content://media/external/images/media "
         "--projection _id,_display_name,date_added "
         "--sort date_added DESC --limit 1")
    out = adb_out(q)
    if not out:
        return (None, None, None)
    # Example row:
    # Row: 0 _id=12345, _display_name=IMG_20250827_..., date_added=1724766140
    m_id = re.search(r"_id=(\d+)", out)
    m_nm = re.search(r"_display_name=([^,\n]+)", out)
    m_ts = re.search(r"date_added=(\d+)", out)
    mid = int(m_id.group(1)) if m_id else None
    nm  = m_nm.group(1) if m_nm else None
    ts  = int(m_ts.group(1)) if m_ts else None
    return (mid, nm, ts)

def wait_for_new_image(prev_id, timeout_s=10.0, poll_s=0.25) -> tuple[bool, tuple[int|None, str|None, int|None]]:
    """
    Poll MediaStore until a new image appears (id != prev_id) or timeout.
    Returns (ok, (id,name,ts)).
    """
    start = time.time()
    while time.time() - start < timeout_s:
        cur = latest_image_row()
        if cur[0] is not None and cur[0] != prev_id:
            return True, cur
        time.sleep(poll_s)
    return False, (None, None, None)

def exposure_timeout_s(shutter_value_s: float) -> float:
    """
    Dynamic timeout: exposure + processing buffer.
    Buffer = 1.5s + 0.2 * exposure; exposure clamped to [1/12000, 30].
    """
    exp = max(min(float(shutter_value_s), 30.0), 1.0/12000.0)
    buf = 1.5 + 0.2 * exp
    return exp + buf

def shoot_with_wait(current_shutter_value_s: float, label: str = ""):
    """
    Press shutter and wait for MediaStore to publish the new image.
    """
    prev_id, prev_name, _ = latest_image_row()
    shutter()
    tmo = exposure_timeout_s(current_shutter_value_s)
    ok, cur = wait_for_new_image(prev_id, timeout_s=tmo, poll_s=0.3)
    if ok:
        print(f"   ✓ Capture saved: id={cur[0]} name={cur[1]} (≤ {tmo:.1f}s) {label}")
    else:
        print(f"   ! Timed out after {tmo:.1f}s waiting for MediaStore (continuing). {label}")
        time.sleep(0.8)

# =========================
# UI control abstraction
# =========================

def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t

@dataclass
class VControl:
    name: str
    toggle_xy: tuple[int, int]
    x: int
    y: int
    pcts: list[float]
    hint: str

    def reveal(self):
        tap(*self.toggle_xy)
        time.sleep(REVEAL_PAUSE)

    def tap_once(self):
        """Tap the vertical track at a fixed coordinate (as in the original script)."""
        self.reveal()
        tap(self.x, self.y)
        time.sleep(SETTLE_SEC)

    # Optional: if you later calibrate min/max Y for the slider track, you can use tap_percent
    # def tap_percent(self, t01: float, y_min: int, y_max: int):
    #     """Tap at relative position along the vertical track (0..1)."""
    #     self.reveal()
    #     y_pos = int(round(lerp(y_min, y_max, t01)))
    #     tap(self.x, y_pos)
    #     time.sleep(SETTLE_SEC)

# =========================
# Main sweep logic
# =========================

def main():
    ensure_device_and_open()

    focus = VControl("FOCUS",  FOCUS_TOGGLE_XY, FOCUS_X, FOCUS_Y, FOCUS_PCTS, "repeats=len(values)")
    shut  = VControl("SHUTTER", SHUT_TOGGLE_XY, SHUT_X, SHUT_Y, SHUT_PCTS, "repeats=len(values)")
    iso   = VControl("ISO",     ISO_TOGGLE_XY,  ISO_X, ISO_Y, ISO_PCTS, "repeats=len(values)")
    wb    = VControl("WB",      WB_TOGGLE_XY,   WB_X, WB_Y, WB_PCTS, "repeats=len(values)")

    controls = [focus, shut, iso, wb]

    print("Sweep mode:", SWEEP_MODE)
    for c in controls:
        print(f" - {c.name}: {c.hint} | values={c.pcts[:5]}{'...' if len(c.pcts)>5 else ''}")

    shot_count = 0

    if SWEEP_MODE == "product":
        combos = list(itertools.product(focus.pcts, shut.pcts, iso.pcts, wb.pcts))
        total  = len(combos) * REPEAT_SHOTS

        for (pf, ps, pi, pw) in combos:
            label = f"[F{pf:.2f} S{ps:.4f} I{pi} W{pw}]"
            print(f"\nSetting combo {label}")

            focus.tap_once()  # If you calibrate, call focus.tap_percent(...)
            shut.tap_once()
            iso.tap_once()
            wb.tap_once()

            for r in range(REPEAT_SHOTS):
                shot_count += 1
                print(f"  -> Shot {shot_count}/{total} {label} (rep {r+1}/{REPEAT_SHOTS})")
                # Wait until the *actual* image is saved:
                shoot_with_wait(ps, label=label)
                if POST_SHOT_TAP:
                    tap(*POST_SHOT_TAP); time.sleep(0.1)
            # Re-expose WB drawer so the UI stays predictable between combos
            wb.reveal()

    elif SWEEP_MODE == "single":
        for c in controls:
            print(f"\n--- Sweeping {c.name} only ---")
            for v in c.pcts:
                c.tap_once()  # If you calibrate, set the specific value here.
                for r in range(REPEAT_SHOTS):
                    shot_count += 1
                    label = v if isinstance(v, str) else f"{v}"
                    # Use true exposure when sweeping shutter; else a nominal fast time
                    cur_exp = float(v) if (c.name == "SHUTTER" and isinstance(v, (int, float))) else (1/125)
                    print(f"  -> Shot {shot_count} [{c.name}={label}] (rep {r+1}/{REPEAT_SHOTS})")
                    shoot_with_wait(cur_exp, label=f"[{c.name}={label}]")
                    if POST_SHOT_TAP:
                        tap(*POST_SHOT_TAP); time.sleep(0.1)

    else:
        raise ValueError("SWEEP_MODE must be 'product' or 'single'")

    print(f"\nDone. Total shots: {shot_count}")

if __name__ == "__main__":
    main()

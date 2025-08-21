#!/usr/bin/env python3
import itertools
import subprocess
import time
from dataclasses import dataclass

# Focus
FOCUS_TOGGLE_XY = (1848, 977)
FOCUS_X = 1805
FOCUS_Y = 428   
FOCUS_PCTS = [0.0, 0.10, 0.2, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]  # 10%..94%

# Shutter 
SHUT_TOGGLE_XY = (660, 995)
SHUT_X = 1904
SHUT_Y = 511
SHUT_PCTS = [1/12000, 1/8000, 1/6000, 1/4000, 1/3000, 1/2000, 1/1500, 1/1000, 
             1/750, 1/500, 1/350, 1/250, 1/180, 1/125, 1/90, 1/60, 1/50, 1/45, 
             1/30, 1/20, 1/15, 1/10, 1/8, 1/6, 1/4, 0.3, 0.5, 1, 2, 4, 8, 10, 15, 20, 30]

# ISO 
ISO_TOGGLE_XY = (888, 995)
ISO_X = 1900
ISO_Y = 485
ISO_PCTS = [50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1600, 3200]

# White Balance 
WB_TOGGLE_XY = (1260, 995)
WB_X = 1904
WB_Y = 518
WB_PCTS = [2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3100, 3200, 3300, 3400, 3500, 3600, 3700, 3800, 3900, 4000, 
            4100, 4200, 4300, 4400, 4500, 4600, 4700, 4800, 4900, 5000, 5100, 5200, 5300, 5400, 5500, 5600, 5700, 5800, 5900,
            6000, 6100, 6200, 6300, 6400, 6500, 6600, 6700, 6800, 6900, 7000, 7100, 7200, 7300, 7400, 7500, 7600, 7700, 7800, 7900, 8000,
            8100, 8200, 8300, 8400, 8500, 8600, 8700, 8800, 8900, 9000, 9100, 9200, 9300, 9400, 9500, 9600, 9700, 9800, 9900, 10000]

REPEAT_SHOTS = 1
SWEEP_MODE = "single" # or "product"

# Timing
REVEAL_PAUSE    = 0.30   # wait after tapping toggle to reveal control
SETTLE_SEC      = 0.50   # wait after setting a control
POST_SHOT_SEC   = 0.80   # wait after shutter
CAPTURE_BASELINE = True
BASELINE_PER_CONTROL = True

POST_SHOT_TAP   = (1000, 510)  # set to None to disable
# POST_SHOT_TAP = None

DRY_RUN = True #see how it runs

def sh(cmd: str):
    if DRY_RUN:
        print(f"[DRY] {cmd}")
        return
    subprocess.run(cmd, shell=True, check=True)

def tap(x: int | float, y: int | float):
    x = int(round(x)); y = int(round(y))
    sh(f"adb shell input tap {x} {y}")

def shutter():
    sh("adb shell input keyevent 27")  # KEYCODE_CAMERA

def ensure_device_and_open():
    sh("adb get-state")
    sh("adb shell monkey -p com.samsung.android.app.galaxyraw -c android.intent.category.LAUNCHER 1")
    time.sleep(1.0)

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
        """Tap the vertical track at the absolute percent position."""
        self.reveal()
        tap(self.x, self.y)
        time.sleep(SETTLE_SEC)

def main():
    ensure_device_and_open()

    focus = VControl("FOCUS",  FOCUS_TOGGLE_XY, FOCUS_X, FOCUS_Y, FOCUS_PCTS, "repeats=len(values)")
    shut  = VControl("SHUTTER", SHUT_TOGGLE_XY, SHUT_X, SHUT_Y, SHUT_PCTS, "repeats=len(values)")
    iso   = VControl("ISO",     ISO_TOGGLE_XY,  ISO_X, ISO_Y, ISO_PCTS, "repeats=len(values)")
    wb    = VControl("WB",      WB_TOGGLE_XY,   WB_X, WB_Y, WB_PCTS, "repeats=len(values)")

    controls = [focus, shut, iso, wb]

    print("Sweep mode:", SWEEP_MODE)
    for c in controls:
        print(f" - {c.name}: {c.hint} | pcts={c.pcts}")

    shot_count = 0


    if SWEEP_MODE == "product":
        combos = list(itertools.product(focus.pcts, shut.pcts, iso.pcts, wb.pcts))
        total  = len(combos) * REPEAT_SHOTS

        for (pf, ps, pi, pw) in combos:
            label = f"[F{pf:.2f} S{ps:.2f} I{pi:.2f} W{pw:.2f}]"
            print(f"\nSetting combo {label}")

            focus.tap_once()
            shut.tap_once()
            iso.tap_once()
            wb.tap_once()

            for r in range(REPEAT_SHOTS):
                shot_count += 1
                print(f"  -> Shot {shot_count}/{total} {label} (rep {r+1}/{REPEAT_SHOTS})")
                shutter(); time.sleep(POST_SHOT_SEC)
                if POST_SHOT_TAP:
                    tap(*POST_SHOT_TAP); time.sleep(0.1)
                wb.reveal()

    elif SWEEP_MODE == "single":
        for c in controls:
            print(f"\n--- Sweeping {c.name} only ---")
            if BASELINE_PER_CONTROL:
                shot_count += 1
                print(f"  -> Shot {shot_count} [BASELINE for {c.name}]")
                shutter(); time.sleep(POST_SHOT_SEC)
                if POST_SHOT_TAP:
                    tap(*POST_SHOT_TAP); time.sleep(0.1)

            for v in c.pcts:         
                c.tap_once()
                for r in range(REPEAT_SHOTS):
                    shot_count += 1
                    label = v if isinstance(v, str) else f"{v}"
                    shutter(); time.sleep(POST_SHOT_SEC)
                    print(f"  -> Shot {shot_count} [{c.name} label={label}] (rep {r+1}/{REPEAT_SHOTS})")
                    if POST_SHOT_TAP:
                        tap(*POST_SHOT_TAP); time.sleep(0.1)
                c.reveal()


    else:
        raise ValueError("SWEEP_MODE must be 'product' or 'single'")

    print(f"\nDone. Total shots: {shot_count}")

if __name__ == "__main__":
    main()

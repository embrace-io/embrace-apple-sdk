"""Smoothness overhead load calibration report.

Reads `SmoothnessLoadCalibrationUITests` results from one benchmark run: the scroll scenario at
several frame loads, each with no added cost (`off`) and with 25µs and 250µs injected per frame.
For each load it reports:

- the Off arm's hitch ratio: the gate is only sensitive while it is small but non-zero;
- for each injected cost, the hitch ratio delta, how clearly it stands out from noise
  (z = delta / its Welch standard error), and the verdict the gate's hitch check would give;
- the refresh rate and peak thermal state, which make a load's numbers unusable if off.

It then suggests the load that best detects the 25µs cost, among loads that ran at the expected
refresh rate, weren't throttled, and caught the 250µs control, plus a starting OFF_HITCH_BAND for
that device class: half to twice the suggested load's Off hitch ratio. Both are suggestions to
review, not applied automatically.

The report goes to stdout and the job summary. Exits 1 if the run has no calibration results.
"""

import math
import os
import re
import json
import sys
from statistics import mean, stdev, variance

from smoothness_overhead import (
    OVER,
    RATE_MIN_FRACTION,
    THERMAL_SERIOUS,
    expected_rate,
    find,
    fmt,
    hitch_check,
)

DEVICE = os.getenv("DEVICE", "")

# e.g. `testFraction60_1_off()` or `testFraction90_3_cost250()`.
CASE = re.compile(r"^testFraction(?P<value>\d+)_\d+_(?P<arm>off|cost25|cost250)(\(\))?$")

COSTS = ("cost25", "cost250")


def load_settings(results):
    """Returns {fraction percent: {arm: {displayName: metric}}}."""
    settings = {}
    for metric in results:
        match = CASE.match(metric["name"].split("/")[-1])
        if not match:
            continue
        key = int(match["value"])
        settings.setdefault(key, {}).setdefault(match["arm"], {})[metric["displayName"]] = metric
    return settings


def label(key):
    return f"fraction {key / 100:.2f}"


def z_score(cost, off):
    """How many Welch standard errors the cost arm's hitch ratio is above the Off arm's."""
    a, b = find(cost, "Hitch Time Ratio"), find(off, "Hitch Time Ratio")
    if not a or not b or len(a["all"]) < 2 or len(b["all"]) < 2:
        return None
    se = math.sqrt(variance(a["all"]) / len(a["all"]) + variance(b["all"]) / len(b["all"]))
    delta = a["avg"] - b["avg"]
    return math.inf if se == 0 and delta > 0 else (delta / se if se else 0.0)


def evaluate(settings):
    """Returns one row dict per load, in sweep order."""
    rows = []
    for key in sorted(settings):
        arms = settings[key]
        off = arms.get("off", {})
        hitch_off = find(off, "Hitch Time Ratio")
        rate = find(off, "Display Refresh Rate")
        expected = expected_rate(arms)
        thermal = [max(metric["all"]) for metric in (find(a, "Thermal State") for a in arms.values()) if metric]

        row = {
            "key": key,
            "off_mean": hitch_off["avg"] if hitch_off else None,
            "off_sd": stdev(hitch_off["all"]) if hitch_off and len(hitch_off["all"]) > 1 else None,
            "rate": rate["avg"] if rate else None,
            "expected": expected,
            "thermal": max(thermal) if thermal else None,
            "costs": {},
        }
        for cost in COSTS:
            hitch_cost = find(arms.get(cost, {}), "Hitch Time Ratio")
            if not hitch_cost or not hitch_off:
                continue
            row["costs"][cost] = {
                "delta": hitch_cost["avg"] - hitch_off["avg"],
                "z": z_score(arms[cost], off),
                "verdict": hitch_check(arms[cost], off)["status"],
            }

        row["usable"] = (
            row["off_mean"] is not None
            and row["rate"] is not None
            and bool(expected)
            and row["rate"] >= RATE_MIN_FRACTION * expected
            and (row["thermal"] or 0) < THERMAL_SERIOUS
            and row["costs"].get("cost250", {}).get("verdict") == OVER
        )
        rows.append(row)
    return rows


def suggest(rows):
    """The usable load with the clearest 25µs signal, then the clearest 250µs signal."""
    usable = [row for row in rows if row["usable"]]
    if not usable:
        return None

    def z(row, cost):
        value = row["costs"].get(cost, {}).get("z")
        return value if value is not None else -math.inf

    return max(usable, key=lambda row: (z(row, "cost25"), z(row, "cost250")))


def render(rows, suggestion):
    body = ["### 🎚️ Smoothness Overhead Load Calibration"]
    if DEVICE:
        body.append(f"Device: `{DEVICE}`")
    body.append(
        "The scroll scenario at each load, with Smoothness off and 0, 25 or 250 µs injected per frame. "
        "z is the hitch ratio delta in Welch standard errors; the verdict is the gate's hitch check. "
        "A load is usable if it ran at the expected refresh rate, wasn't throttled and caught the 250 µs control."
    )
    body.append("")
    body.append("| Load | Refresh (Hz) | Thermal peak | Off hitch ratio (ms/s) | +25 µs Δ (z) | +25 µs verdict | +250 µs Δ (z) | +250 µs verdict | Usable |")
    body.append("|:---|---:|---:|---:|---:|:---|---:|:---|:---|")
    for row in rows:
        cells = [
            label(row["key"]),
            f"{fmt(row['rate'], 1)} / {fmt(row['expected'], 0)}",
            fmt(row["thermal"], 0),
            f"{fmt(row['off_mean'])} ± {fmt(row['off_sd'])}",
        ]
        for cost in COSTS:
            result = row["costs"].get(cost)
            if result:
                cells += [f"{fmt(result['delta'])} ({fmt(result['z'], 1)})", result["verdict"]]
            else:
                cells += ["n/a", "⚠️ missing"]
        cells.append("✅" if row["usable"] else "—")
        body.append("| " + " | ".join(cells) + " |")

    body.append("")
    if suggestion is None:
        body.append("**No usable load.** None ran at the expected rate unthrottled and caught the 250 µs control.")
        return "\n".join(body)

    env = f"EMBFrameLoadFraction={suggestion['key'] / 100:.2f}"
    rate = round(suggestion["expected"])
    low, high = suggestion["off_mean"] / 2, suggestion["off_mean"] * 2
    body.append(f"**Suggested load:** {label(suggestion['key'])} (`{env}`).")
    body.append(
        f"**Suggested band:** `OFF_HITCH_BAND_{rate}=\"{low:.2f},{high:.2f}\"` "
        "(half to twice this load's Off hitch ratio). Review both before committing them."
    )
    return "\n".join(body)


def main():
    results = json.loads(os.getenv("PERF_PR") or "[]")
    if isinstance(results, dict):
        results = []

    settings = load_settings(results)
    if not settings:
        print("No SmoothnessLoadCalibrationUITests results found in this run.", file=sys.stderr)
        sys.exit(1)

    rows = evaluate(settings)
    markdown = render(rows, suggest(rows))
    print(markdown)

    summary = os.getenv("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(markdown + "\n")


if __name__ == "__main__":
    main()

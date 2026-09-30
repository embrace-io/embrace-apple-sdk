"""Smoothness overhead release gate.

Pairs `SmoothnessOverheadUITests` results from a single benchmark run (`<scenario>_<n>_smoothnessOff`
vs `<scenario>_<n>_smoothnessOn`, same build) and applies the overhead criteria:

- Hitch Time Ratio: the On − Off delta must be shown to be within budget, where the budget is
  max(HITCH_THRESHOLD_PCT of the Off mean, HITCH_ABS_FLOOR ms/s). The floor keeps a near-zero
  baseline from turning noise into a tiny budget. This is an equivalence test: the one-sided
  (1 − ALPHA) Welch upper bound on the delta must be below the budget to pass. If the lower bound
  is above the budget, the scenario fails. Otherwise the run is too noisy to tell, and the scenario
  is inconclusive, which doesn't count as a pass.
- CPU utilization (CPU Time / Clock Monotonic Time, per iteration): increase below
  CPU_MAX_DELTA_PP percentage points.

Each scenario also runs a positive control, `<scenario>_smoothnessOnPlusCost`: Smoothness on, plus a
known cost the benchmark adds to every frame. Each gate the scenario applies must report the control
as over budget; if it doesn't, the gate can't see a cost of that size, and the run is incomplete.

A scenario only counts if the SDK's own frame count ("Smoothness Frames") is above 0 in the On arm
and 0 in the Off arm; otherwise the comparison didn't measure Smoothness and the run is incomplete.

Each arm runs as numbered blocks in a mirrored order (Off, On, OnPlusCost, OnPlusCost, On, Off), so a
steady drift over the run cancels out; `<n>` is the block's position. Each arm's blocks are merged
before the gates run. A scenario is incomplete if the arms' average positions differ (e.g. a block
is missing), or if any iteration's thermal state reached serious, since the device was throttling.

Every arm must also run at the expected refresh rate: the device's own maximum ("Max Display Rate"),
or EXPECTED_HZ if set. A scenario is incomplete if any arm's average "Display Refresh Rate" is below
RATE_MIN_FRACTION of it, or the arms' averages differ by more than RATE_MAX_SPREAD. The refresh rate
comes from frame durations, so hitches don't lower it, unlike "Display Link Rate" (callbacks per
second), which is shown as context.

The hitch gate is only sensitive while the Off arm hitches a little. OFF_HITCH_BAND_<rate> (e.g.
OFF_HITCH_BAND_120="0.5,20", in ms/s) sets the Off hitch ratio band for a device class, taken from
a calibration run; a scenario outside it is incomplete. Unset, the Off hitch ratio is context only.

Every other paired metric is reported for information. The result is posted as a PR comment
(when PR_NUMBER is set) and written to the job summary.

By default the script only reports. With STRICT=1 (release sign-off runs) it exits non-zero unless
the overall result passes: any failed, inconclusive, incomplete or missing row, or no results at all,
blocks.
"""

import math
import os
import re
import json
import sys
from statistics import mean, variance

from scipy import stats

ALPHA = float(os.getenv("ALPHA", "0.05"))
HITCH_THRESHOLD = float(os.getenv("HITCH_THRESHOLD_PCT", "5.0")) / 100.0
HITCH_ABS_FLOOR = float(os.getenv("HITCH_ABS_FLOOR", "1.0"))
CPU_MAX_DELTA_PP = float(os.getenv("CPU_MAX_DELTA_PP", "1.0"))
TITLE = os.getenv("TITLE") or "Smoothness Overhead (on vs off)"
DEVICE = os.getenv("DEVICE", "")
STRICT = os.getenv("STRICT") == "1"
# The refresh rate every arm must reach. Defaults to the device's own maximum ("Max Display Rate").
EXPECTED_HZ = float(os.getenv("EXPECTED_HZ") or 0) or None
RATE_MIN_FRACTION = float(os.getenv("RATE_MIN_FRACTION", "0.85"))
RATE_MAX_SPREAD = float(os.getenv("RATE_MAX_SPREAD", "0.10"))

# e.g. `testScrolling_2_smoothnessOn()`: the number is the block's position in the run.
PAIR = re.compile(r"^(?P<scenario>.*?)(_(?P<block>\d+))?_smoothness(?P<mode>OnPlusCost|On|Off)(\(\))?$")

# The positive control arm: Smoothness on, plus a known per-tick cost the gate must catch.
MODES = {"On": "on", "Off": "off", "OnPlusCost": "control"}

# `ProcessInfo.ThermalState.serious`: the device is throttling, so the arms aren't comparable.
THERMAL_SERIOUS = 2


def one_sided_p(on, off):
    """P-value that `on` is larger than `off` (Welch's t-test), or None if either is too small."""
    if len(on) < 2 or len(off) < 2:
        return None
    t, p = stats.ttest_ind(on, off, equal_var=False)
    if math.isnan(p):
        return None
    return p / 2 if t > 0 else 1 - p / 2


def welch_bounds(on, off, alpha):
    """One-sided (1 - alpha) Welch confidence bounds on mean(on) - mean(off).

    Returns (lower, upper), or None if either side has fewer than 2 values.
    """
    if len(on) < 2 or len(off) < 2:
        return None
    delta = mean(on) - mean(off)
    se_on, se_off = variance(on) / len(on), variance(off) / len(off)
    se = math.sqrt(se_on + se_off)
    if se == 0:
        return delta, delta
    # Welch–Satterthwaite degrees of freedom.
    df = (se_on + se_off) ** 2 / (se_on**2 / (len(on) - 1) + se_off**2 / (len(off) - 1))
    margin = stats.t.ppf(1 - alpha, df) * se
    return delta - margin, delta + margin


def load_pairs(results):
    """Returns {scenario: {"on"|"off"|"control": {displayName: metric}, "blocks": {arm: [position]}}}.

    Each arm runs as several blocks; a metric's iterations from all of an arm's blocks are merged
    into one metric, with its average recomputed.
    """
    pairs = {}
    for metric in results:
        name = metric["name"].split("/")[-1]
        match = PAIR.match(name)
        if not match:
            continue
        mode = MODES[match["mode"]]
        scenario = pairs.setdefault(match["scenario"], {})
        position = int(match["block"]) if match["block"] else None
        blocks = scenario.setdefault("blocks", {}).setdefault(mode, [])
        if position not in blocks:
            blocks.append(position)

        arm = scenario.setdefault(mode, {})
        merged = arm.get(metric["displayName"])
        if merged is None:
            arm[metric["displayName"]] = {**metric, "all": list(metric["all"])}
        else:
            merged["all"] += metric["all"]
            merged["avg"] = mean(merged["all"])
    return pairs


def order_check(blocks):
    """Whether every arm ran as at least two blocks with the same average position in the run.

    With a mirrored order (Off, On, OnPlusCost, OnPlusCost, On, Off), a steady drift over the run
    shifts every arm equally, so it cancels out of each comparison.
    """
    if not blocks or any(None in positions or len(positions) < 2 for positions in blocks.values()):
        return False
    return len({mean(positions) for positions in blocks.values()}) == 1


def find(metrics, needle):
    for display_name, metric in metrics.items():
        if needle.lower() in display_name.lower():
            return metric
    return None


def fmt(x, digits=3):
    return f"{x:.{digits}f}" if x is not None and math.isfinite(x) else "n/a"


def fmtp(p):
    return f"{p:.3g}" if p is not None else "n/a"


WITHIN = "✅ within budget"
OVER = "❌ over budget"
INCONCLUSIVE = "⚠️ inconclusive"


def hitch_check(on, off):
    """Hitch Time Ratio check of `on` against `off`, or None if either lacks the metric.

    Passing needs proof the delta is within budget, so noise can't pass as "no regression".
    """
    hitch_on, hitch_off = find(on, "Hitch Time Ratio"), find(off, "Hitch Time Ratio")
    if not hitch_on or not hitch_off:
        return None

    delta = hitch_on["avg"] - hitch_off["avg"]
    relative = delta / hitch_off["avg"] if hitch_off["avg"] else (math.inf if delta > 0 else 0.0)
    budget = max(HITCH_THRESHOLD * hitch_off["avg"], HITCH_ABS_FLOOR)
    bounds = welch_bounds(hitch_on["all"], hitch_off["all"], ALPHA)
    if bounds is None:
        status, evidence = INCONCLUSIVE, "too few iterations"
    else:
        lower, upper = bounds
        if upper < budget:
            status = WITHIN
        elif lower > budget:
            status = OVER
        else:
            status = INCONCLUSIVE
        evidence = f"≤ {upper:+.3f} (budget {budget:.3f})"

    return {
        "name": hitch_on["displayName"],
        "metric": f"{hitch_on['displayName']} ({hitch_on['unitOfMeasurement']})",
        "status": status,
        "cells": (
            fmt(hitch_off["avg"]),
            fmt(hitch_on["avg"]),
            f"{delta:+.3f} ({relative:+.1%})" if math.isfinite(relative) else f"{delta:+.3f}",
            evidence,
        ),
    }


def cpu_check(on, off):
    """CPU utilization check of `on` against `off`, or None if either lacks CPU or clock time."""
    cpu_on, cpu_off = find(on, "CPU Time"), find(off, "CPU Time")
    clock_on, clock_off = find(on, "Clock Monotonic Time"), find(off, "Clock Monotonic Time")
    if not (cpu_on and cpu_off and clock_on and clock_off):
        return None

    util_on = [c / w * 100 for c, w in zip(cpu_on["all"], clock_on["all"]) if w]
    util_off = [c / w * 100 for c, w in zip(cpu_off["all"], clock_off["all"]) if w]
    delta_pp = mean(util_on) - mean(util_off)

    return {
        "name": cpu_on["displayName"],
        "metric": "CPU utilization (%)",
        "status": OVER if delta_pp >= CPU_MAX_DELTA_PP else WITHIN,
        "cells": (
            fmt(mean(util_off), 2),
            fmt(mean(util_on), 2),
            f"{delta_pp:+.2f} pp",
            f"p = {fmtp(one_sided_p(util_on, util_off))}",
        ),
    }


def expected_rate(arms):
    """The refresh rate the run should reach: EXPECTED_HZ, or the device's own maximum."""
    max_rates = [metric["avg"] for metric in (find(metrics, "Max Display Rate") for metrics in arms.values() if metrics) if metric]
    return EXPECTED_HZ or (max(max_rates) if max_rates else None)


def baseline_band(rate):
    """The Off hitch ratio band set for this device class, as (low, high), or None if unset.

    Set from a calibration run (`bin/smoothness_calibration.py`) as OFF_HITCH_BAND_<rate>, e.g.
    OFF_HITCH_BAND_120="0.5,20", because the sensitive range differs between 60Hz and 120Hz devices.
    """
    value = os.getenv(f"OFF_HITCH_BAND_{round(rate)}", "") if rate else ""
    if not value.strip():
        return None
    low, high = (float(part) for part in value.split(","))
    return low, high


def baseline_check(scenario, off, rate):
    """Returns (gate row, ok) for the Off arm's hitch ratio against its calibrated band.

    The gate is only sensitive while the Off arm hitches a little. Outside the band (e.g. an iOS
    update made the screen cheaper to render), a pass doesn't show the SDK is cheap.
    """
    hitch_off = find(off, "Hitch Time Ratio")
    if not hitch_off:
        return None, True
    band = baseline_band(rate)
    metric = f"Off hitch ratio ({hitch_off['unitOfMeasurement']})"
    if band is None:
        return (scenario, metric, "ℹ️ no band set", fmt(hitch_off["avg"]), "", "", f"OFF_HITCH_BAND_{round(rate or 0)} unset"), True
    low, high = band
    ok = low <= hitch_off["avg"] <= high
    status = "✅ in band" if ok else "⚠️ outside band"
    return (scenario, metric, status, fmt(hitch_off["avg"]), "", "", f"band {low:g}–{high:g}"), ok


def refresh_rate_check(scenario, arms):
    """Returns (gate row, ok). Every arm's average refresh rate must reach RATE_MIN_FRACTION of the
    expected rate, and the arms' averages must be within RATE_MAX_SPREAD of each other."""
    rates = {arm: find(metrics, "Display Refresh Rate") for arm, metrics in arms.items() if metrics}
    rates = {arm: metric["avg"] for arm, metric in rates.items() if metric}
    if "off" not in rates or "on" not in rates:
        return (scenario, "Display Refresh Rate", "⚠️ missing", "can't confirm the refresh rate", "", "", ""), False

    expected = expected_rate(arms)
    if not expected:
        return (scenario, "Display Refresh Rate", "⚠️ missing", "no Max Display Rate or EXPECTED_HZ", "", "", ""), False

    floor = RATE_MIN_FRACTION * expected
    spread = (max(rates.values()) - min(rates.values())) / max(rates.values()) if max(rates.values()) else 0.0
    if min(rates.values()) < floor:
        status = "⚠️ below expected"
    elif spread > RATE_MAX_SPREAD:
        status = "⚠️ arms differ"
    else:
        status = "✅ at expected rate"
    evidence = f"expected {expected:.0f} Hz (≥ {floor:.0f}), spread {spread:.0%}"
    if "control" in rates:
        evidence += f", control {rates['control']:.1f}"
    row = (scenario, "Display Refresh Rate (Hz)", status, fmt(rates["off"], 1), fmt(rates["on"], 1), "", evidence)
    return row, status.startswith("✅")


def evaluate(pairs):
    """Returns (gate rows, info rows, overall pass)."""
    gates, info = [], []
    passed = True

    for scenario in sorted(pairs):
        on, off = pairs[scenario].get("on", {}), pairs[scenario].get("off", {})
        if not on or not off:
            gates.append((scenario, "pairing", "⚠️ missing", "only one side ran", "", "", ""))
            passed = False
            continue

        gated = set()
        shown = set()

        # Proves the comparison measured Smoothness: without it, an On arm where the service
        # disabled itself (e.g. under a debugger) would pass as SDK-off against SDK-off.
        frames_on, frames_off = find(on, "Smoothness Frames"), find(off, "Smoothness Frames")
        if frames_on and frames_off:
            shown.add(frames_on["displayName"])
            active = frames_on["avg"] > 0 and frames_off["avg"] == 0
            passed &= active
            if active:
                status = "✅ active"
            elif frames_on["avg"] <= 0:
                status = "❌ inactive in On"
            else:
                status = "❌ active in Off"
            gates.append((
                scenario,
                f"{frames_on['displayName']} ({frames_on['unitOfMeasurement']})",
                status,
                fmt(frames_off["avg"], 0),
                fmt(frames_on["avg"], 0),
                "",
                "",
            ))
        else:
            gates.append((scenario, "Smoothness Frames", "⚠️ missing", "can't confirm Smoothness ran", "", "", ""))
            passed = False

        hitch = hitch_check(on, off)
        if hitch:
            gated.add(hitch["name"])
            passed &= hitch["status"] == WITHIN
            gates.append((scenario, hitch["metric"], hitch["status"], *hitch["cells"]))

        cpu = cpu_check(on, off)
        if cpu:
            gated.add(cpu["name"])
            passed &= cpu["status"] == WITHIN
            gates.append((scenario, cpu["metric"], cpu["status"], *cpu["cells"]))

        # The positive control must be caught by every gate this scenario applies. If it isn't, the
        # gate can't see a cost of that size (e.g. the baseline is saturated), so a pass means nothing.
        control = pairs[scenario].get("control", {})
        if not control:
            gates.append((scenario, "positive control", "⚠️ missing", "can't show the gate detects a cost", "", "", ""))
            passed = False
        else:
            frames_control = find(control, "Smoothness Frames")
            if not frames_control or frames_control["avg"] <= 0:
                gates.append((scenario, "positive control", "❌ inactive", "Smoothness counted no frames", "", "", ""))
                passed = False
            for check, gate in ((hitch_check, hitch), (cpu_check, cpu)):
                if not gate:
                    continue
                result = check(control, off)
                if not result:
                    gates.append((scenario, f"control: {gate['metric']}", "⚠️ missing", "", "", "", ""))
                    passed = False
                    continue
                detected = result["status"] == OVER
                passed &= detected
                gates.append((
                    scenario,
                    f"control: {result['metric']}",
                    "✅ detected" if detected else "❌ not detected",
                    *result["cells"],
                ))

        # A missing block breaks the mirrored order, so drift would no longer cancel.
        blocks = pairs[scenario].get("blocks", {})
        ordered = order_check(blocks)
        passed &= ordered
        gates.append((
            scenario,
            "run order",
            "✅ mirrored" if ordered else "⚠️ unbalanced",
            ", ".join(f"{arm} {sorted(p for p in positions if p is not None)}" for arm, positions in sorted(blocks.items())),
            "",
            "",
            "",
        ))

        # Throttling changes what the arms measure, so a throttled run can't be compared.
        thermal = {arm: find(metrics, "Thermal State") for arm, metrics in (("off", off), ("on", on), ("control", control))}
        if thermal["off"] and thermal["on"]:
            shown.add(thermal["on"]["displayName"])
            peaks = {arm: max(metric["all"]) for arm, metric in thermal.items() if metric}
            throttled = max(peaks.values()) >= THERMAL_SERIOUS
            passed &= not throttled
            gates.append((
                scenario,
                "Thermal State (peak)",
                "❌ throttled" if throttled else "ℹ️ context",
                fmt(peaks["off"], 0),
                fmt(peaks["on"], 0),
                "",
                f"control {fmt(peaks['control'], 0)}" if "control" in peaks else "",
            ))
        else:
            gates.append((scenario, "Thermal State", "⚠️ missing", "can't rule out throttling", "", "", ""))
            passed = False

        # The SDK's cost is per tick, so a run that fell back to a lower refresh rate (Low Power Mode,
        # thermal caps, no ProMotion) under-measures it, and arms at different rates aren't comparable.
        arms = {"off": off, "on": on, "control": control}
        rate_row, rate_ok = refresh_rate_check(scenario, arms)
        shown.update({"Display Refresh Rate", "Max Display Rate"})
        passed &= rate_ok
        gates.append(rate_row)

        baseline_row, baseline_ok = baseline_check(scenario, off, expected_rate(arms))
        if baseline_row:
            passed &= baseline_ok
            gates.append(baseline_row)

        # Context only: callbacks per second, which drop when the main thread hitches.
        rate_on, rate_off = find(on, "Display Link Rate"), find(off, "Display Link Rate")
        if rate_on and rate_off:
            shown.add(rate_on["displayName"])
            gates.append((
                scenario,
                f"{rate_on['displayName']} ({rate_on['unitOfMeasurement']})",
                "ℹ️ context",
                fmt(rate_off["avg"], 1),
                fmt(rate_on["avg"], 1),
                "",
                "",
            ))

        # e.g. the simulator emits scroll duration but no hitch metrics.
        if not gated:
            gates.append((scenario, "gated metrics", "⚠️ missing", "no hitch or CPU utilization metric", "", "", ""))
            passed = False

        for display_name in sorted(on):
            if display_name in gated or display_name in shown or display_name not in off:
                continue
            a, b = on[display_name], off[display_name]
            relative = (a["avg"] - b["avg"]) / b["avg"] if b["avg"] else math.nan
            info.append((
                scenario,
                f"{display_name} ({a['unitOfMeasurement']})",
                fmt(b["avg"]),
                fmt(a["avg"]),
                f"{relative:+.1%}" if math.isfinite(relative) else "n/a",
                fmtp(one_sided_p(a["all"], b["all"])),
            ))

    return gates, info, passed


def render(gates, info, passed, has_results):
    marker = f"<!-- perf-check-comment: {TITLE} -->"
    body = [marker, f"### {TITLE}"]
    if DEVICE:
        body.append(f"Device: `{DEVICE}`")
    body.append(
        f"Criteria: hitch time ratio delta proven within budget — the one-sided {1 - ALPHA:.0%} upper bound "
        f"must be below max(`{HITCH_THRESHOLD:.0%}` of Off, `{HITCH_ABS_FLOOR}` ms/s), and a run too noisy "
        f"to show that is inconclusive; CPU utilization increase < `{CPU_MAX_DELTA_PP}` pp; "
        "Smoothness frame count > 0 in On and 0 in Off; the positive control (On plus a known per-frame "
        "cost) must be over budget on every gate. Hang capture is on in all arms."
    )
    body.append("")

    if not has_results:
        body.append("⚠️ No `SmoothnessOverheadUITests` results found in this run.")
        if STRICT:
            body.append("")
            body.append("**Strict mode: this run blocks.**")
        return "\n".join(body)

    verdict = "✅ within budget" if passed else "❌ over budget, inconclusive or incomplete"
    if STRICT:
        mode = "strict mode, gate passed" if passed else "strict mode, this run blocks"
    else:
        mode = "report only; release sign-off uses a strict run"
    body.append(f"**Overall: {verdict}** — {mode}.")
    body.append("")
    body.append("| Scenario | Metric | Status | Off | On | Δ | Evidence |")
    body.append("|:---|:---|:---|---:|---:|---:|---:|")
    for row in gates:
        body.append("| " + " | ".join(row) + " |")

    if info:
        body.append("")
        body.append("<details><summary>Other metrics (informational)</summary>")
        body.append("")
        body.append("| Scenario | Metric | Off | On | Δ | p |")
        body.append("|:---|:---|---:|---:|---:|---:|")
        for row in info:
            body.append("| " + " | ".join(row) + " |")
        body.append("")
        body.append("</details>")

    return "\n".join(body)


def post_comment(markdown):
    from github import Github

    gh = Github(os.environ["GITHUB_TOKEN"])
    pr = gh.get_repo(os.environ["REPO"]).get_pull(int(os.environ["PR_NUMBER"]))
    marker = markdown.splitlines()[0]
    for comment in pr.get_issue_comments():
        if marker in comment.body:
            comment.edit(markdown)
            return
    pr.create_issue_comment(markdown)


def main():
    results = json.loads(os.getenv("PERF_PR") or "[]")
    if isinstance(results, dict):
        results = []

    pairs = load_pairs(results)
    gates, info, passed = evaluate(pairs)
    markdown = render(gates, info, passed, bool(pairs))
    print(markdown)

    summary = os.getenv("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(markdown + "\n")

    if os.getenv("PR_NUMBER"):
        post_comment(markdown)

    # Exits only after reporting, so a blocked run still shows why.
    if STRICT and not (pairs and passed):
        print("Smoothness overhead gate did not pass (STRICT=1).", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

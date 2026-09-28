"""Smoothness overhead release gate.

Pairs `SmoothnessOverheadUITests` results from a single benchmark run (`<scenario>_smoothnessOff`
vs `<scenario>_smoothnessOn`, same build) and applies the overhead criteria:

- Hitch Time Ratio: no regression that is significant (one-sided Welch, p < ALPHA), at least
  HITCH_THRESHOLD_PCT relative, and at least HITCH_ABS_FLOOR ms/s absolute. The floor keeps a
  near-zero baseline from turning noise into a large relative change.
- CPU utilization (CPU Time / Clock Monotonic Time, per iteration): increase below
  CPU_MAX_DELTA_PP percentage points.

Every other paired metric is reported for information. The result is posted as a PR comment
(when PR_NUMBER is set) and written to the job summary. It never fails the job: release
sign-off is manual, backed by these numbers.
"""

import math
import os
import re
import json
from statistics import mean

from scipy import stats

ALPHA = float(os.getenv("ALPHA", "0.05"))
HITCH_THRESHOLD = float(os.getenv("HITCH_THRESHOLD_PCT", "5.0")) / 100.0
HITCH_ABS_FLOOR = float(os.getenv("HITCH_ABS_FLOOR", "1.0"))
CPU_MAX_DELTA_PP = float(os.getenv("CPU_MAX_DELTA_PP", "1.0"))
TITLE = os.getenv("TITLE") or "Smoothness Overhead (on vs off)"
DEVICE = os.getenv("DEVICE", "")

PAIR = re.compile(r"^(?P<scenario>.*)_smoothness(?P<mode>On|Off)(\(\))?$")


def one_sided_p(on, off):
    """P-value that `on` is larger than `off` (Welch's t-test), or None if either is too small."""
    if len(on) < 2 or len(off) < 2:
        return None
    t, p = stats.ttest_ind(on, off, equal_var=False)
    if math.isnan(p):
        return None
    return p / 2 if t > 0 else 1 - p / 2


def load_pairs(results):
    """Returns {scenario: {"on"|"off": {displayName: metric}}}."""
    pairs = {}
    for metric in results:
        name = metric["name"].split("/")[-1]
        match = PAIR.match(name)
        if not match:
            continue
        mode = match["mode"].lower()
        pairs.setdefault(match["scenario"], {}).setdefault(mode, {})[metric["displayName"]] = metric
    return pairs


def find(metrics, needle):
    for display_name, metric in metrics.items():
        if needle.lower() in display_name.lower():
            return metric
    return None


def fmt(x, digits=3):
    return f"{x:.{digits}f}" if x is not None and math.isfinite(x) else "n/a"


def fmtp(p):
    return f"{p:.3g}" if p is not None else "n/a"


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

        hitch_on, hitch_off = find(on, "Hitch Time Ratio"), find(off, "Hitch Time Ratio")
        if hitch_on and hitch_off:
            gated.add(hitch_on["displayName"])
            delta = hitch_on["avg"] - hitch_off["avg"]
            relative = delta / hitch_off["avg"] if hitch_off["avg"] else (math.inf if delta > 0 else 0.0)
            p = one_sided_p(hitch_on["all"], hitch_off["all"])
            regressed = p is not None and p < ALPHA and relative >= HITCH_THRESHOLD and delta >= HITCH_ABS_FLOOR
            passed &= not regressed
            gates.append((
                scenario,
                f"{hitch_on['displayName']} ({hitch_on['unitOfMeasurement']})",
                "❌ fail" if regressed else "✅ pass",
                fmt(hitch_off["avg"]),
                fmt(hitch_on["avg"]),
                f"{delta:+.3f} ({relative:+.1%})" if math.isfinite(relative) else f"{delta:+.3f}",
                fmtp(p),
            ))

        cpu_on, cpu_off = find(on, "CPU Time"), find(off, "CPU Time")
        clock_on, clock_off = find(on, "Clock Monotonic Time"), find(off, "Clock Monotonic Time")
        if cpu_on and cpu_off and clock_on and clock_off:
            gated.add(cpu_on["displayName"])
            util_on = [c / w * 100 for c, w in zip(cpu_on["all"], clock_on["all"]) if w]
            util_off = [c / w * 100 for c, w in zip(cpu_off["all"], clock_off["all"]) if w]
            delta_pp = mean(util_on) - mean(util_off)
            regressed = delta_pp >= CPU_MAX_DELTA_PP
            passed &= not regressed
            gates.append((
                scenario,
                "CPU utilization (%)",
                "❌ fail" if regressed else "✅ pass",
                fmt(mean(util_off), 2),
                fmt(mean(util_on), 2),
                f"{delta_pp:+.2f} pp",
                fmtp(one_sided_p(util_on, util_off)),
            ))

        # Context only: shows whether the scenario really ran at the intended refresh rate.
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
        f"Criteria: hitch time ratio no significant regression (α = `{ALPHA}`, ≥ `{HITCH_THRESHOLD:.0%}` "
        f"and ≥ `{HITCH_ABS_FLOOR}` ms/s); CPU utilization increase < `{CPU_MAX_DELTA_PP}` pp. "
        "Hang capture is on in both arms."
    )
    body.append("")

    if not has_results:
        body.append("⚠️ No `SmoothnessOverheadUITests` results found in this run.")
        return "\n".join(body)

    body.append(f"**Overall: {'✅ within budget' if passed else '❌ over budget or incomplete'}** — release sign-off still required.")
    body.append("")
    body.append("| Scenario | Metric | Status | Off | On | Δ | p |")
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


if __name__ == "__main__":
    main()

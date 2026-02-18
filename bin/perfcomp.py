import os, json, math
from statistics import mean
from github import Github
from scipy import stats

THRESHOLD = float(os.getenv("THRESHOLD_PCT", "15.0")) / 100.0  # percent → fraction
ALPHA = float(os.getenv("ALPHA", "0.05"))
TITLE = os.getenv("TITLE") or "Set a title pls"

pr_data = json.loads(os.getenv("PERF_PR", "[]"))
main_data = json.loads(os.getenv("PERF_MAIN", "[]"))

main_by_name = {m["name"]: m for m in main_data}
rows = []

for pr in pr_data:
    main = main_by_name.get(pr["name"])
    if not main:
        main = pr.copy()
    
    a, b = pr, main
    pr_mean, main_mean = a["avg"], b["avg"]
    slowdown_pct = (pr_mean - main_mean) / main_mean if main_mean else float("inf")

    # Welch’s t-test
    if a["count"] >= 2 and b["count"] >= 2:
        t, p = stats.ttest_ind_from_stats(
            mean1=a["avg"], std1=a["stddev"], nobs1=a["count"],
            mean2=b["avg"], std2=b["stddev"], nobs2=b["count"],
            equal_var=False
        )
        # one-sided: PR slower
        p = p/2 if t > 0 else 1 - p/2
    else:
        p = None

    significant = (p is not None and p < ALPHA and slowdown_pct >= THRESHOLD)

    rows.append({
        "name": pr["name"],
        "displayName": pr.get("displayName", "N/A"),
        "unitOfMeasurement": pr.get("unitOfMeasurement", "N/A"),
        "pr_avg": pr_mean,
        "main_avg": main_mean,
        "slowdown_pct": slowdown_pct,
        "p": p,
        "significant": significant,
    })

# Build markdown
def fmtpct(x): return f"{x:+.2%}" if math.isfinite(x) else "n/a"
def fmtp(p): return f"{p:.3g}" if p is not None else "n/a"

def clean_test_name(name):
    """Extract last part of test name and remove parentheses"""
    # Get the part after the last "/"
    if "/" in name:
        name = name.split("/")[-1]
    # Remove parentheses
    return name.replace("(", "").replace(")", "")

# Sort rows by DisplayName, Unit, then test name
rows.sort(key=lambda r: (r["displayName"], r["unitOfMeasurement"], r["name"]))

body = [f"<!-- perf-check-comment: {TITLE} -->",
        f"### {TITLE}",
        f"Threshold: `{THRESHOLD*100:.1f}%`, α = `{ALPHA}`",
        ""]

prev_group = None
for r in rows:
    current_group = (r["displayName"], r["unitOfMeasurement"])

    # Add header for new group
    if current_group != prev_group:
        if prev_group is not None:
            body.append("")  # Add spacing between groups
        body.append(f"#### {r['displayName']} ({r['unitOfMeasurement']})")
        body.append("| Status | Test | PR Avg | Main Avg | Δ vs Main | p |")
        body.append("|:-------|:-----|-------:|---------:|----------:|---:|")
        prev_group = current_group

    status = "🔴 regression" if r["significant"] else "🟢 ok"
    test_name = clean_test_name(r["name"])
    body.append(f"| {status} | `{test_name}` | {r['pr_avg']:.3f} | {r['main_avg']:.3f} | {fmtpct(r['slowdown_pct'])} | {fmtp(r['p'])} |")

markdown = "\n".join(body)

# Post or update PR comment
token = os.environ["GITHUB_TOKEN"]
repo = os.environ["REPO"]
pr_number = int(os.environ["PR_NUMBER"])

gh = Github(token)
repo_obj = gh.get_repo(repo)
pr_obj = repo_obj.get_pull(pr_number)

existing = None
comment_marker = f"<!-- perf-check-comment: {TITLE} -->"
for c in pr_obj.get_issue_comments():
    if comment_marker in c.body:
        existing = c
        break

if existing:
    existing.edit(markdown)
else:
    pr_obj.create_issue_comment(markdown)

print(markdown)

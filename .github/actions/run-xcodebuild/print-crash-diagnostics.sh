#!/usr/bin/env bash
# Prints the crash diagnostics that an xcresult bundle holds but the xcodebuild log does not:
#
# - Sanitizer reports. Each test bundle's stdout/stderr is stored only in the bundle, so a
#   ThreadSanitizer report that aborts the test process shows up in the log as a bare
#   "Test crashed with signal abrt."
# - The crashed thread of each .ips crash report.
# - For a bundle that restarted after a crash with no sanitizer report, the output leading up to
#   the restart.
#
# Diagnostic-only: always exits 0, so it never changes the job's outcome.
#
# Usage: print-crash-diagnostics.sh <path-to.xcresult>

set -uo pipefail

bundle="${1:?usage: print-crash-diagnostics.sh <path-to.xcresult>}"
max_report_lines=400
max_frames=30
restart_context_lines=40

if [[ ! -d "$bundle" ]]; then
  echo "No xcresult bundle at $bundle; skipping crash diagnostics"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
diagnostics="$work/diagnostics"

if ! xcrun xcresulttool export diagnostics --path "$bundle" --output-path "$diagnostics" >"$work/export.log" 2>&1; then
  echo "::warning::xcresulttool could not export diagnostics from $bundle"
  cat "$work/export.log"
  exit 0
fi

# Appends stdin to the job's Summary tab; discards it when run outside GitHub Actions.
summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat >>"$GITHUB_STEP_SUMMARY"
  else
    cat >/dev/null
  fi
}

# The bundle's directory is named "<TestBundle>-<UUID>".
bundle_name() { basename "$(dirname "$1")" | sed -E 's/-[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$//'; }

found=0

# Sanitizer reports run from the "WARNING: ThreadSanitizer:" / "ERROR: AddressSanitizer:" header
# to the "SUMMARY: …Sanitizer:" line. Other threads keep logging while the report is written, so
# timestamped log lines and XCTest progress lines inside a report are dropped.
while IFS= read -r -d '' output; do
  report=$(awk '
    /WARNING: ThreadSanitizer:|ERROR: AddressSanitizer:|ERROR: UndefinedBehaviorSanitizer:|runtime error:/ { inside = 1 }
    inside && !/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9:.]+\+[0-9][0-9][0-9][0-9] / && !/^Test (Case|Suite) / { print }
    inside && /^SUMMARY: [A-Za-z]+Sanitizer:/ { inside = 0; print "" }
  ' "$output" | head -n "$max_report_lines")

  name=$(bundle_name "$output")

  if [[ -n "$report" ]]; then
    found=1
    echo "::group::Sanitizer report — $name"
    echo "$report"
    echo "::endgroup::"

    # Drops the "(<binary path>:arm64+0x…)" location so the annotation reads as the race itself.
    grep -E '^SUMMARY: [A-Za-z]+Sanitizer:' <<<"$report" | sed -E 's/ \([^)]*\) in / in /' | while IFS= read -r line; do
      echo "::error title=${name} sanitizer report::${line}"
    done

    {
      echo "### 🧵 Sanitizer report — ${name}"
      echo ""
      echo '```'
      echo "$report"
      echo '```'
    } | summary
    continue
  fi

  # No sanitizer report, but the bundle restarted after a crash: show what came right before it.
  grep -n '^Restarting after unexpected exit' "$output" | cut -d: -f1 | while IFS= read -r line_number; do
    first=$((line_number > restart_context_lines ? line_number - restart_context_lines : 1))
    echo "::group::Output before the restart — $name (line $line_number)"
    sed -n "${first},${line_number}p" "$output"
    echo "::endgroup::"
  done
done < <(find "$diagnostics" -name StandardOutputAndStandardError.txt -print0)

# An .ips file is a one-line JSON header followed by the JSON crash report. The simulator's
# DiagnosticReports also collects crashes of system daemons (PosterBoard, chronod, …), so only the
# test runner's reports are printed in full.
other_crashes=()
while IFS= read -r -d '' ips; do
  process=$(head -n 1 "$ips" | jq -r '.app_name // .name // empty' 2>/dev/null)
  if [[ "$process" != "xctest" ]]; then
    other_crashes+=("$(basename "$ips")")
    continue
  fi
  found=1
  crash=$(tail -n +2 "$ips" | jq -r --argjson max "$max_frames" '
    .usedImages as $images
    | "Process: \(.procName // "?")",
      "Exception: \(.exception.type // "?") \(.exception.signal // "")",
      (.asi // {} | to_entries[] | "Message (\(.key)): \(.value | join(" "))"),
      (.threads[]? | select(.triggered) |
        "Crashed thread queue: \(.queue // "-")",
        (.frames[:$max][] | "  \($images[.imageIndex].name // "?")  \(.symbol // "+\(.imageOffset)")"))
  ' 2>&1)

  echo "::group::Crash report — $(basename "$ips")"
  echo "$crash"
  echo "::endgroup::"
done < <(find "$diagnostics" -name '*.ips' -print0)

if [[ ${#other_crashes[@]} -gt 0 ]]; then
  echo "Crash reports from other simulator processes, not printed: ${other_crashes[*]}"
fi

if [[ "$found" -eq 0 ]]; then
  echo "No sanitizer reports or crash reports in $bundle"
fi

exit 0

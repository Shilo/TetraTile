#!/usr/bin/env bash
# Linux/CI mirror of run_tests.ps1. Identical 17-test inventory.
#
# Usage from project root:
#   bash addons/penta_tile/tests/run_tests.sh                  # all tests, headless
#   GODOT=/path/to/godot bash addons/penta_tile/tests/...      # custom Godot binary
#
# Each test exits 0 on PASS, non-zero on FAIL. Runner aggregates and exits with
# the count of failed tests (0 = all green). Per Pitfall #1 (Godot CLI exit
# codes unreliable in --headless mode), failure detection is BOTH the exit
# code AND a stderr grep for ERROR / FAIL / MAIN TEST FAILED markers — either
# signal flips the test to FAIL.
#
# Inventory keep-in-sync anchor: addons/penta_tile/tests/run_tests.ps1:53-71
# (17 tests, in this exact order — order matters for the failure summary).
# Note: penta_ground_hollow_test was retired in Phase 5 Plan 01 (the demo's
# authored ground.tres was removed); inventory is 17 tests, not 18.

set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if ! command -v "$GODOT" > /dev/null 2>&1; then
    echo "FATAL: Godot binary not found. Set GODOT=/path/to/godot or install godot in PATH." >&2
    exit 2
fi

# 17-test inventory — keep in sync with run_tests.ps1:53-71.
TESTS=(
    paint_test
    all_layouts_test
    visual_render_test
    strict_pixel_test
    penta_one_mode_test
    auto_strip_axis_test
    layout_swap_test
    all_layouts_swap_pixel_test
    bitmask_bounds_test
    comprehensive_bitmask_test
    determinism_test
    blob_47_collapse_test
    blob_47_hollow_test
    single_grid_8_moore_propagation_test
    pixellab_first_cell_test
    pixellab_visual_regression_test
    fallback_routing_test
)

failures=0
declare -a results

for t in "${TESTS[@]}"; do
    echo ""
    echo "============================================================"
    echo "[$t]"
    echo "============================================================"

    script_path="addons/penta_tile/tests/${t}.gd"
    full_path="${PROJECT_ROOT}/${script_path}"

    if [ ! -f "$full_path" ]; then
        echo "SKIP: script not found at ${full_path}"
        results+=("$t SKIP")
        continue
    fi

    stderr_log="$(mktemp)"
    # The script-mode tests call `quit()` themselves; --quit-after is NOT used.
    # Pitfall #1 mitigation: capture stderr; treat error markers as failures
    # even if the exit code is 0.
    "$GODOT" --headless --path "$PROJECT_ROOT" --script "$script_path" 2> "$stderr_log"
    rc=$?

    # Failure detection: exit-code OR stderr error markers.
    if [ "$rc" -ne 0 ] || grep -qE '^(ERROR|FAIL)\b|MAIN TEST FAILED|MAIN TEST WARNING' "$stderr_log"; then
        echo "FAIL ($t, rc=$rc):"
        cat "$stderr_log" || true
        results+=("$t FAIL (rc=$rc)")
        failures=$((failures + 1))
    else
        echo "PASS: $t"
        results+=("$t PASS")
    fi

    rm -f "$stderr_log"
done

echo ""
echo "============================================================"
echo "Test summary"
echo "============================================================"
for r in "${results[@]}"; do
    echo "  $r"
done

echo ""
total="${#TESTS[@]}"
if [ "$failures" -eq 0 ]; then
    echo "ALL GREEN ($total tests)"
    exit 0
else
    echo "$failures of $total FAILED"
    exit "$failures"
fi

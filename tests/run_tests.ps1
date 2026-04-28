# Run PentaTile test suite — headless by default, -Windowed for visible runs.
#
# Usage from project root:
#   .\addons\penta_tile\tests\run_tests.ps1                  # all tests, headless, summary only
#   .\addons\penta_tile\tests\run_tests.ps1 -Verbose         # all tests, full output
#   .\addons\penta_tile\tests\run_tests.ps1 -Test paint_test # one test
#   .\addons\penta_tile\tests\run_tests.ps1 -Windowed        # no --headless flag (window opens)
#
# Each test exits 0 on PASS, 1 on FAIL. Script aggregates and exits with the
# count of failed tests (0 = all green).

[CmdletBinding()]
param(
    [string]$Test = "all",
    [switch]$Windowed,
    [switch]$NoPause,
    [string]$GodotExe = "C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

# Project root = two levels up from this script (addons/penta_tile/tests/).
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$testsDir    = Join-Path $projectRoot "addons\penta_tile\tests"

# Sanity checks.
if (-not (Test-Path $GodotExe)) {
    Write-Host "Godot executable not found at:" -ForegroundColor Red
    Write-Host "  $GodotExe" -ForegroundColor Red
    Write-Host "Pass -GodotExe <path> to override." -ForegroundColor Yellow
    exit 2
}
if (-not (Test-Path $projectRoot)) {
    Write-Host "Project root not found: $projectRoot" -ForegroundColor Red
    exit 2
}

# Test inventory — assertion-based regression tests (return non-zero on FAIL).
# Add new tests to this list; diagnostics live in *_diag.gd and aren't run.
$allTests = @(
    "paint_test",
    "all_layouts_test",
    "visual_render_test",
    "determinism_test"
)

# Resolve which tests to run.
$tests = if ($Test -eq "all") { $allTests } else { @($Test) }

# Pass/fail patterns we trust the tests to print.
$passPattern = "ALL PASS|MAIN TEST PASSED"
$failPattern = "FAIL|MAIN TEST WARNING|MAIN TEST FAILED"

# Build common Godot arg list.
$commonArgs = @("--path", $projectRoot)
if (-not $Windowed) {
    $commonArgs += "--headless"
}

$results  = [ordered]@{}
$failures = 0

foreach ($t in $tests) {
    $script = Join-Path $testsDir "$t.gd"
    if (-not (Test-Path $script)) {
        Write-Host "[$t] SKIP — script not found: $script" -ForegroundColor Yellow
        $results[$t] = "SKIP"
        continue
    }

    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "[$t]" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray

    $argsForTest = $commonArgs + @("--script", "addons/penta_tile/tests/$t.gd")

    # Use Start-Process with redirected stdout/stderr files so we get a
    # reliable ExitCode (PowerShell's `$LASTEXITCODE` after `& ... 2>&1` is
    # unreliable when the captured stream mixes ErrorRecord and string).
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $GodotExe `
            -ArgumentList $argsForTest `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile
        $exit = $proc.ExitCode

        if ($VerbosePreference -eq "Continue") {
            # Verbose: dump everything (stdout then stderr).
            Get-Content $stdoutFile | ForEach-Object { Write-Host $_ }
            Get-Content $stderrFile | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
        } else {
            # Quiet: surface only pass/fail-relevant lines from both streams.
            $lines = @()
            if (Test-Path $stdoutFile) { $lines += Get-Content $stdoutFile }
            if (Test-Path $stderrFile) { $lines += Get-Content $stderrFile }
            $lines | Select-String -Pattern "$passPattern|$failPattern|Sub-test \(c\)" | ForEach-Object {
                $line = $_.Line
                if ($line -match $passPattern) {
                    Write-Host "  $line" -ForegroundColor Green
                } elseif ($line -match $failPattern) {
                    Write-Host "  $line" -ForegroundColor Red
                } else {
                    Write-Host "  $line"
                }
            }
        }
    } finally {
        Remove-Item -ErrorAction SilentlyContinue $stdoutFile, $stderrFile
    }

    if ($exit -eq 0) {
        $results[$t] = "PASS"
    } else {
        $results[$t] = "FAIL (exit=$exit)"
        $failures += 1
    }
}

# Final summary.
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host "Test summary" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor DarkGray
foreach ($t in $results.Keys) {
    $r = $results[$t]
    $color = if ($r -eq "PASS") { "Green" } elseif ($r -eq "SKIP") { "Yellow" } else { "Red" }
    Write-Host ("  {0,-22} {1}" -f $t, $r) -ForegroundColor $color
}
Write-Host ""
if ($failures -eq 0) {
    Write-Host "ALL GREEN ($($results.Count) tests)" -ForegroundColor Green
} else {
    Write-Host "$failures of $($results.Count) FAILED" -ForegroundColor Red
}

# Pause so the window stays open when launched via double-click / explorer.
# -NoPause flag skips this for CI / scripted invocations.
if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to close..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

exit $failures

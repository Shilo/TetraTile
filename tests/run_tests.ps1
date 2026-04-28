# Run PentaTile test suite. PowerShell 5.1 + 7+ compatible.
#
# Usage from project root:
#   .\addons\penta_tile\tests\run_tests.ps1                     # all tests, headless
#   .\addons\penta_tile\tests\run_tests.ps1 -Verbose            # full output
#   .\addons\penta_tile\tests\run_tests.ps1 -Test paint_test    # one test
#   .\addons\penta_tile\tests\run_tests.ps1 -Windowed           # window opens (no --headless)
#   .\addons\penta_tile\tests\run_tests.ps1 -NoPause            # skip the press-any-key
#   .\addons\penta_tile\tests\run_tests.ps1 -GodotExe <path>    # custom Godot executable
#
# Each test exits 0 on PASS, non-zero on FAIL. Runner aggregates and exits with
# the count of failed tests (0 = all green). Pause-at-end fires via try/finally
# so it runs even when the script itself parse-errors or throws mid-run.

[CmdletBinding()]
param(
    [string]$Test = "all",
    [switch]$Windowed,
    [switch]$NoPause,
    [string]$GodotExe = "C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
)

# Exit-code state lives outside the try block so the finally block can read it.
$script:ExitCode = 0

try {
    $ErrorActionPreference = "Stop"

    # Force UTF-8 console output so em-dashes / unicode in test output don't
    # render as Windows-1252 mojibake (the default in legacy PowerShell 5.1
    # console hosts). Set both directions for PS 5.1 robustness.
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {
        # Some restricted hosts disallow setting Console.OutputEncoding;
        # ignore — the rest of the script still works, just with mojibake.
    }

    # Project root = three levels up from this script (addons/penta_tile/tests/).
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
    $testsDir    = Join-Path $projectRoot "addons\penta_tile\tests"

    if (-not (Test-Path $GodotExe)) {
        Write-Host "Godot executable not found at:" -ForegroundColor Red
        Write-Host "  $GodotExe" -ForegroundColor Red
        Write-Host "Pass -GodotExe <path> to override." -ForegroundColor Yellow
        $script:ExitCode = 2
        return
    }

    # Test inventory. Diagnostics live in *_diag.gd and aren't run by this suite.
    $allTests = @(
        "paint_test",
        "all_layouts_test",
        "visual_render_test",
        "strict_pixel_test",
        "determinism_test"
    )

    $tests = $allTests
    if ($Test -ne "all") {
        $tests = @($Test)
    }

    $results  = [ordered]@{}
    $failures = 0

    foreach ($t in $tests) {
        $scriptPath = Join-Path $testsDir ($t + ".gd")
        if (-not (Test-Path $scriptPath)) {
            Write-Host ("[" + $t + "] SKIP - script not found: " + $scriptPath) -ForegroundColor Yellow
            $results[$t] = "SKIP"
            continue
        }

        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host ("[" + $t + "]") -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor DarkGray

        $argsList = @("--path", $projectRoot)
        if (-not $Windowed) {
            $argsList += "--headless"
        }
        $argsList += @("--script", "addons/penta_tile/tests/$t.gd")

        # Use Start-Process with redirected stdout/stderr files so we get a
        # reliable ExitCode (PowerShell's $LASTEXITCODE after `& ... 2>&1` is
        # unreliable when the captured stream mixes ErrorRecord and string).
        $stdoutFile = [System.IO.Path]::GetTempFileName()
        $stderrFile = [System.IO.Path]::GetTempFileName()
        $exit = -1

        try {
            $proc = Start-Process -FilePath $GodotExe -ArgumentList $argsList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
            $exit = $proc.ExitCode

            # Read with explicit UTF-8 encoding via .NET so em-dashes / unicode
            # in test output don't get misinterpreted as Windows-1252 by PS 5.1's
            # Get-Content (which defaults to system codepage). PS 7's Get-Content
            # defaults to UTF-8, but .NET ReadAllLines is consistent across both.
            $allLines = @()
            if (Test-Path $stdoutFile) { $allLines += [System.IO.File]::ReadAllLines($stdoutFile, [System.Text.Encoding]::UTF8) }
            if (Test-Path $stderrFile) { $allLines += [System.IO.File]::ReadAllLines($stderrFile, [System.Text.Encoding]::UTF8) }

            if ($VerbosePreference -eq "Continue") {
                foreach ($line in $allLines) { Write-Host $line }
            } else {
                # Patterns. Order matters — pass takes precedence so "ALL PASS"
                # is green even though it contains "PASS" which info also looks for.
                # FAIL regex uses \b word boundaries so "failures" / "FAILURES"
                # in "failures: 0" / "FAILURES (N)" status lines don't trigger
                # red — only actual failure markers (FAIL [scope], FAIL sub-test,
                # MAIN TEST WARNING, MAIN TEST FAILED) get colored red.
                $passRx = '\bALL PASS\b|MAIN TEST PASSED|: PASS\b'
                $failRx = '\bFAIL\b|MAIN TEST WARNING|MAIN TEST FAILED'
                # Info: per-test counts + sub-test results. Excludes per-run
                # determinism hashes (would flood output with 11 'Run N' lines).
                $infoRx = '^\s*Sub-test |painted display cells|painted: \d|^\s*failures:|cells=\d'
                foreach ($line in $allLines) {
                    if ($line -match $passRx) {
                        Write-Host ("  " + $line) -ForegroundColor Green
                    } elseif ($line -match $failRx) {
                        Write-Host ("  " + $line) -ForegroundColor Red
                    } elseif ($line -match $infoRx) {
                        Write-Host ("  " + $line)
                    }
                }
            }
        } finally {
            Remove-Item -ErrorAction SilentlyContinue $stdoutFile
            Remove-Item -ErrorAction SilentlyContinue $stderrFile
        }

        if ($exit -eq 0) {
            $results[$t] = "PASS"
        } else {
            $results[$t] = "FAIL (exit=" + $exit + ")"
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
        $color = "Red"
        if ($r -eq "PASS") { $color = "Green" }
        elseif ($r -eq "SKIP") { $color = "Yellow" }
        Write-Host ("  {0,-22} {1}" -f $t, $r) -ForegroundColor $color
    }

    Write-Host ""
    $totalCount = $results.Count
    if ($failures -eq 0) {
        Write-Host ("ALL GREEN (" + $totalCount + " tests)") -ForegroundColor Green
    } else {
        Write-Host ($failures.ToString() + " of " + $totalCount.ToString() + " FAILED") -ForegroundColor Red
    }

    $script:ExitCode = $failures
}
catch {
    Write-Host ""
    Write-Host "RUNNER ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    $script:ExitCode = 99
}
finally {
    if (-not $NoPause) {
        Write-Host ""
        Write-Host "Press any key to close..." -ForegroundColor DarkGray
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            # Some hosts (ISE, non-interactive) don't support ReadKey.
            Read-Host "Press Enter" | Out-Null
        }
    }
}

exit $script:ExitCode

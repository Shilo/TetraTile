---
phase: 4
slug: fallback-routing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-29
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Godot 4.6 native — `godot --headless --script <test>.gd` (no GUT, per "works in my game" quality bar) |
| **Config file** | `addons/penta_tile/tests/run_tests.ps1` (registry of all test scripts) |
| **Quick run command** | `& "C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path . --script addons/penta_tile/tests/fallback_routing_test.gd` |
| **Full suite command** | `pwsh addons/penta_tile/tests/run_tests.ps1` |
| **Estimated runtime** | ~6–10 seconds for full suite (17 tests today, 18 after Phase 4) |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the script just touched (or full suite if cross-cutting)
- **After every plan wave:** Run the full suite (`run_tests.ps1`)
- **Before `/gsd-verify-work`:** Full suite must be green AND `04-FALLBACK-UAT.md` signed off
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

> Filled in by the planner. Each task in each PLAN.md must map to a row here OR explicitly declare itself manual-only in the table below.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _planner fills_ | _01_ | _1_ | _PREVIEW-03/04_ | _—_ | _N/A_ | _unit_ | _`godot --headless --script ...fallback_routing_test.gd`_ | _❌ W0_ | _⬜ pending_ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `addons/penta_tile/tests/fallback_routing_test.gd` — composed-canvas test exercising all 8 actually-shipped layouts via `tile_set = null` (5 Phase 2 + Blob47Godot + 2 PixelLab; Tilesetter pair excluded per D-86 b)
- [ ] `addons/penta_tile/tests/run_tests.ps1` — register `fallback_routing_test.gd` so the full-suite command picks it up

*Existing infrastructure (composed-canvas helpers in `comprehensive_bitmask_test.gd` and `penta_ground_hollow_test.gd`) is reused; no new framework install required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fallback eyeball pass on demo | PREVIEW-03 | Visual regression — automated test cannot judge "looks like a tileset" qualitatively | Open `addons/penta_tile/demo/penta_tile_demo.tscn`, swap each of the 8 layouts in turn (set `tile_set = null` first), drag-paint, confirm visible greybox tiles; record sign-off in `04-FALLBACK-UAT.md` |
| `tile_set` user-override regression | PREVIEW-04 | Inspector-driven — confirms `_tile_set_is_fallback` flag flips correctly when user assigns a custom TileSet, then clears it | Open inspector on `PentaTileMapLayer`, assign a custom TileSet → confirm fallback overridden (no warnings); set `tile_set = null` → confirm fallback returns; record in `04-FALLBACK-UAT.md` |
| Cross-AI review (Gemini) findings + dispositions | — (process artifact, not REQ-mapped) | Reviewer output is text, dispositions are human judgment | Run `gemini -p "<prompt>"` per RESEARCH § 3, capture output, classify findings, log dispositions in `04-GEMINI-REVIEW-FIX.md`; atomic commits per applied fix |
| Cross-AI review (Codex) findings + dispositions | — (process artifact, not REQ-mapped) | Reviewer output is text, dispositions are human judgment | Run `/gsd-review codex` (or `codex exec --skip-git-repo-check -` per Phase 3.5 precedent), capture output, classify findings, log dispositions in `04-CODEX-REVIEW-FIX.md`; atomic commits per applied fix |
| Doc-comment sweep coverage | DOC-related (Phase 4 SC #5) | Reviewer-as-validator per D-04-04 — no lint test added | Cross-AI review pass surfaces missed `##` blocks / wrong tag usage as `Doc`-themed findings; sweep summary in `04-DOC-SWEEP.md` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (manual-only tasks for review/UAT/doc-sweep are acceptable per the table above)
- [ ] Wave 0 covers all MISSING references (`fallback_routing_test.gd` + registry update)
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

---
phase: 03-tilebittools-sourced-layouts
verified: 2026-04-29T09:30:00Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: ""
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 3: Public-Convention Layouts (Blob47 + Tilesetter) Verification Report

**Phase Goal (per D-72 retitled ROADMAP.md):** "Public-Convention Layouts (Blob47 + Tilesetter)" — ship layouts whose slot tables are sourced from each format's own primary reference (BorisTheBrave for 47-blob; Tilesetter manual for Tilesetter Wang/Blob), plus a TBT design-inspiration audit deliverable. Greyboxed bitmask PNGs ship for layouts that ship. README.md acknowledges TileBitTools as design inspiration in a 1-line footnote (NO ATTRIBUTION.md).

**D-86 outcome (recorded in STATE.md):** option (b) — Tilesetter layouts deferred to v0.3+. Phase 3 ships ONLY the unblocked deliverables.

**Verified:** 2026-04-29T09:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (anchored on ROADMAP Success Criteria + per-plan must_haves, scoped to D-86 = (b))

| #   | Truth                                                                                                                                                            | Status     | Evidence                                                                                                                                                                                                                                |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | TBT-01: TilesetterWang15 — explicitly deferred to v0.3+ via TBT-01-DEFERRED v2 backlog entry under D-86 = (b)                                                    | VERIFIED   | `.planning/REQUIREMENTS.md:272` declares `TBT-01-DEFERRED`; `.planning/REQUIREMENTS.md:344` Traceability `TBT-01 \| 3 → v0.3+ \| Deferred`; STATE.md TILESETTER_DECISION: b at line 143; no `*tilesetter*` source files in addons/penta_tile/layouts/ |
| 2   | TBT-02: TilesetterBlob47 — explicitly deferred to v0.3+ via TBT-02-DEFERRED v2 backlog entry under D-86 = (b)                                                    | VERIFIED   | `.planning/REQUIREMENTS.md:273` declares `TBT-02-DEFERRED`; `.planning/REQUIREMENTS.md:345` Traceability `TBT-02 \| Deferred`; same evidence chain as #1                                                                                |
| 3   | TBT-03: PentaTileLayoutBlob47Godot ships at the canonical addon path with BorisTheBrave-canonical 7×7 packing + 256→47 collapse + 47-entry dispatch dict        | VERIFIED   | `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` exists (4977 bytes, 112 LOC); class_name + 47-entry `_MASK_TO_ATLAS` + static `_collapse_8bit_moore` + 8 D-76-ordered Moore offsets verified by reading the file; `blob_47_collapse_test` ALL PASS (256 raw masks × dict coverage + size==47 + idempotence + boundary masks); `blob_47_hollow_test` ALL PASS (composed-canvas hollow ring + bbox + hole emptiness + PRE-BAKED W-5 strict equalities) |
| 4   | TBT-04 + DOC-05: README footnote acknowledges TileBitTools as design inspiration; NO ATTRIBUTION.md exists (D-73 final guard)                                    | VERIFIED   | README.md:228 contains `https://github.com/dandeliondino/tile_bit_tools` "Design inspiration for PentaTile's layout-Resource architecture ... no code or data is copied from TBT"; `addons/penta_tile/ATTRIBUTION.md` does NOT exist (verified via ls); 0 occurrences of `tile_bit_tools` string in any file under `addons/penta_tile/` |
| 5   | TEMPLATE-02 (partial): Blob47Godot half ships (bundled PNG); Tilesetter half deferred via TEMPLATE-02-DEFERRED                                                  | VERIFIED   | `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png` exists (224×224 RGBA, 7×7 atlas, 47 grey + 2 transparent slots at (5,6)/(6,6) — visually inspected); `_generate_bitmasks.py` contains `gen_blob_47_godot` + `BLOB_47_GODOT_MASKS` + `draw_47_blob_silhouette`; main() prints "Generated 15 bitmask PNGs"; `bitmask_bounds_test` ALL PASS (Blob47Godot grid=(7,7) slots=49 inspected=47 gaps=2 bounds_fails=0 fullness_fails=0); `.planning/REQUIREMENTS.md:274` declares `TEMPLATE-02-DEFERRED` for Tilesetter half; `.planning/REQUIREMENTS.md:357` Traceability `TEMPLATE-02 \| 3 + 3 → v0.3+ \| Partial` |
| 6   | D-87 8-Moore propagation patch + audit deliverable + 03-CONTEXT.md decisions honored end-to-end                                                                  | VERIFIED   | `_mark_affected_single_grid_cells` at `penta_tile_map_layer.gd:240-249` lists all 4 cardinals + all 4 diagonals (`Vector2i(1, -1)`, `Vector2i(1, 1)`, `Vector2i(-1, 1)`, `Vector2i(-1, -1)`) with D-87 doc-comment; `single_grid_8_moore_propagation_test` ALL PASS (initial=(0,0) post=(0,2)); `03-TBT-DEEP-AUDIT.md` exists (~364 lines, ADOPT/PARTIAL/REJECT classification, AP-1..AP-10 anti-pattern register, 11 patterns audited); ROADMAP Phase 3 retitled "Public-Convention Layouts (Blob47 + Tilesetter)" in 2 places (lines 26, 120); `_decode_tbt_templates.py` does not exist; no `tile_bit_tools/` references in any addon source file |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact                                                                          | Expected                                                                | Status     | Details                                                                                                                                                          |
| --------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd`                    | Single-grid 47-blob layout class — class_name + collapse + dict + virtuals | VERIFIED   | 112 LOC; `class_name PentaTileLayoutBlob47Godot`; 8 D-76 Moore offsets; 47-entry `_MASK_TO_ATLAS`; `static func _collapse_8bit_moore`; `is_dual_grid()=false`; `_default_bitmask_template_path` + `_fallback_atlas_grid_size=Vector2i(7,7)` populated |
| `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png`                   | 224×224 RGBA, 47 grey + 2 transparent slots                              | VERIFIED   | File present (714 bytes); visual inspection of the image confirmed solid grey slots in 7×7 layout with transparent gaps at (5,6) and (6,6); `bitmask_bounds_test` reports `inspected=47 gaps=2 bounds_fails=0 fullness_fails=0` |
| `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png.import`            | Godot import sidecar so layout `load()` works at runtime                  | VERIFIED   | File present (1022 bytes); `blob_47_hollow_test` loads layout + populates fallback codegen + composes canvas successfully — only possible if .import sidecar resolves |
| `addons/penta_tile/_generate_bitmasks.py` (extended)                              | `draw_47_blob_silhouette` + `BLOB_47_GODOT_MASKS` + `gen_blob_47_godot` + main() updated to "15 PNGs" | VERIFIED   | All four substrings present (verified by reading the file); print line 335 reads `Generated 15 bitmask PNGs at:`                                                 |
| `addons/penta_tile/penta_tile_map_layer.gd` (8-Moore patch)                       | `_mark_affected_single_grid_cells` extended from 4 cardinals → 8 Moore neighbors | VERIFIED   | Lines 240-249 contain UP/DOWN/LEFT/RIGHT + 4 diagonals with explicit `# NE / SE / SW / NW` comments; doc-comment lines 230-239 cite D-87 + the 4-cardinal layout no-op rationale via `_paint_via_layout` short-circuit |
| `addons/penta_tile/tests/blob_47_collapse_test.gd`                                | 256→47 collapse coverage + size==47 + idempotence + boundary masks       | VERIFIED   | 70 LOC; enumerates 256 raw masks; asserts dict.size()==47; idempotence on 5 spot values; mask=0 → (0,0); mask=255 → (4,6); test runs ALL PASS                    |
| `addons/penta_tile/tests/blob_47_hollow_test.gd`                                  | Composed-canvas 5×5 hollow-ring regression net                            | VERIFIED   | 180 LOC; uses `extends SceneTree`; composes canvas via blit + bbox + hole emptiness + PRE-BAKED W-5 strict equalities; test runs ALL PASS                        |
| `addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd`                 | Wang2Corner-probe atlas-coord-change regression                          | VERIFIED   | 102 LOC; paints (1,1) then diagonal (0,0); asserts mask flips 0→8 and atlas changes (0,0)→(0,2); test runs ALL PASS; verify-the-regression cycle documented in 03-01-SUMMARY |
| `addons/penta_tile/tests/comprehensive_bitmask_test.gd` (extended)                | Blob47Godot in matrix + 2 new 8-Moore patterns                           | VERIFIED   | preload `_Blob47GodotSc` (line 40); layouts array entry `Blob47Godot` (line 86); `plus_with_diagonals` (line 70-74) + `diag_chain` (line 75-77) added to patterns array; matrix test ALL PASS (6×18=108 combos) |
| `addons/penta_tile/tests/bitmask_bounds_test.gd` (extended)                       | `_check_atlas` `gap_cells` parameter + Blob47Godot 7×7 inspection         | VERIFIED   | Lines 80-85 invoke `_check_atlas("Blob47Godot", ..., Vector2i(7,7), _solid_silhouette, blob_47_godot_gaps)` with `[Vector2i(5,6), Vector2i(6,6)]` whitelist; bounds test ALL PASS |
| `addons/penta_tile/tests/run_tests.ps1`                                           | All 3 new test names registered in `$allTests`                           | VERIFIED   | Lines 66-68 list `blob_47_collapse_test`, `blob_47_hollow_test`, `single_grid_8_moore_propagation_test`; full suite reports `ALL GREEN (15 tests)` |
| `.planning/phases/03-tilebittools-sourced-layouts/03-TBT-DEEP-AUDIT.md` (Wave 0b) | ADOPT/PARTIAL/REJECT classification + AP-1..AP-10 register + backlog seeds + ≥350 lines | VERIFIED   | Audit deliverable present; 11 TBT patterns classified; AP-1..AP-10 register present; 2 backlog seeds (layout tags vocabulary, Project Settings verbosity); ≥350-line gate met (~364 lines per Plan 02 SUMMARY) |
| `README.md` (1-line TBT design-inspiration footnote)                              | "External Resources" section bullet linking dandeliondino/tile_bit_tools  | VERIFIED   | Line 228 contains the link + "Design inspiration for PentaTile's layout-Resource architecture ... no code or data is copied from TBT"; exactly 1 occurrence of `tile_bit_tools` in README                                |
| `.planning/ROADMAP.md` (D-72 retitle)                                             | "Public-Convention Layouts (Blob47 + Tilesetter)" appears in Phases list + detail block | VERIFIED   | 2 occurrences (lines 26, 120); SC#4 references `1-line footnote` + `https://github.com/dandeliondino/tile_bit_tools`; SC#5 cites `_generate_bitmasks.py` (not the obsolete `_generate_greybox_templates.py`) |
| `.planning/REQUIREMENTS.md` (D-72/D-73/D-86 ratification)                         | TBT-04 + DOC-05 rewritten to footnote pattern; v2 backlog has 3 -DEFERRED rows; Out of Scope bans ATTRIBUTION.md + TBT code/data lift | VERIFIED   | TBT-04 (line 155-156) cites README footnote + D-72 + D-73; DOC-05 (line 206-207) cites README footnote + NO ATTRIBUTION.md; v2 Requirements has TBT-01-DEFERRED (272), TBT-02-DEFERRED (273), TEMPLATE-02-DEFERRED (274); Out of Scope (lines 304-305) bans both `addons/penta_tile/ATTRIBUTION.md` and TBT code/data lift |
| `.planning/STATE.md` (D-86 = b sentinel)                                          | TILESETTER_DECISION: b literal sentinel + Phase 3 closure entry          | VERIFIED   | Line 143 contains `TILESETTER_DECISION: b`; line 92 (Roadmap Evolution) records 2026-04-29 Phase 3 closure with reduced scope; line 28 Current Position confirms COMPLETE status |
| `addons/penta_tile/ATTRIBUTION.md`                                                | MUST NOT EXIST (D-73 absolute guard)                                      | VERIFIED ABSENT | `ls addons/penta_tile/ATTRIBUTION.md` returns "No such file or directory"; `git ls-files` does not list it; CLAUDE.md "Coined-Term Discipline" + D-73 final guard honored |

### Key Link Verification

| From                                                | To                                                                              | Via                                              | Status | Details                                                                                                                                                                                                                          |
| --------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------ | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Blob47Godot layout                                   | `penta_tile_map_layer.gd` 8-Moore patch                                         | single-grid pipeline `_paint_via_layout` + `_mark_affected_single_grid_cells` | WIRED  | Layout's `compute_mask` reads 8 Moore offsets; layer marks all 8 in affected set; propagation regression test confirms cell (1,1) re-renders when diagonal (0,0) paints (initial=(0,0) → post=(0,2))                            |
| Blob47Godot layout                                   | bundled bitmask PNG                                                             | `_default_bitmask_template_path` returning `res://...blob_47_godot.png` + base class auto-load in `_init` + `.import` sidecar | WIRED  | `blob_47_hollow_test` exercises the full chain: layout instantiated → `bitmask_template` populated → `get_fallback_tile_set` codegen builds TileSet from PNG → primary_layer renders cells → composed canvas inspection passes |
| `_generate_bitmasks.py`                             | `_MASK_TO_ATLAS` keys in Blob47Godot.gd                                         | mirrored sorted-ascending list (`BLOB_47_GODOT_MASKS`)                        | WIRED  | Python list at lines 290-294 (47 ints, sorted) matches GDScript dict keys at lines 43-56 of layout file; collapse test asserts every raw mask collapses to one of these keys                                                     |
| README footnote                                     | TBT GitHub repo                                                                  | https URL with `target="_blank" rel="noopener"`  | WIRED  | Line 228 has working anchor with the canonical TBT URL; rendered prose "Design inspiration for PentaTile's layout-Resource architecture ... no code or data is copied from TBT"                                                  |
| REQUIREMENTS.md TBT-04                              | README.md design-inspiration footnote                                            | both reference the same TBT GitHub URL + "design inspiration" wording | WIRED  | TBT-04 wording cites `https://github.com/dandeliondino/tile_bit_tools` and "1-line footnote"; matches README text                                                                                                                |
| STATE.md `TILESETTER_DECISION: b` sentinel          | Plan 05 SKIPPED outcome                                                          | grep-target sentinel + Plan 05 conditional checkpoint branch                  | WIRED  | Plan 05 SUMMARY explicitly cites STATE.md line 143 sentinel; no Tilesetter source files exist; ROADMAP Plan 05 entry annotated `[~] SKIPPED`                                                                                    |
| Phase 3 closeout (Plan 06)                          | REQUIREMENTS.md Traceability rows                                                | direct edits per D-86 = b routing                                              | WIRED  | Traceability rows for TBT-01, TBT-02, TBT-03, TBT-04, DOC-05, TEMPLATE-02 all updated to reflect actual outcomes; v2 Requirements gains 3 -DEFERRED rows                                                                          |

### Data-Flow Trace (Level 4)

| Artifact                                  | Data Variable                | Source                                                              | Produces Real Data | Status   |
| ----------------------------------------- | ---------------------------- | ------------------------------------------------------------------- | ------------------ | -------- |
| `penta_tile_layout_blob_47_godot.gd`     | `_MASK_TO_ATLAS` const dict   | hard-coded literal sorted-ascending row-major over 47 collapse-reachable masks | Yes               | FLOWING |
| `gen_blob_47_godot()` (Python)            | `BLOB_47_GODOT_MASKS` list   | hard-coded literal mirroring the GDScript dict keys                  | Yes               | FLOWING |
| Blob47Godot bundled PNG                   | per-cell pixel data          | Pillow draw via `draw_47_blob_silhouette` + `_generate_bitmasks.py` `main()` | Yes               | FLOWING |
| Blob47Godot fallback TileSet              | atlas texture                 | base class `get_fallback_tile_set` codegen from `bitmask_template` + `_fallback_atlas_grid_size=(7,7)` | Yes               | FLOWING |
| `comprehensive_bitmask_test` matrix       | layout × pattern combos       | `layouts` + `patterns` arrays in test (6 layouts × 18 patterns = 108 combos) | Yes (matrix test runs ALL PASS) | FLOWING |

### Behavioral Spot-Checks

| Behavior                                                    | Command                                                                                                                                                       | Result                                            | Status |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ------ |
| 256→47 collapse rule total + dict coverage                   | `Godot --headless --path . --script addons/penta_tile/tests/blob_47_collapse_test.gd`                                                                          | exit 0 / "ALL PASS"                                | PASS   |
| 8-Moore propagation patch correctness                        | `Godot --headless --path . --script addons/penta_tile/tests/single_grid_8_moore_propagation_test.gd`                                                          | exit 0; initial=(0,0) post=(0,2) (mask=8 dispatch) | PASS   |
| Hollow-ring composed-canvas regression net                   | `Godot --headless --path . --script addons/penta_tile/tests/blob_47_hollow_test.gd`                                                                            | exit 0 / "ALL PASS"                                | PASS   |
| Bitmask bounds test (Blob47Godot 7×7 + gap whitelist)        | `Godot --headless --path . --script addons/penta_tile/tests/bitmask_bounds_test.gd`                                                                            | exit 0; Blob47Godot inspected=47 gaps=2 bounds_fails=0 fullness_fails=0 | PASS   |
| Comprehensive matrix (6 layouts × 18 patterns = 108 combos)  | `Godot --headless --path . --script addons/penta_tile/tests/comprehensive_bitmask_test.gd`                                                                     | exit 0 / "ALL PASS"                                | PASS   |
| Full suite                                                   | `powershell -ExecutionPolicy Bypass -File ./addons/penta_tile/tests/run_tests.ps1 -NoPause`                                                                    | exit 0; "ALL GREEN (15 tests)"                     | PASS   |

### Requirements Coverage

| Requirement     | Source Plan | Description                                                                                            | Status                       | Evidence                                                                                                                                                                                       |
| --------------- | ----------- | ------------------------------------------------------------------------------------------------------ | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TBT-01          | 03-05 (skipped) | TilesetterWang15 layout + 5×3 atlas + stray-fill slot                                              | DEFERRED to v0.3+            | Plan 05 SKIPPED per D-86 = (b); REQUIREMENTS.md v2 has TBT-01-DEFERRED entry; Traceability marks `Deferred to v0.3+`. **Not blocking under D-86 = (b) routing.**                                |
| TBT-02          | 03-05 (skipped) | TilesetterBlob47 layout + 11×5 atlas with sub-block gaps                                            | DEFERRED to v0.3+            | Same as TBT-01; tracked as TBT-02-DEFERRED. **Not blocking under D-86 = (b) routing.**                                                                                                          |
| TBT-03          | 03-04        | PentaTileLayoutBlob47Godot — slot table from BorisTheBrave reference                                  | SATISFIED                    | `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` ships; collapse test + hollow test green; matrix integration green                                                              |
| TBT-04          | 03-03        | README footnote acknowledging TBT as design inspiration; NO ATTRIBUTION.md                            | SATISFIED                    | README.md line 228; ATTRIBUTION.md absent; D-73 final guard holds                                                                                                                              |
| TEMPLATE-02     | 03-04 (partial) + 03-05 (skipped) | bundled bitmask PNGs for Phase 3 layouts (Blob47Godot + Tilesetter pair)              | PARTIAL (Blob47Godot half satisfied; Tilesetter half deferred) | Blob47Godot PNG ships at `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png`; bounds test passes; Tilesetter half tracked as TEMPLATE-02-DEFERRED                                  |
| DOC-05          | 03-03        | README External Resources section TBT design-inspiration footnote                                     | SATISFIED                    | Same evidence as TBT-04 (intentional duplication per REQUIREMENTS.md cross-reference)                                                                                                          |

**Coverage matches expected per D-86 = (b):** 4 of 6 satisfied (TBT-03, TBT-04, DOC-05, TEMPLATE-02 partial); 2 explicitly deferred (TBT-01, TBT-02); 1 partial routing the rest of TEMPLATE-02 to v2 backlog. No orphaned requirements. No requirements claimed satisfied without evidence.

### Anti-Patterns Found

Scan target files (modified in Phase 3 per SUMMARY key-files): `penta_tile_layout_blob_47_godot.gd`, `penta_tile_map_layer.gd` (lines 220-280 only — patch surface), `_generate_bitmasks.py` (Blob47 additions only), 3 new tests, `comprehensive_bitmask_test.gd`, `bitmask_bounds_test.gd`, `run_tests.ps1`, `README.md`, `.planning/{ROADMAP,REQUIREMENTS,STATE}.md`, `03-TBT-DEEP-AUDIT.md`.

| File                                       | Line     | Pattern                                              | Severity   | Impact                                                                                                                                                                                                                                |
| ------------------------------------------ | -------- | ---------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| (none in Blob47Godot layout)               | —        | No `tile_bit_tools/` references; no `randi()`; no `TODO/FIXME/PLACEHOLDER`; no `transform_flags!=0`; no `_pack_alternative` invocation | (none)     | D-73 / Pitfall #2 / Pitfall #1 / D-77 all honored                                                                                                                                                                                     |
| (no ATTRIBUTION.md)                        | —        | File does NOT exist                                  | (none)     | D-73 absolute guard holds                                                                                                                                                                                                            |
| (no `_decode_tbt_templates.py`)            | —        | File does NOT exist                                  | (none)     | D-73 absolute guard holds                                                                                                                                                                                                            |
| (no Tilesetter source files in addons)     | —        | Files do NOT exist                                   | (none)     | D-86 = (b) routing honored — no Tilesetter half shipped                                                                                                                                                                              |

**Anti-pattern scan returned zero blockers, zero warnings, zero info-level findings on the modified-files set.**

### Critical Pitfall Cross-Check (CLAUDE.md "Critical Pitfalls")

| Pitfall  | Description                                                  | Status in Phase 3                                                                                                                                                                                                                                                  |
| -------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| #1       | `alternative_tile` bit packing                               | Honored — every Blob47Godot slot has `transform_flags=0` and `alternative_tile=0` explicit; D-77 forbids rotation reuse for blob layouts; no `_pack_alternative` call in new code                                                                                  |
| #2       | Variation determinism (no `randi()`)                         | Honored — `grep -c "randi(" ` on all 3 new tests + Blob47 layout = 0; collapse table is pure-math; no nondeterministic hash                                                                                                                                       |
| #4       | Setter loops + `Resource.changed` storms                     | Not touched — Blob47Godot has no `@export` properties beyond inherited base, inherits base setter idempotence; pipeline patch only adds 4 lines to existing function                                                                                              |
| #8       | Single-grid logic-painted gate                                | Honored — `_paint_via_layout` short-circuit at line 272 unchanged; new 8-Moore extension covered explicitly in doc-comment ("4-cardinal layouts the extra diagonal cells in the affected set hit the line-262 short-circuit and render nothing — net behavior unchanged") |
| #9       | Single-grid mask=0 dispatch                                   | Honored — Blob47Godot's `mask_to_atlas(0)` dispatches to `Vector2i(0, 0)` (the lonely-tile slot per D-80); collapse test asserts this directly; never returns null                                                                                                |
| #10      | Penta canonical-silhouette enforcement                        | N/A — Phase 3 ships only Blob47Godot which has no rotation reuse                                                                                                                                                                                                  |

All applicable pitfalls honored; no new pitfalls introduced.

### Coined-Term Discipline (CLAUDE.md)

- **Penta** is reserved for the 5-archetype tileset format. Blob47Godot is named for the format ("Blob47 from the Godot ecosystem convention"), not coined as a Penta concept.
- All new class names use the `PentaTile*` prefix (`PentaTileLayoutBlob47Godot`) — project namespace, not semantic Penta.
- No new `PentaCache`, `PentaDecoder`, etc. — the audit deliverable explicitly REJECTs adopting TBT class names into PentaTile (AP-8 in the AP-1..AP-10 register).

### LOC Tracking (Identity Guardrail)

Direct measurement at Phase 3 close:
```
git ls-files addons/penta_tile | grep -E '\.gd$' | grep -v 'tests/' | grep -v 'demo/' | xargs wc -l
```
Result: **2455 runtime LOC** (matches Plan 06 SUMMARY).

- Phase 2 close baseline: 1827.
- Phase 3 actual additions: +9 (Plan 01 8-Moore patch) + 112 (Plan 04 Blob47Godot) = +121 LOC.
- Methodology drift: ~507 LOC gap between 1827 baseline + 121 actual additions vs 2455 measurement; documented transparently in Plan 06 SUMMARY + STATE.md as historical counting-convention drift, NOT unreported code growth.
- Identity guardrail status: **AT RISK carry-forward** (consistent with Phase 2 close) — formal gate is Phase 5 final audit. Not blocking for Phase 3.

### Human Verification Required

Phase 3 ships only one new layout (Blob47Godot) with comprehensive automated regression coverage:
- Pure-math collapse rule fully exercised (256 raw masks × 47 dict keys × idempotence × boundary masks)
- Composed-canvas hollow regression net with PRE-BAKED W-5 strict equalities (CLAUDE.md Test Methodology #1)
- 8-Moore propagation regression test (verify-the-regression cycle confirmed in Plan 01 SUMMARY)
- Pattern × layout matrix extended (6×18=108 combos) including 2 new 8-Moore-revealing patterns (`plus_with_diagonals`, `diag_chain`)
- Bitmask bounds test verifies the bundled PNG's atlas occupancy with explicit gap whitelist

The automated tests are sufficient to verify the goal — they compose actual rendered output and assert structural invariants per CLAUDE.md Test Methodology #1-6, replicating the lessons learned from Phase 2's UAT cycle. **No outstanding human verification items.**

Optional visual UAT (not blocking): a user with a real artist-authored 47-blob atlas can paint a fixture in the demo scene to confirm visual correctness — but the bundled fallback codegen path is exercised by `blob_47_hollow_test` which composes the rendered canvas and asserts hole emptiness and bbox correctness.

### Gaps Summary

No gaps. All must-haves verified. The phase is closed under D-86 = (b) reduced scope per the locked decision (recorded in STATE.md TILESETTER_DECISION: b 2026-04-29). Tilesetter pair deferred to v0.3+ via TBT-01-DEFERRED / TBT-02-DEFERRED / TEMPLATE-02-DEFERRED v2 backlog entries — these are explicit deferrals captured in the active forward-tracking surface, not silent gaps.

**Phase 4 (Fallback Routing) is the next planning step per ROADMAP execution order.**

---

*Verified: 2026-04-29T09:30:00Z*
*Verifier: Claude (gsd-verifier)*

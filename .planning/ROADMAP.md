# Roadmap: PentaTile v0.2.0

**Milestone:** v0.3.0 — "Terrain + Variation + VirtuMap Integration"
**Created:** 2026-04-30 (transitioned from v0.2.0 which shipped 2026-04-29)
**Granularity:** standard

## Overview

PentaTile v0.1.0 ships a single hardcoded atlas convention — 4 tiles in the "penta" order (Fill / Inner Corner / Border / Outer Corner). Atlases authored anywhere else (Tilesetter, OpenGameArt's 47-blob, Godot's stock terrain templates, the broader pixel-art ecosystem) don't drop in.

v0.2.0 ships a **library of pluggable layout Resources**. Every popular Godot autotiling atlas convention becomes a `PentaTileLayout` subclass. Drop a fresh `PentaTileMapLayer` into a scene, attach a layout Resource, and either bring your own atlas or use the layout's bundled fallback TileSet for instant prototyping. No bitmask authoring per tile, no peering bits.

The five-phase plan lands the contract + base layout class first (gates everything), then ships the three PentaTile-native layouts (DualGrid16, Wang2Edge, Wang2Corner), then transcribes TileBitTools' MIT-licensed slot tables for the three Blob/Wang layouts (Blob47Godot, TilesetterWang15, TilesetterBlob47), then wires the fallback-TileSet routing for prototyping UX, then closes with a demo refresh and the GitHub release.

The original v0.2 feature pillars (Y-axis variation, top tiles, non-rotating tilesets) are now in v2 backlog. "Non-rotating" is largely *delivered* by the new layouts since DualGrid16 / Wang2Corner / Wang2Edge are explicitly per-direction-authored. Variation and top tiles need their own design discussion against the new layout shape.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4, 5): Planned milestone work
- Decimal phases (e.g. 3.5): Reserved for inserts that extend an adjacent integer phase without renumbering. Currently in use: 3.5 (PixelLab layouts, extends Phase 3). Phase 2.1 was inserted 2026-04-26 then **collapsed into Phase 2** on 2026-04-26 when the Penta layout absorbed Single-Tile mode via auto-detect.

- [x] **Phase 1: Contract Skeleton + Penta Layouts** — Introduce `PentaTileAtlasContract` + `PentaTileLayout` base + `AtlasSlot`. Ship Penta Horizontal + Penta Vertical as the first two layout subclasses. v0.1 visuals continue unchanged via the bundled default contract OR the null-fallback path.
- [x] **Phase 1.1: PentaTile Rename + Penta Codename Establishment** — Project-wide rename to `PentaTile` (source code, saved resources, planning + project docs, GitHub repo, local clone, Claude memory) before Phase 2 ships new files under the old name. "Penta" coined as the 5-archetype tileset codename via canonical README anchor + CLAUDE.md project invariant. CHANGELOG.md ships the v0.2 BREAKING entry.
- [x] **Phase 2: Native Layouts + Penta Synthesis (1/2/3/4/5 auto-detect)** — Ship DualGrid16, Wang2Edge, Wang2Corner, Min3x3 subclasses. Plus the architectural pivot: Phase 1's `PentaTileLayoutPentaHorizontal`/`Vertical` are merged into a single `PentaTileLayoutPenta` class with `axis: Axis` enum and `tile_count: TileCountMode { AUTO, AUTO_STRIP, ONE, TWO, THREE, FOUR, FIVE }` enum — five progressive synthesis modes per strip with AUTO/AUTO_STRIP detection variants. Runtime overlay layer DELETED entirely (single-layer dispatch only). New slot ordering: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`; OuterCorner is implicit (synthesized from slot 0). Closed 2026-04-28 after the UAT bug-fix sweep (7 bug classes across commits 6553380..205fb67) — see `.planning/phases/02-native-layouts/02-UAT-LESSONS-LEARNED.md`. Companion artifact: `.planning/research/layouts/RPG_MAKER.md` documents the deferred RPG Maker family for v0.3+.
- [x] **Phase 3: Public-Convention Layouts (Blob47 only; Tilesetter deferred to v0.3+ per D-86 b)** — Shipped `PentaTileLayoutBlob47Godot` (BorisTheBrave 7×7 + algorithmic 256→47 collapse rule + 47-entry dispatch dict), 8-Moore single-grid propagation patch, TBT design-inspiration audit (`03-TBT-DEEP-AUDIT.md`), README "External Resources" footnote acknowledging TileBitTools (NO `addons/penta_tile/ATTRIBUTION.md` per D-73), and the closeout matrix-test extension. **Plan 05 SKIPPED** per D-86 user decision (option b — Tilesetter primary source not located in plan-phase research; deferred to v0.3+). TBT-01 / TBT-02 / Tilesetter half of TEMPLATE-02 carry forward as `TBT-01-DEFERRED` / `TBT-02-DEFERRED` / `TEMPLATE-02-DEFERRED` in REQUIREMENTS.md v2 backlog.
- [x] **Phase 3.5: PixelLab Layouts (variation-bank pick deferred to v2 per D-91)** — Shipped `PentaTileLayoutPixelLabTopDown` and `PentaTileLayoutPixelLabSideScroller` (8×8 atlas, single-grid, 4-bit corner mask). Both share the locked role-to-mask bijection from spike 003 and dispatch via cached `_first_cell_by_mask` (first-cell row-major pick per D-89). The "+ Variation-Seed Wiring" suffix from the original phase title was a v0.2 misnomer — `variation_seed` property NOT exposed; bank-pick wiring deferred to v2 backlog as VAR-PIXEL-01 (design-coupled with VAR-01 + MULTITERR-01). Min3x3 already shipped in Phase 2 — no Phase 3.5 work needed. (Closed 2026-04-29.)
- [x] **Phase 4: Fallback Routing + Doc Sweep + Cross-AI Review** — Three braided deliverables before v0.2.0 closes. (1) **Routing close-out:** PREVIEW-03/04 verified across all 8 actually-shipped layouts via composed-canvas test (`fallback_routing_test.gd`) + manual demo eyeball pass per D-04-06 belt+suspenders. (2) **Doc-comment sweep** of all 12 addon scripts per [Godot's official format](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) — class-level + every public method + every `@export` property; `@experimental` on `PentaTileLayout` abstract base. (3) **Two-pass cross-AI review with fixes:** Gemini → fix → Codex → fix; severity-tiered fix policy (Critical/High auto, Medium gated, Low/Info logged); standard disqualification list rejected compat-shim / forward-compat / Phase 5 / v0.3+/v2 / ATTRIBUTION.md / Coined-Term / locked-decision findings. Gemini pass returned `status: clean` (0 findings). Codex pass DEFERRED at closeout due to a hard external CLI quota wall (RESEARCH § 8 Pitfall #14; user elected to skip and continue per `AskUserQuestion`); prompt preserved at `04-CODEX-PROMPT.md` for re-use when quota resets. Phase ships with single-pass cross-AI coverage. All 4 closeout artifacts committed (`04-FALLBACK-UAT.md` + `04-DOC-SWEEP.md` + `04-GEMINI-REVIEW-FIX.md` + `04-CODEX-REVIEW-FIX.md`); 18 automated tests green. Closed 2026-04-29.
- [x] **Phase 5: Demo Refresh + Documentation + Release** — Closed 2026-04-29. v0.2.0 shipped via release workflow run 25131034672 (44s wall-clock). 8-instance demo grid (every instance uses bundled fallback per DEMO-02); README extensions (Layouts / Upgrading / Authoring a Custom Layout / Identity & Footprint); accumulated CHANGELOG; auto-bumped plugin.cfg + git tag `v0.2.0` + GitHub Release zip published at https://github.com/Shilo/PentaTile/releases/tag/v0.2.0. 58 / 58 v1 requirements satisfied. Identity audit per D-05-11: `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md` outcome SHIP (clean hot path + 16/16 anti-patterns absent; +758 LOC delta vs TileMapDual is signal not verdict).

## Phase Details

### Phase 1: Contract Skeleton + Penta Layouts

**Goal**: A typed `PentaTileAtlasContract` Resource owning a `PentaTileLayout` reference is the source of truth for atlas shape; v0.1 scenes that don't migrate continue to render unchanged via either the bundled default contract OR the null-fallback path.

**Depends on**: Nothing (first phase).

**Requirements (residual, after Phase 2 supersession)**: LAYOUT-01, LAYOUT-02, LAYOUT-05 — the 3 base-layout virtuals + `_pack_alternative()` helper that Phase 2 inherits unchanged. *Originally also covered: CONTRACT-01..05 (now deleted in Phase 2 LAYER-01..03), PENTA-01..03 (now reworked in Phase 2 with merged `PentaTileLayoutPenta` + new slot ordering), LAYOUT-03/04 (now revised in Phase 2 — bitmask_template rename, AtlasSlot field deletion), PREVIEW-01 (now revised in Phase 2 — bitmask_template rename). See traceability table for current status of these IDs.*

**Success Criteria (Phase 1, as-shipped)**:
1. ✓ The PentaTileLayout base class can be subclassed; instances of `PentaTileLayoutPentaHorizontal` / `Vertical` appear correctly in the inspector picker for the contract's `layout` slot.
2. ✓ Setting `atlas_contract` to the bundled default produces visuals bit-identical to v0.1 (verified at Phase 1 close, 26/26 tests passing).
3. ✓ Idempotence guard + signal-storm protection on the contract setter (verified at Phase 1 close).
4. ✓ End-of-Phase-1 LOC checkpoint: logged in the phase summary; no LOC explosion.

> Phase 1 is shipped but **partially superseded by Phase 2** (8 of its 14 reqs are reopened). The successes above remain factual records of what Phase 1 delivered; the reopened reqs (CONTRACT-*, PENTA-01..03, LAYOUT-03/04, PREVIEW-01) are tracked in Phase 2's scope.

**Plans**: 5 plans
Plans:
- [x] 01-01-PLAN.md — Wave 0: capture v0.1 baselines + LOC snapshot + _rebuild_count instrumentation + ROADMAP/REQUIREMENTS expansion (D-27)
- [x] 01-02-PLAN.md — Wave 1: Resource skeleton (PentaTileAtlasSlot + PentaTileLayout base + PentaTileAtlasContract with locked D-08 setter)
- [x] 01-03-PLAN.md — Wave 2: Concrete layout subclasses (PentaTileLayoutPentaHorizontal with relocated 16-state match + PentaTileLayoutPentaVertical axis-swap subclass)
- [x] 01-04-PLAN.md — Wave 3: Layer dispatcher rewrite (hard-remove enum + atlas_layout export, add atlas_contract setter, _resolve_layout lazy singleton, dual+single grid pipeline branch)
- [x] 01-05-PLAN.md — Wave 4: Bundled .tres files + demo wiring + visual regression + idempotence/storm test + LOC checkpoint

### Phase 1.1: PentaTile Rename + Penta Codename Establishment (INSERTED)

**Goal:** Project-wide rename PentaTile → PentaTile (source code, saved Godot resources, planning + project docs, GitHub repo, local clone directory, Claude memory directory) BEFORE Phase 2 ships new files under the old name. Coin "Penta" as the canonical codename for the 5-archetype tileset format via a load-bearing README definition ("What is a Penta tileset?") + a CLAUDE.md project invariant ("Coined-Term Discipline"). No backwards-compat shims per the no-compat policy; CHANGELOG documents the breakage.
**Requirements**: NONE — rename phase, no formal REQ-IDs (success measured by CONTEXT.md scope items and goal-backward must_haves in each plan)
**Depends on:** Phase 1
**Plans:** 3 plans complete (3/3)
**Completed:** 2026-04-26

Plans:
- [x] 01.1-01-source-and-resources-PLAN.md — Source code + saved Godot resources rename (atomic across two consecutive commits)
- [x] 01.1-02-docs-and-codename-anchors-PLAN.md — Planning + project docs sweep + README "What is a Penta tileset?" + CLAUDE.md "Coined-Term Discipline" + CHANGELOG.md
- [x] 01.1-03-repo-git-memory-and-verify-PLAN.md — GitHub rename + git remote retarget + local dir + Claude memory migration + final verification

### Phase 2: Native Layouts + Architectural Simplification

**Goal**: Four native layout subclasses (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) ship with hand-authored slot tables. **Plus a sweeping architectural simplification** locked in 2026-04-26 after four iterations of design refinement:

1. **Merge** Phase 1's `PentaTileLayoutPentaHorizontal` + `PentaTileLayoutPentaVertical` into a single `PentaTileLayoutPenta` class with `axis: Axis` enum
2. **Add** `tile_count: TileCountMode` enum (`AUTO`, `AUTO_STRIP`, `ONE`/`TWO`/`THREE`/`FOUR`/`FIVE`) — five progressive modes via auto-detect, plus per-strip detection variant
3. **New slot ordering**: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. OuterCorner is implicit (synthesized from slot 0's corners across all modes; no dedicated slot).
4. **Synthesize missing archetypes** at load time per mode (drops the runtime overlay layer entirely)
5. **Delete** `PentaTileAtlasContract` — `layout: PentaTileLayout` directly on `PentaTileMapLayer` (no version field, no contract wrapper)
6. **Rename** `template_image` → `bitmask_template` (single image serves as inspector preview AND fallback TileSet source — no atlas/bitmask split). **Hide** `fallback_tile_set` from inspector. **Delete** speculative `decoder_image`.
7. **Co-locate bundled bitmask PNGs** next to layout `.gd` files. Penta has 10 PNGs in `penta_tile_layout_penta/` subfolder (5 modes × 2 axes); single-variant layouts use flat siblings. The `templates/` folder is deleted entirely.
8. **Delete** the entire `addons/penta_tile/contracts/` folder + `penta_tile_atlas_contract.gd` + the original v0.1 `penta_tile_template.png`

This phase supersedes Phase 1's CONTRACT-* (deleted), separate Penta H/V classes (merged), `template_image` naming (renamed), `fallback_tile_set` @export (hidden), `decoder_image` (deleted), and the previously-planned Penta5-as-separate-class + Phase 2.1 SingleTile-as-separate-class plans. Per the [no-backwards-compat AND no-forward-compat policy](../../CLAUDE.md#breaking-changes-policy-hard-rule), all of this proceeds without compat shims; CHANGELOG documents the breakage.

**Depends on**: Phase 1 (layout dispatch foundation; Phase 2 modifies but doesn't replace it).

**Requirements**: NATIVE-01..03, MIN3x3-01, LAYER-01..05, LAYOUT-03/04/06/07, PENTA-01..03, PENTA-SYNTH-01..12, PREVIEW-01..02, TEMPLATE-01/03/04.

**Success Criteria** (what must be TRUE):
1. DualGrid16 layout, with a 16-tile authored atlas, paints all 16 mask states correctly (corner-mask TL=1/TR=2/BL=4/BR=8).
2. Wang2Edge layout paints all 16 edge-mask states correctly (CR31 N=1/E=2/S=4/W=8); edges form lines/paths.
3. Wang2Corner layout produces visuals identical to DualGrid16 on the same atlas data — different bit naming, same silhouettes.
4. Min3x3 layout, with a 9-tile authored atlas, paints all 16 edge-mask states correctly (single-grid, T=1/E=2/B=4/W=8 mask).
5. **Single `PentaTileLayoutPenta` class** with `axis: Axis` and `tile_count: TileCountMode` enums replaces Phase 1's two separate classes. Inspector shows: `axis` (HORIZONTAL/VERTICAL), `tile_count` (AUTO/AUTO_STRIP/ONE/TWO/THREE/FOUR/FIVE), `description`. `bitmask_template` hidden via `_validate_property` (auto-resolved per axis × mode).
6. **AUTO mode auto-detect** correctly maps atlas axis size 1/2/3/4/5 to ONE/TWO/THREE/FOUR/FIVE uniformly across all strips. Other axis sizes (0, 6+) → render disabled + warning. NO pixel inspection.
7. **AUTO_STRIP mode** independently detects each strip's tile count via `has_tile()` checks. Different strips can use different modes within a single atlas.
8. **ONE prototyping mode**: 1-wide atlas with one isolated-cell-with-all-edges-and-corners tile renders all 16 mask states without broken seams. Visible regions tested: isolated cell, strip, L-shape, filled rectangle.
9. **FIVE mode pure-authored**: 5-wide atlas with all 5 archetypes hand-drawn renders all 16 mask states without any synthesis (only OuterCorner derived from slot 0).
10. **TWO/THREE/FOUR mid-tier modes** synthesize the missing archetypes from slot 0 and render all 16 mask states correctly. Visual quality progressively improves with each added explicit slot.
11. **`PentaTileAtlasContract` class deleted**, `addons/penta_tile/contracts/` folder deleted, `addons/penta_tile/penta_tile_template.png` (original v0.1 reference) deleted. `PentaTileMapLayer.layout: PentaTileLayout` is the only resource property.
12. **Overlay layer removed**: `PentaTileMapLayer._overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, and `AtlasSlot.diagonal_complement_atlas_coords` all deleted. `PentaTileMapLayer` has exactly ONE child visual layer.
13. **Synthesis collision support**: source tile collision/occlusion/navigation polygons copied to synthesized tiles with appropriate transforms. Animation/custom-data/probability/y-sort NOT copied (documented as a layout-choice tradeoff).
14. **Bundled PNGs co-located**: `addons/penta_tile/layouts/penta_tile_layout_penta/{one,two,three,four,five}_{horizontal,vertical}.png` (10 PNGs) + `addons/penta_tile/layouts/penta_tile_layout_<slug>.png` (4 single-variant PNGs for DualGrid16, Wang2Edge, Wang2Corner, Min3x3). Existing `templates/` folder deleted. Bitmask generator script updated to produce new structure.
15. **`get_fallback_tile_set()` virtual** on `PentaTileLayout` base class returns a runtime-generated TileSet from the layout's `bitmask_template` (the SAME image that's the inspector preview — single image, both roles). No `.tres` fallback files needed.
16. **Demo scene loads cleanly after Wave 2** (LAYER-04). `addons/penta_tile/demo/penta_tile_demo.tscn` is rebound from `atlas_contract = ExtResource(default_horizontal.tres)` to the new `layout: PentaTileLayout` API atomically with the contract deletion. Wave 2 acceptance criterion — non-skippable.
17. **Phase 1 verification suite migrated** (LAYER-05). The 26/26 tests at `.planning/phases/01-contract-skeleton-penta-layouts/01-VERIFICATION.md` reference `atlas_contract` and the deleted `PentaTileLayoutPentaHorizontal` / `Vertical` class names. Phase 2 Wave 1 migrates them to the new API; new tests added for TWO/THREE/FIVE modes + AUTO_STRIP. Don't let the planner assume Phase 1 tests just keep passing.

**Plans**: 7 plans complete (7/7) — code-complete, awaiting visual UAT
Plans:
- [x] 02-01-PLAN.md — Wave 0/1: AtlasSlot trim + bitmask_template rename + LAYER-05 verification migration spec + get_fallback_tile_set virtual stub
- [x] 02-02-PLAN.md — Wave 2: PentaTileSynthesis engine (Liang-Barsky polygon clipper, Gate 1 Path B OuterCorner-from-slot-0, Gate 2 transform order TRANSPOSE→FLIP_H→FLIP_V, signature-based idempotence, build_tile_set_from_synthesis)
- [x] 02-03-PLAN.md — Wave 3: PentaTileLayoutPenta merged class (axis × tile_count enums, AUTO_STRIP=-1 sentinel, _BITMASK_TEMPLATE_LOOKUP with Vector2i keys [H-4 fix], _validate_property hides bitmask_template via bitwise-clear [H-1 fix], _make_slot)
- [x] 02-04-PLAN.md — Wave 4: 4 native layouts atomic (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) committed in 91f69a2
- [x] 02-05-PLAN.md — Wave 5: bundled bitmask PNGs co-located (10 Penta + 4 flat siblings) + _generate_bitmasks.py rewritten + README image retargets
- [x] 02-06-PLAN.md — Wave 6: AUTO/AUTO_STRIP detection + configuration warnings delegation + FOUR-mode demo binding + FOUR-mode regression baseline
- [x] 02-07-PLAN.md — Wave 7: LOC checkpoint (1827 runtime LOC, 31% over ~1500 trigger; AT RISK noted for Phase 5 final audit) + determinism test PASS (BASELINE_HASH=2986698704)

**Post-execution review** (3 passes, all clean): initial review (commit `eec027d`) found 6 Warnings (WR-01..WR-06); independent third-party audit added WR-07 (latent VERTICAL BLOCKER — `_make_slot` returned wrong axis); all 7 WR fixes landed across commits `ea0ba23` `ae5d787` `9ca342e` `d74df0e` `2ca04e0` `720f017` `79af1e3`. VERTICAL regression net + sub-test (c) added in commit `673ace0`. Re-review (`49852b9`) added IN-10. Third pass (`aa07ac1`) added IN-11/12/13, all 3 fixed in `c9a6aa9`. **Final review status:** 0 Critical / 0 Warning / 13 Info. **Outstanding gates:** (1) human visual UAT — 4 items in `02-HUMAN-UAT.md`, (2) LOC overage acceptance decision (informational at Phase 2; formal gate is Phase 5).

### Phase 3: Public-Convention Layouts (Blob47 + Tilesetter)

**Goal**: Three layouts whose slot tables are sourced from each format's primary reference: `PentaTileLayoutBlob47Godot` from BorisTheBrave's 47-blob reference (`https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html`), `PentaTileLayoutTilesetterWang15` and `PentaTileLayoutTilesetterBlob47` from Tilesetter's manual + the user's own export sample (D-86 outcome). Co-located bitmask PNGs are generated for all three. A single-line README footnote acknowledges TileBitTools as design inspiration; per D-73 no code or data is lifted from TBT — the audit deliverable `03-TBT-DEEP-AUDIT.md` reads TBT source but produces only ideas/recommendations.

**Depends on**: Phase 1 (layout dispatch). Independent of Phase 2 in principle, but sequenced after to keep the dependency chain linear.

**Requirements**: TBT-01, TBT-02, TBT-03, TBT-04, TEMPLATE-02, DOC-05.

**Success Criteria** (what must be TRUE):
1. `PentaTileLayoutTilesetterWang15`'s slot table is sourced from Tilesetter's primary reference (D-75 outcome) (15 entries plus the stray-fill handling); a hand-painted Tilesetter Wang atlas attached to this layout paints correctly across all 15 mask states.
2. `PentaTileLayoutTilesetterBlob47`'s slot table is sourced from Tilesetter's primary reference (D-75 outcome) (47 entries in the 11×5 atlas with sub-block gaps); a hand-painted Tilesetter Blob atlas paints correctly across all 47 mask states.
3. `PentaTileLayoutBlob47Godot`'s slot table is sourced from BorisTheBrave's 47-blob reference (D-74); a 47-tile atlas authored to that convention paints correctly across all 47 mask states.
4. `README.md` "External Resources" section contains a 1-line footnote acknowledging TileBitTools (https://github.com/dandeliondino/tile_bit_tools) as design inspiration. Per D-73, NO `addons/penta_tile/ATTRIBUTION.md` is created — nothing is lifted from TBT, so nothing requires attribution. The audit deliverable `.planning/phases/03-tilebittools-sourced-layouts/03-TBT-DEEP-AUDIT.md` reads TBT source for design analysis only.
5. The 3 missing template PNGs (`tilesetter_wang_15.png`, `tilesetter_blob_47.png`, `blob_47_godot.png`) are produced by `_generate_bitmasks.py` (deterministic, regenerable) and committed alongside the layout Resources.

**Plans**: 6 plans

Plans:
- [x] 03-01-PLAN.md — Wave 1 prereqs: D-86 user gate (checkpoint:decision) + 8-Moore single-grid pipeline patch + propagation regression test (D-87)
- [x] 03-02-PLAN.md — Wave 1 deliverable: 03-TBT-DEEP-AUDIT.md ADOPT/PARTIAL/REJECT pattern audit (D-84, no code/data lift)
- [x] 03-03-PLAN.md — Wave 1 doc rewrites: ROADMAP/REQUIREMENTS retitle + TBT-04/DOC-05 rewrite + README footnote (D-72, D-73; no ATTRIBUTION.md)
- [x] 03-04-PLAN.md — Wave 2: PentaTileLayoutBlob47Godot (BorisTheBrave 7×7 + 256→47 collapse + 47-entry dict) + collapse test + hollow test + bundled PNG (TBT-03, TEMPLATE-02 partial)
- [~] 03-05-PLAN.md — SKIPPED per D-86 resolution (option b — Tilesetter layouts deferred to v0.3+; TBT-01/TBT-02/Tilesetter half of TEMPLATE-02 → v2 backlog)
- [x] 03-06-PLAN.md — Wave 4 closeout: comprehensive_bitmask_test + bitmask_bounds_test extended with Blob47Godot; REQUIREMENTS Traceability + v2 deferred-backlog entries; ROADMAP [x] + STATE.md cumulative LOC + Phase 3 closure

### Phase 3.5: PixelLab Layouts + Variation-Seed Wiring

**Goal**: Ship `PentaTileLayoutPixelLabTopDown` and `PentaTileLayoutPixelLabSideScroller` subclasses. Both consume PixelLab Aseprite plugin native 8×8 atlas output. Both share the locked role-to-mask bijection `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]` (corner mask). **Variation handling for v0.2 is first-cell row-major pick only** — when multiple cells map to the same mask, `mask_to_atlas` returns the row-major-first cell (D-89). The `variation_seed` deterministic-hash bucket-pick is **deferred to v2 backlog as VAR-PIXEL-01** per D-91 — design-coupled with VAR-01 (Y-axis variation) and MULTITERR-01 (multi-terrain).

**Depends on**: Phase 1 (architecture), Phase 2 or Phase 3 (single-grid pipeline first consumed by Wang2Corner in Phase 2).

**Requirements**: PIXLAB-01, PIXLAB-02, PIXLAB-03, PIXLAB-04. (VAR-PIXEL-01 deferred to v2 backlog per D-91 — see REQUIREMENTS.md "v2 Requirements" section.)

**Success Criteria** (what must be TRUE):
1. `PentaTileLayoutPixelLabTopDown.compute_mask` and `mask_to_atlas` consume the locked role-to-mask mapping; visual regression on a PixelLab 8×8 sample matches the Aseprite plugin output.
2. `PentaTileLayoutPixelLabSideScroller` shares the role-to-mask mapping; cell-to-role differs (the side-scroller variant). Visual regression on a side-scroller PixelLab 8×8 sample passes.
3. Variation handling: when a mask has multiple cells (PixelLab variations), `mask_to_atlas` returns the row-major-FIRST cell deterministically (D-89). Bank pick (`hash(coord, variation_seed) % cells.size()`) is deferred to v2 — `VAR-PIXEL-01` in REQUIREMENTS.md.
4. ~~`variation_seed` produces different picks for different seed values~~ — **DEFERRED to v2 (VAR-PIXEL-01)** per D-91. v0.2 Phase 3.5 ships first-cell pick only.

**Plans**: 6 plans complete (6/6) — closed 2026-04-29

Plans:
- [x] 03.5-01-PLAN.md — Generator extension: gen_pixel_lab_top_down + gen_pixel_lab_side_scroller in _generate_bitmasks.py + 2 bundled PNGs at 256×256 + .import sidecars (TEMPLATE-01 partial — PixelLab half)
- [x] 03.5-02-PLAN.md — PentaTileLayoutPixelLabTopDown shipping (PIXLAB-01)
- [x] 03.5-03-PLAN.md — PentaTileLayoutPixelLabSideScroller shipping (PIXLAB-02)
- [x] 03.5-04-PLAN.md — pixellab_first_cell_test (D-89 cache contract) + comprehensive_bitmask_test matrix extension to 8×18=144 + bitmask_bounds_test 8×8 PIXLAB extension + run_tests.ps1 registration (PIXLAB-03)
- [x] 03.5-05-PLAN.md — pixellab_visual_regression_test composed-canvas test + checked-in spike-003 PixelLab samples + run_tests.ps1 registration (PIXLAB-04)
- [x] 03.5-06-PLAN.md — Closeout: REQUIREMENTS Traceability + ROADMAP retitle + ROADMAP [x] + STATE.md cumulative LOC + Roadmap Evolution entry + VAR-PIXEL-01 deferral preservation

### Phase 4: Fallback Routing + Doc Sweep + Cross-AI Review

**Goal**: Close out v0.2 implementation work and gate v0.2.0 release through three braided deliverables: (1) verify and formally close PREVIEW-03 / PREVIEW-04 (the fallback routing wiring already shipped in Phase 2 — Phase 4 is the cross-layout verification gate), (2) sweep full GDScript doc comments per Godot's official format onto the 12 addon scripts, (3) run a two-pass cross-AI review (Gemini headless → fix valid → Codex via `/gsd-review codex` → fix valid) covering codebase + implementation + design + goals + docs against TileMapDual identity guardrails. Decisions captured in `.planning/phases/04-fallback-routing/04-CONTEXT.md` (D-04-01 through D-04-16).

**Depends on**: Phase 1 (layer integration), Phase 2 (`get_fallback_tile_set()` codegen on base class; PREVIEW-03/04 wiring already shipped at `penta_tile_map_layer.gd:54-70` and pulled forward from Phase 4 during the auto-fill chain refinement), Phase 3 (Blob47Godot layout's bundled bitmask PNG), Phase 3.5 (2 PixelLab layouts shipped with first-cell pick). Verifies the consumer side once all 8 actually-shipped layouts can produce a fallback TileSet.

**Requirements**: PREVIEW-03, PREVIEW-04. Visual-regression sweep across all 8 actually-shipped layouts (5 Phase 2 + 1 Phase 3 Blob47Godot + 2 Phase 3.5 PixelLab; the Tilesetter pair TBT-01 / TBT-02 stays deferred to v0.3+ per D-86 b).

**Success Criteria** (what must be TRUE):
1. **Fallback routing UAT**: creating a new `PentaTileMapLayer` node with `tile_set = null` and `layout` attached (with any of the 8 actually-shipped layouts) makes drag-paint produce visible greybox tiles immediately — no TileSet authored. Programmatic composed-canvas test (`fallback_routing_test.gd`) plus manual demo eyeball pass per CLAUDE.md Test Methodology #1.
2. **PREVIEW-04 contract**: assigning `tile_set` directly overrides the fallback (no warnings, no errors). Removing `tile_set` again (back to null) re-routes to the fallback. The `_tile_set_is_fallback` flag in `penta_tile_map_layer.gd:79` remains the source of truth for fallback-vs-user-supplied.
3. **All 8 layouts** have a working fallback path: paint a small scene using each layout's fallback, confirm visible output matches the layout's bitmask-template silhouettes. Tilesetter pair correctly excluded (deferred per D-86 b).
4. **Regression-safe**: the fallback routing path doesn't change behavior when `tile_set` is provided (existing scenes with `tile_set` set don't suddenly use fallback art).
5. **Doc-comment sweep**: all 12 addon scripts under `addons/penta_tile/` (excluding `tests/` and `demo/`) have class-level `##` blocks + `##` on every public method (no leading underscore) + `##` on every `@export` property. Use full Godot doc-comment tag set (`@tutorial`, `@experimental`, `@deprecated`, BBCode `[param]`, `[code]`, `[Class]`, `[method]`, `[member]`). `@experimental` annotation on the `PentaTileLayout` subclassing surface per DOC-03. `@tutorial` tags point to relevant `.planning/research/` docs and ROADMAP entries.
6. **Gemini cross-AI review pass**: headless `gemini -p ...` review covers codebase + project planning docs + identity guardrails + TileMapDual comparison. Findings categorized by Severity (Critical | High | Medium | Low | Info) × Theme (Bug | Identity | Goal-misalignment | Doc | Design). Output: `04-GEMINI-REVIEW.md` (raw findings) + `04-GEMINI-REVIEW-FIX.md` (per-finding disposition + fix-commit log). Severity-tiered fix policy (Critical/High auto, Medium user-gated, Low/Info logged).
7. **Codex cross-AI review pass**: `/gsd-review codex` against the post-Gemini-fix codebase. Same review surface and finding format as Gemini. Output: `04-CODEX-REVIEW.md` + `04-CODEX-REVIEW-FIX.md`.
8. **Standard disqualification list** filters reviewer findings: reject suggestions that propose backwards-compat shims (CLAUDE.md HARD RULE), forward-compat versioning fields, v2/v0.3+ scope (TBT-01/02-DEFERRED, VAR-01, TOP-01, MULTITERR-*), Phase 5 territory (LOC trim, README rewrite, CHANGELOG, demo refresh, plugin.cfg bump, ATTRIBUTION.md per D-72/D-73), Coined-Term Discipline violations, or locked-decision contradictions. All findings (applied + rejected) logged with disposition rationale.
9. **Atomic-commit-per-finding**: one commit per fix referencing the finding ID (e.g. `fix(04): GEMINI-W-03 — missing @return tag in PentaTileLayout.compute_mask docstring`). Matches Phase 2's WR-fix pattern.
10. **Phase-close gate**: ROADMAP Phase 4 row flips to `[x]` only when all four artifacts commit: `04-FALLBACK-UAT.md` (UAT pass record), `04-DOC-SWEEP.md` (sweep summary + before/after), `04-GEMINI-REVIEW-FIX.md`, `04-CODEX-REVIEW-FIX.md`.

**Out of scope (deferred to Phase 5 or v0.3+)**: LOC + identity formal audit (Phase 5), README "Layouts"/"Upgrading"/"Authoring a Custom Layout" sections (Phase 5 / DOC-01..03), CHANGELOG v0.2.0 entry (Phase 5 / DOC-04), demo refresh showcasing all layouts (Phase 5 / DEMO-01..03), plugin.cfg bump (Phase 5 / REL-01), GitHub Release zip (Phase 5 / REL-03), Tilesetter pair (TBT-01-DEFERRED / TBT-02-DEFERRED, v0.3+), variation-bank pick (VAR-PIXEL-01, v2), Y-axis variation / top tiles / multi-terrain (v2 backlog).

**Plans**: 5 plans (2/5 complete)
Plans:
- [x] 04-01-PLAN.md — Wave 1: fallback_routing_test.gd composed-canvas test (8 layouts × 1 pattern + PREVIEW-04 contract sub-tests) + run_tests.ps1 registry append (17 → 18) + 04-FALLBACK-UAT.md skeleton (PREVIEW-03 + PREVIEW-04)
- [x] 04-02-PLAN.md — Wave 1: doc-comment sweep across 12 addon scripts (annotation-only — class-level ## + every public method + every @export property; @experimental flag added ONLY on PentaTileLayout abstract base per D-04-03)
- [ ] 04-03-PLAN.md — Wave 2: manual UAT eyeball pass + 04-DOC-SWEEP.md summary + Gemini cross-AI review (headless gemini -p) + fix-application loop per severity-tiered policy (D-04-13) + standard disqualification list (D-04-14)
- [ ] 04-04-PLAN.md — Wave 3: Codex cross-AI review (headless codex exec --skip-git-repo-check -) on POST-Gemini-fix codebase per D-04-10 strict order + fix-application loop
- [ ] 04-05-PLAN.md — Wave 4 closeout: REQUIREMENTS.md PREVIEW-03/04 status flips Pending → Complete + ROADMAP Phase 4 [x] + STATE.md Performance Metrics + Roadmap Evolution + cumulative LOC + Current Position advance to Phase 5

### Phase 5: Demo Refresh + Documentation + Release

**Goal**: One updated demo scene showcasing all 8 actually-shipped layouts (5 Phase 2 + 1 Phase 3 + 2 Phase 3.5; Tilesetter pair stays deferred to v0.3+ per D-86 b), README sections documenting the library, CHANGELOG, and a tagged GitHub release.

**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4 (consuming phase — uses every output of the prior phases).

**Requirements**: DEMO-01, DEMO-02, DEMO-03, DOC-01, DOC-02, DOC-03, DOC-04, REL-01, REL-02, REL-03.

**Success Criteria** (what must be TRUE):
1. The updated `penta_tile_demo.tscn` showcases all 8 actually-shipped layouts (5 Phase 2 + 1 Phase 3 + 2 Phase 3.5) — either via runtime layout switching (UI to swap the `layout` property) or side-by-side `PentaTileMapLayer` instances arranged spatially. A casual playtester can see each layout in action.
2. The demo references the bundled fallback TileSets (via `get_fallback_tile_set()` codegen) so it works out of the box without any authored tilesets (proves the prototyping UX).
3. Runtime drag-paint (existing `demo_runtime_painter.gd`) continues to work across all layouts in the updated demo without script changes beyond layout-switching glue.
4. README has a "Layouts" section listing all 8 actually-shipped layouts (5 Phase 2 + 1 Phase 3 + 2 Phase 3.5) with names, descriptions, atlas grids, tile counts, and which conventions they target. Plus "Upgrading from 0.1.x" and "Authoring a Custom Layout" (experimental).
5. `plugin.cfg` `version` field reads `0.2.0` exactly (no `-pre` / `-alpha` / `-dev` suffix). `CHANGELOG.md` has a v0.2.0 entry naming all breaking changes (`PentaTileAtlasContract` deletion, `template_image` → `bitmask_template` rename, `fallback_tile_set` @export removal, separate Penta H/V class merge, overlay-layer deletion, etc.).
6. Downloading the v0.2.0 GitHub Release zip and extracting to a fresh Godot 4.6 project produces a working demo with no errors on first run.
7. Final identity audit reports three axes (LOC, public surface, hot-path depth) plus an anti-pattern register check against TileMapDual v5.0.2. LOC is reported as signal, not a fail criterion (D-05-11). Audit summary lives in README § Identity & Footprint; full working artifact at `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md`.

**Plans**: 5 plans (5/5 complete)

Plans:
- [x] 05-01-PLAN.md — Demo refresh: 8-instance spatial-grid scene + hover-target painter + retired demo_player + authored ground + 4 legacy .tres orphans (DEMO-01..03)
- [x] 05-02-PLAN.md — Documentation + spec corrections: 4 new README sections + accumulated CHANGELOG + 15 spec corrections (DOC-01..04 + SC-A..D + 1 follow-up at ROADMAP.md:303)
- [x] 05-03-PLAN.md — Identity audit: TileMapDual v5.0.2 comparison (3-axis: LOC + public surface + hot-path) + D-05-11 ship/extract decision (outcome SHIP) + README Identity & Footprint summary (manual prerequisite per D-05-13)
- [x] 05-04-PLAN.md — Release infrastructure: .github/workflows/release.yml (workflow_dispatch, no inputs, auto-version-increment) + tests/run_tests.sh Linux mirror (REL-01..03 enabled)
- [x] 05-05-PLAN.md — Closeout: workflow run 25131034672 via GitHub UI + Traceability flips + ROADMAP / STATE updates (REL-01..03 satisfied via workflow side-effects)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 3.5 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Contract Skeleton + Penta Layouts | 5/5 | Complete (substantially superseded by Phase 2 architectural sweep) | 2026-04-26 |
| 1.1. PentaTile Rename + Penta Codename Establishment | 3/3 | Complete | 2026-04-26 |
| 2. Native Layouts + Architectural Simplification | 7/7 + retroactive AUTO_STRIP wave + UAT bug-fix sweep | **Complete.** 3 review passes clean (0 Critical, 0 Warning, 13 Info). UAT bug-fix sweep 2026-04-28 closed 7 bug classes across commits 6553380..205fb67 — 12 automated tests green, methodology codified in `02-UAT-LESSONS-LEARNED.md`. User confirmed visual UAT via the 16-mask-pattern demo scene 2026-04-28T22:00. LOC overage (1827 vs ~1500 informational trigger) carried forward; formal gate is Phase 5 final audit. | 2026-04-28 |
| 3. Public-Convention Layouts (Blob47 only; Tilesetter deferred to v0.3+) | 6/6 (5 executed + Plan 05 SKIPPED per D-86 = b) | **Complete with reduced scope per D-86 (b)** — Blob47Godot ships (TBT-03), audit deliverable + README footnote land (TBT-04, DOC-05); Tilesetter pair (TBT-01/02) + Tilesetter half of TEMPLATE-02 deferred to v0.3+ via `TBT-01-DEFERRED` / `TBT-02-DEFERRED` / `TEMPLATE-02-DEFERRED`. 15 automated tests green; matrix coverage extended to 6×18=108 combos in comprehensive_bitmask_test. Cumulative runtime LOC ~2455 (Phase 2 baseline 1827 + Phase 3 delta ~121 + measurement methodology drift; AT RISK carry-forward for Phase 5 final identity audit). No `addons/penta_tile/ATTRIBUTION.md` created (D-73 final guard). | 2026-04-29 |
| 3.5. PixelLab Layouts (variation-bank pick deferred to v2) | 6/6 | **Complete.** Both PixelLab layouts (top-down + side-scroller) shipped with cached first-cell row-major dispatch. 2 new tests (pixellab_first_cell_test + pixellab_visual_regression_test) green; matrix grew to 8 layouts × 18 patterns = 144 combos; bounds extended with PIXLAB silhouettes. VAR-PIXEL-01 (variation-bank pick) preserved in v2 backlog per D-91. | 2026-04-29 |
| 4. Fallback Routing + Doc Sweep + Cross-AI Review | 5/5 | **Complete.** All 4 closeout artifacts committed (FALLBACK-UAT.md + DOC-SWEEP.md + GEMINI-REVIEW-FIX.md + CODEX-REVIEW-FIX.md); 18 automated tests green; Gemini cross-AI pass returned `status: clean` (0 findings); Codex pass DEFERRED at closeout due to a hard external CLI quota wall (RESEARCH § 8 Pitfall #14; user elected to skip per `AskUserQuestion`). PREVIEW-03/04 closed per D-04-07. | 2026-04-29 |
| 5. Demo Refresh + Documentation + Release | 5/5 | **Complete.** v0.2.0 shipped end-to-end via the release workflow on 2026-04-29. 8-instance demo grid + 4 README sections + accumulated CHANGELOG + 15 spec corrections (SC-A..D + 1 follow-up) + identity audit (per D-05-11 — SHIP outcome: clean hot path + 16/16 anti-patterns absent). 17 automated tests green; release workflow run 25131034672 (44s) published `penta_tile-v0.2.0.zip` (208024 bytes) to https://github.com/Shilo/PentaTile/releases/tag/v0.2.0. | 2026-04-29 |
| 6. Editor Line/Rect/Bucket Tool Preview During Drag | 0/0 | Deferred / not planned. Known editor-preview UX issue captured for later. | — |
| 7. Repo Restructure: Extract Tests + MkDocs Site + LLM-Friendly Docs Pipeline | 1/1 | **Complete.** Tests extracted to root `tests/`; release workflow retargeted and still archives only `addons/penta_tile/`; MkDocs Material site added with dark-first manual toggle; LLM docs decision recommends direct source docs over generated flat artifact for now. | 2026-04-29 |
| 8. Research Triage + v0.3 Scope Selection | 4/4 | **Complete.** Verified competitive-autotiling claims, dispositioned supplied recommendations, ranked v0.3 candidates, wrote scope firewall, refined backlog triggers, and recommended **Terrain + Variation Authoring Research Spike** as the next v0.3 target. Production terrain/variation refactors remain blocked until spike findings plus user-side manual Godot testing exist. | 2026-04-30 |
| 9. Terrain + Variation Authoring Research Spike | 3/3 | Complete. 09-ARCHITECTURE-RECOMMENDATION.md produced: PentaTileTerrainGroup + penta_terrain_id custom data layer + transient terrain index + 6-phase blueprint (~440 LOC). Godot terrain sets PDF fully extracted. All 6 phase decisions verified. | 2026-04-30 |
| 10. Multi-Terrain + Variation Implementation | 4/4 | Complete   | 2026-04-30 |
| 10.1. Terrain Auto-Detection Redesign | 1/3 | In Progress|  |
| 11. VirtuMap Integration Bridge | 0/0 | Consumes spike 004+005. Blocked until Phase 10.1 completes. | — |

## Coverage

All 58 v1 requirements mapped to exactly one phase. No orphans, no duplicates.

| Phase | Requirements (count) |
|-------|----------------------|
| 1. Contract Skeleton + Penta Layouts (residual) | LAYOUT-01, LAYOUT-02, LAYOUT-05 (3) |
| 2. Native Layouts + Architectural Simplification | NATIVE-01..03, MIN3x3-01, LAYER-01..05, LAYOUT-03/04/06/07, PENTA-01..03, PENTA-SYNTH-01..12, PREVIEW-01..02, TEMPLATE-01/03/04 (33) |
| 3. TileBitTools-Sourced Layouts | TBT-01..04, TEMPLATE-02, DOC-05 (6) |
| 3.5. PixelLab Layouts | PIXLAB-01..04 (4) |
| 4. Fallback Routing | PREVIEW-03, PREVIEW-04 (2) |
| 5. Demo Refresh + Documentation + Release | DEMO-01..03, DOC-01..04, REL-01..03 (10) |
| 7. Repo Restructure + MkDocs + LLM Docs | REPO-01..03, DOCS-06..08 (6 post-release follow-up reqs) |
| 8. Research Triage + v0.3 Scope Selection | TRIAGE-01..06 (6 post-release planning reqs) |
| 10 + 10.1. Multi-Terrain + Variation | MULTITERR-01..08 (8, split across Phases 10 + 10.1) |
| **(Pre-shipped flat templates) → restructured in Phase 2 (TEMPLATE-01)** | (existing PNGs migrated to co-located bundles next to layout `.gd` files) |
| **Total** | **58 / 58 v1 + 6 / 6 Phase 7 follow-up + 6 / 6 Phase 8 planning reqs + 0/8 MULTITERR reqs (Phase 10 partial, Phase 10.1 pending)** |

> **2026-04-26 architectural pivots** (locked after fourth iteration of design refinement):
> - `PentaTileAtlasContract` deleted (CONTRACT-01..05 retired); `layout: PentaTileLayout` directly on `PentaTileMapLayer` (LAYER-01..03)
> - `PentaTileLayoutPentaHorizontal`+`Vertical` merged into `PentaTileLayoutPenta` with `axis: Axis` enum
> - `tile_count: TileCountMode` enum (`AUTO`/`AUTO_STRIP`/`ONE`/`TWO`/`THREE`/`FOUR`/`FIVE`) — five progressive modes; AUTO is dimension-only, AUTO_STRIP is per-strip
> - **New slot ordering**: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. OuterCorner is implicit (synthesized from slot 0 across all modes; no dedicated slot)
> - `template_image` → `bitmask_template` (single image per layout, doubles as inspector preview AND fallback TileSet source — no atlas/bitmask split)
> - `fallback_tile_set` hidden from inspector (codegen via `get_fallback_tile_set()`); `decoder_image` deleted (was speculative)
> - **Bundled PNGs co-located** next to layout `.gd` files. Penta: 10 PNGs in `penta_tile_layout_penta/` subfolder. Single-variant layouts: flat siblings. The `templates/` folder is deleted entirely.
> - VAR-PIXEL-01 (PixelLab variation-bank pick) moved to v2 backlog with VAR-01 / MULTITERR-* (all Y-axis-coupled, must be designed together)
> - Phase 2.1 collapsed back into Phase 2 (ONE mode handles SingleTile prototyping via auto-detect)

## Identity Guardrails

The PROJECT.md identity constraint — quality over raw size — is checked at four points across the roadmap:

- **End of Phase 1:** LOC checkpoint after the contract surface lands. The base class + AtlasSlot + PentaHorizontal/Vertical + integration in PentaTileMapLayer is the largest schema addition; LOC is tracked as a data point.
- **End of Phase 3:** LOC checkpoint after the standard 8 blob/wang/penta layouts ship. LOC is tracked as a data point.
- **End of Phase 3.5:** LOC contribution from the two PixelLab layouts plus the `variation_seed` deterministic-hash wiring (~80–120 LOC total for both layouts + variation pick).
- **End of Phase 4:** Compare the runtime hot path (`_update_cells` → `layout.compute_mask` → `layout.mask_to_atlas` → `set_cell`) against v0.1's straight-line `match` to confirm no significant perf regression at demo scale.
- **Phase 5 final audit:** Total `addons/penta_tile/` LOC measured; result included in the release notes as a data point.

Per PROJECT.md, the quality bar is "works in my game" — visual regression on the demo is the primary verification mechanism, not a formal test suite. Demo-scale (~100–1k cells) is the only perf target; success criteria deliberately do NOT gate on perf.

Architectural anti-patterns explicitly NOT introduced (per `.planning/research/layouts/MASK_UNIFICATION.md`, the TileBitTools audit, and the 2026-04-29 multi-terrain research): no `EditorInspectorPlugin` polish, no Godot terrain-solver delegation, no parallel painting API, no persistent coordinate cache, no watcher / signal-fanout systems, no quarter-tile compositor. Godot `TileData` terrain metadata may be read as input in a future focused MULTITERR phase.

### Phase 6: Editor Line/Rect/Bucket Tool Preview During Drag

**Status:** Far-future / deferred — defer until after v0.2.0 ships. Tracked because the bug surfaces immediately when a layout is bound (preview invisible during line/rect/bucket drag), but it is not blocking any v0.2 success criterion and demo-scale paint usage stays acceptable.

**Goal:** Restore visible preview while the user is mid-drag with the editor's line, rectangle, and bucket tools when a `layout` is assigned to `PentaTileMapLayer`. Today the preview is invisible because Godot 4.6 draws line/rect/bucket previews to the viewport overlay multiplied by `edited_layer.self_modulate`, and PentaTile zeroes `self_modulate.a` via `logic_layer_opacity = 0` to hide the parent's raw cells.

**Requirements**: TBD (likely a new "editor-integration" requirement family).

**Depends on:** Phase 5

**Background:** Full investigation in `.planning/research/editor-line-rect-preview.md` — verified against Godot 4.6 source (`editor/scene/2d/tiles/tile_map_layer_editor.cpp` lines 875-990). Companion todo: `.planning/todos/pending/2026-04-28-re-research-editor-line-rect-tool-preview-during-drag.md`. **Re-verify the open questions in the research doc before committing to an approach** — Godot may add atlas-redirect to `_tile_data_runtime_update`, expose preview state to scripts, or add a per-layer preview hook between now and when this phase fires.

**Two candidate approaches** (decision deferred to plan phase):

- **(a) Ghost-material refactor (TileMapDual parity, raw preview).** Replace `self_modulate.a`-based hiding (`penta_tile_map_layer.gd:439-442`) with a `ShaderMaterial` (`COLOR = vec4(0)` in fragment) on the parent's `material` slot; keep `self_modulate.a == 1.0`; forward user-supplied `material` to `_primary_layer` via a new `display_material` export. Result: editor's 50%-alpha raw atlas preview becomes visible during drag (not autotile-dispatched). ~30 LOC. Breaking change to public `logic_layer_opacity` export (acceptable per CLAUDE.md breaking-changes policy).

- **(b) Custom `EditorPlugin` with `forward_canvas_draw_over_viewport`.** Hook editor drag state, compute the cells the line/rect/bucket tool will produce, run autotile dispatch with a virtual sample fn that includes preview cells, render the dispatched output as a viewport overlay. Result: fully autotile-dispatched preview during drag. Significant work; risks conflicts with the editor's built-in preview overlay if both render simultaneously.

**Success criteria (draft, refine when planning):**
- Line, rectangle, and bucket tools all show a visible preview during drag when a `layout` is bound.
- Null-layout fallback path stays unchanged (already works).
- Pitfall §7 (`visible = false` cleanup leak) stays mitigated.
- No regression to runtime (in-game) rendering behavior.
- LOC checkpoint: LOC is reported as signal, not verdict.

**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 6 to break down — but only after v0.2.0 ships)

### Phase 7: Repo Restructure: Extract Tests + MkDocs Site + LLM-Friendly Docs Pipeline

**Goal:** Three deliverables, all v0.2.0 follow-up post-release:

1. **Move `addons/penta_tile/tests/` → `./tests/`.** Tests should not ship in the GitHub Release zip. Verify self-containment (no path assumptions into `addons/penta_tile/`), then move. Update all references: `.github/workflows/release.yml`, `run_tests.ps1`, `run_tests.sh`, `.gitignore`, CLAUDE.md, planning docs.

2. **MkDocs documentation site.** Dark mode by default with a dark↔light toggle (two-state, no system-preference auto). Includes a quickstart guide and per-layout dedication pages, with a "What is a Penta tileset?" deep-dive page anchoring the codename. (This reverses PROJECT.md's prior "no MkDocs" stance — that decision was made when the audience was strictly the author; reconciled in PROJECT.md + REQUIREMENTS.md.)

3. **LLM-friendly documentation pipeline.** Research whether an LLM agent reads this addon better via (a) the mkdocs source + GDScript `##` doc-comments directly, or (b) an auto-generated flat text artifact. If (b) wins, design a GitHub Actions workflow that regenerates the artifact on every mkdocs/GDScript-doc change. The research-and-decide is the deliverable — don't presuppose the answer.

**Requirements**: REPO-01..03, DOCS-06..08. TOOL-04 (MkDocs documentation site) promoted from v2 backlog into Phase 7 scope and satisfied as DOCS-06/07.

**Depends on:** Phase 5 (consumes the shipped v0.2.0 surface). Independent of Phase 6 (deferred editor-preview work).

**Plans:** 1 plan (1/1 complete)

Plans:
- [x] 07-PLAN.md — Repo restructure, MkDocs site, LLM docs decision, verification, closeout

### Phase 8: Research Triage + v0.3 Scope Selection

**Goal:** Turn the supplied competitive-autotiling research into a verified, identity-filtered v0.3 candidate set. This is a design/planning phase, not an implementation phase: challenge claims against primary sources and the live repo, produce the next-milestone scope recommendation.

**Requirements**: TRIAGE-01..06.

**Depends on:** Phase 5 for the shipped v0.2.0 surface. Phase 7 docs may inform the final communication shape, but Phase 8 is independent of Phase 6 editor-preview implementation.

**Background:** Initial triage artifact: `.planning/phases/08-research-triage-v0-3-scope-selection/08-RESEARCH-TRIAGE.md`. Focused terrain artifact: `.planning/phases/08-research-triage-v0-3-scope-selection/08-MULTI-TERRAIN-RESEARCH.md`. The broad research usefully reinforces deterministic variation, PixelLab variation-bank pick, explicit top tiles, Tilesetter follow-up, authoring/converter tooling, docs, and benchmark-first performance work. It also contains stale or off-identity recommendations: PentaTile already has dual-grid layouts; global constraint solvers, terrain-rule docks, persistent caches, hex/iso support, JSON metadata/entity spawning, and GPU infinite-world shaders are not v0.3 defaults. Multi-terrain support is no longer blanket-rejected: the accepted research shape is to read Godot `TileData` terrain metadata as authoring/indexing input while PentaTile keeps its own deterministic layout solver and generated `set_cell()` output.

**Success Criteria (complete):**
1. **Verified claims table:** Complete in `08-VERIFIED-CLAIMS.md`.
2. **Accept/reject matrix:** Complete in `08-DISPOSITION-MATRIX.md`.
3. **v0.3 candidate matrix:** Complete in `08-CANDIDATE-MATRIX.md`; ranks Terrain + Variation Authoring Research Spike first and preserves Art Quality / Adoption-UX alternates.
4. **Scope firewall:** Complete in `08-SCOPE-FIREWALL.md`; Godot terrain metadata input remains allowed, solver delegation and framework-scale systems rejected.
5. **Backlog cleanup:** Complete in `REQUIREMENTS.md` and `08-BACKLOG-CLEANUP.md`; production terrain/variation work waits for spike findings and user-side manual Godot testing.
6. **Next-step recommendation:** Complete in `08-RECOMMENDATION.md`.

**Plans:** 4 plans (4/4 complete)

Plans:
- [x] 08-01-PLAN.md — Verify claims and disposition supplied research recommendations
- [x] 08-02-PLAN.md — Rank v0.3 candidates and write the scope firewall
- [x] 08-03-PLAN.md — Refine REQUIREMENTS backlog triggers and constraints
- [x] 08-04-PLAN.md — Recommend v0.3 package, update ROADMAP/STATE, and close Phase 8

**Recommendation:** Add and plan the next v0.3 phase:

```text
/gsd-add-phase "Terrain + Variation Authoring Research Spike"
/gsd-plan-phase <new phase number>
```

### Phase 9: Terrain + Variation Authoring Research Spike

**Goal**: Research and design the architecture for multi-terrain dispatch, deterministic variation, and VirtuMap integration. Output: formal architecture recommendation at `09-ARCHITECTURE-RECOMMENDATION.md`.
**Requirements**: D-01..D-06 (phase-specific design decisions)
**Depends on:** Phase 8
**Plans:** 3 plans complete (3/3)

Plans:
- [x] 09-01-PLAN.md — Wave 1: Godot native + TileMapDual + TileBitTools + BetterTerrain terrain/variation architectures
- [x] 09-02-PLAN.md — Wave 1: Tiled + LDtk + RPG Maker external editor autotile conventions
- [x] 09-03-PLAN.md — Wave 2: Synthesize into PentaTileTerrainGroup + penta_terrain_id + transient terrain index + 6-phase blueprint

### Phase 10: Multi-Terrain + Variation Implementation

**Goal:** Implement terrain dispatch via PentaTileTerrainGroup Resource (Phase 9 design) + deterministic variation via TileData.probability + source_id on AtlasSlot + terrain_mode() virtual + compute_mask(strip_index) extension. Consumes Phase 9 architecture + spikes 006+007 findings.

**Requirements**: TBD
**Depends on:** Phase 9
**Plans:** 4/4 plans complete

Plans:
- [x] 10-01-PLAN.md — Wave 1: PentaTileTerrainGroup Resource + source_id on AtlasSlot + terrain_mode() + VariationMode + compute_mask signature on base + all 9 subclass signature updates
- [x] 10-02-PLAN.md — Wave 2: terrain_group setter + _build_terrain_index() + _resolve_terrain_id() + terrain-aware single-grid dispatch
- [x] 10-03-PLAN.md — Wave 3: per-corner dual-grid terrain dispatch + variation mode wiring (SINGLE/PROBABILITY/STRIP) + PentaTileLayoutSlope subclass + set_cell_passthrough()
- [x] 10-04-PLAN.md — Wave 4: fallback TileSet extension for terrain_group + full 9-layout × 13-pattern × multi-terrain integration test suite

### Phase 10.1: Terrain Auto-Detection Redesign — replace manual TerrainGroup Resource with auto-detected Godot native terrain sets, single shared layout for all terrains, atlas-grid-based terrain count (INSERTED)

**Goal:** Replace the Phase 10 `PentaTileTerrainGroup` Resource + per-terrain layout array with auto-detection: terrain count derived from `atlas_grid_size.y` (each atlas row = one terrain), Godot native `TerrainSets` for name/color storage (not solving), single shared `layout: PentaTileLayout` for all terrains. ~280 LOC net savings (~400 removed, ~120 added).

**Requirements**: MULTITERR-01, MULTITERR-02, MULTITERR-03, MULTITERR-04, MULTITERR-05, MULTITERR-07, MULTITERR-08
**Depends on:** Phase 10
**Plans:** 1/3 plans executed

Plans:
- [x] 10.1-01-PLAN.md — Wave 1: Source code refactor — DELETE TerrainGroup infrastructure + ADD _auto_detect_terrains()/_on_tile_set_changed()/_resolve_terrain_id() + SIMPLIFY dual-grid per-corner dispatch + single-grid terrain dispatch + variation wiring
- [ ] 10.1-02-PLAN.md — Wave 2: NEW tests (terrain_autodetect_test.gd + terrain_dispatch_test.gd + terrain_determinism_test.gd + terrain_sample_terrains_test.gd) + DELETE 5 old TerrainGroup-coupled tests
- [ ] 10.1-03-PLAN.md — Wave 2: REWRITE tests (variation_determinism_test.gd + slope_layout_test.gd drop TerrainGroup) + UPDATE run_tests.ps1 inventory + closeout (ROADMAP.md + STATE.md)

### Phase 11: VirtuMap Integration Bridge

**Goal:** Implement atlas passthrough (source-ID gating + _PentaTilePassthrough layer) + PentaTileLayoutSlope subclass + editor preview fix (ghost material refactor). Consumes spike 004+005 findings. Enables VirtuMap to adopt PentaTile as its autotiling engine.

**Requirements**: TBD
**Depends on:** Phase 10
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 11 to break down)

---
*Roadmap re-spun: 2026-04-25 after v0.2 pivot to layout library*

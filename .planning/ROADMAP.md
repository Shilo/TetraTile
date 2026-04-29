# Roadmap: PentaTile v0.2.0

**Milestone:** v0.2.0 — "Layout Library + Preview Fallback"
**Created:** 2026-04-25 (re-spun after pivot from "expand the contract")
**Granularity:** standard (5 phases)

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
- [ ] **Phase 3.5: PixelLab Layouts + Variation-Seed Wiring** — Ship `PentaTileLayoutPixelLabTopDown` and `PentaTileLayoutPixelLabSideScroller` (8×8 atlas, single-grid, 4-bit corner mask, variation-bank). Wire `variation_seed` deterministic-hash bucket-pick. Add `PentaTileLayoutMinimal3x3` if not already shipped in Phase 2.
- [ ] **Phase 4: Fallback Routing** — Wire `PentaTileMapLayer` to use `layout.fallback_tile_set` when `tile_set == null`. Verify all 10 layouts (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5) paint correctly with their bundled fallback. Visual regression on the demo scene.
- [ ] **Phase 5: Demo Refresh + Documentation + Release** — One updated demo scene showcasing all 10 layouts (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5), README sections (Layouts / Upgrading / Authoring a Custom Layout), CHANGELOG, plugin.cfg bump, GitHub Release zip with `v0.2.0` tag.

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

**Goal**: Ship `PentaTileLayoutPixelLabTopDown` and `PentaTileLayoutPixelLabSideScroller` subclasses. Both consume PixelLab Aseprite plugin native 8×8 atlas output with variation banks. Both share the locked role-to-mask bijection `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]` (corner mask). Wire `variation_seed` deterministic-hash bucket-pick: `mask → cells[]; pick = cells[hash(coord, variation_seed) % cells.size()]`.

**Depends on**: Phase 1 (architecture), Phase 2 or Phase 3 (single-grid pipeline first consumed by Wang2Corner in Phase 2).

**Requirements**: PIXLAB-01, PIXLAB-02, PIXLAB-03, PIXLAB-04, VAR-PIXEL-01.

**Success Criteria** (what must be TRUE):
1. `PentaTileLayoutPixelLabTopDown.compute_mask` and `mask_to_atlas` consume the locked role-to-mask mapping; visual regression on a PixelLab 8×8 sample matches the Aseprite plugin output.
2. `PentaTileLayoutPixelLabSideScroller` shares the role-to-mask mapping; cell-to-role differs (the side-scroller variant). Visual regression on a side-scroller PixelLab 8×8 sample passes.
3. Variation-bank: when a mask has multiple cells (PixelLab variations), `mask_to_atlas` returns a deterministic pick keyed on `(coord, variation_seed)`. Same `(coord, seed)` always returns the same cell across `rebuild()` invocations (no shimmering).
4. Setting `variation_seed = N` produces a different deterministic pick than `variation_seed = N+1`, verified visually on a uniform painted region.

**Plans**: 6 plans

Plans:
- [ ] 03.5-01-PLAN.md — Wave 1: generator extension + 2 bundled PixelLab greybox PNGs (256×256, 8×8 atlas) + .import sidecars
- [x] 03.5-02-PLAN.md — Wave 2: PentaTileLayoutPixelLabTopDown subclass (PIXLAB-01)
- [x] 03.5-03-PLAN.md — Wave 2: PentaTileLayoutPixelLabSideScroller subclass (PIXLAB-02)
- [x] 03.5-04-PLAN.md — Wave 3: pixellab_first_cell_test + comprehensive_bitmask_test matrix extension to 8×18=144 + bitmask_bounds_test 8×8 PIXLAB extension + run_tests.ps1 (PIXLAB-03) — 2026-04-29
- [x] 03.5-05-PLAN.md — Wave 4: pixellab_visual_regression_test composed-canvas + checked-in spike-003 PixelLab samples + run_tests.ps1 (PIXLAB-04) — 2026-04-29
- [ ] 03.5-06-PLAN.md — Wave 4: closeout — REQUIREMENTS Traceability + ROADMAP retitle + ROADMAP [x] + STATE.md cumulative LOC + Roadmap Evolution + VAR-PIXEL-01 deferral preservation

### Phase 4: Fallback Routing

**Goal**: When `PentaTileMapLayer.tile_set == null` and `layout != null`, the layer routes rendering through `layout.get_fallback_tile_set()` (codegen from `bitmask_template`). This is the prototyping UX win — drop a fresh layer into a scene with just a layout attached and start painting.

**Depends on**: Phase 1 (layer integration), Phase 2 (Phase 2 ships `get_fallback_tile_set()` codegen on the base class + co-located bundled bitmask PNGs for all 5 layouts shipped so far), Phase 3 (TBT layouts add their own `get_fallback_tile_set()` overrides). Wires the consumer side once all 10 layouts (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5) can produce a fallback TileSet.

**Requirements**: PREVIEW-03, PREVIEW-04. Final visual-regression sweep across all 10 layouts (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5).

**Success Criteria** (what must be TRUE):
1. Creating a new `PentaTileMapLayer` node with `tile_set = null` and `layout` attached (with any of the 10 layouts) makes drag-paint produce visible greybox tiles immediately — no TileSet authored.
2. Assigning `tile_set` directly overrides the fallback (no warnings, no errors). Removing `tile_set` again (back to null) re-routes to the fallback.
3. All 10 layouts have a working fallback path: paint a small scene using each layout's fallback, confirm visible output matches the layout's bitmask-template silhouettes.
4. The fallback routing path doesn't change behavior when `tile_set` is provided (regression check: existing scenes with `tile_set` set don't suddenly use fallback art).

**Plans**: TBD

### Phase 5: Demo Refresh + Documentation + Release

**Goal**: One updated demo scene showcasing all 10 built-in layouts (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5), README sections documenting the library, CHANGELOG, and a tagged GitHub release.

**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4 (consuming phase — uses every output of the prior phases).

**Requirements**: DEMO-01, DEMO-02, DEMO-03, DOC-01, DOC-02, DOC-03, DOC-04, REL-01, REL-02, REL-03.

**Success Criteria** (what must be TRUE):
1. The updated `penta_tile_demo.tscn` showcases all 10 layouts (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5) — either via runtime layout switching (UI to swap the `layout` property) or side-by-side `PentaTileMapLayer` instances arranged spatially. A casual playtester can see each layout in action.
2. The demo references the bundled fallback TileSets (via `get_fallback_tile_set()` codegen) so it works out of the box without any authored tilesets (proves the prototyping UX).
3. Runtime drag-paint (existing `demo_runtime_painter.gd`) continues to work across all layouts in the updated demo without script changes beyond layout-switching glue.
4. README has a "Layouts" section listing all 10 built-in layouts (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5) with names, descriptions, atlas grids, tile counts, and which conventions they target. Plus "Upgrading from 0.1.x" and "Authoring a Custom Layout" (experimental).
5. `plugin.cfg` `version` field reads `0.2.0` exactly (no `-pre` / `-alpha` / `-dev` suffix). `CHANGELOG.md` has a v0.2.0 entry naming all breaking changes (`PentaTileAtlasContract` deletion, `template_image` → `bitmask_template` rename, `fallback_tile_set` @export removal, separate Penta H/V class merge, overlay-layer deletion, etc.).
6. Downloading the v0.2.0 GitHub Release zip and extracting to a fresh Godot 4.6 project produces a working demo with no errors on first run; ATTRIBUTION.md is present at the addon root.
7. Final LOC audit confirms `addons/penta_tile/` total surface area stays under TileMapDual's equivalent — the result included in the release notes.

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 3.5 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Contract Skeleton + Penta Layouts | 5/5 | Complete (substantially superseded by Phase 2 architectural sweep) | 2026-04-26 |
| 1.1. PentaTile Rename + Penta Codename Establishment | 3/3 | Complete | 2026-04-26 |
| 2. Native Layouts + Architectural Simplification | 7/7 + retroactive AUTO_STRIP wave + UAT bug-fix sweep | **Complete.** 3 review passes clean (0 Critical, 0 Warning, 13 Info). UAT bug-fix sweep 2026-04-28 closed 7 bug classes across commits 6553380..205fb67 — 12 automated tests green, methodology codified in `02-UAT-LESSONS-LEARNED.md`. User confirmed visual UAT via the 16-mask-pattern demo scene 2026-04-28T22:00. LOC overage (1827 vs ~1500 informational trigger) carried forward; formal gate is Phase 5 final audit. | 2026-04-28 |
| 3. Public-Convention Layouts (Blob47 only; Tilesetter deferred to v0.3+) | 6/6 (5 executed + Plan 05 SKIPPED per D-86 = b) | **Complete with reduced scope per D-86 (b)** — Blob47Godot ships (TBT-03), audit deliverable + README footnote land (TBT-04, DOC-05); Tilesetter pair (TBT-01/02) + Tilesetter half of TEMPLATE-02 deferred to v0.3+ via `TBT-01-DEFERRED` / `TBT-02-DEFERRED` / `TEMPLATE-02-DEFERRED`. 15 automated tests green; matrix coverage extended to 6×18=108 combos in comprehensive_bitmask_test. Cumulative runtime LOC ~2455 (Phase 2 baseline 1827 + Phase 3 delta ~121 + measurement methodology drift; AT RISK carry-forward for Phase 5 final identity audit). No `addons/penta_tile/ATTRIBUTION.md` created (D-73 final guard). | 2026-04-29 |
| 3.5. PixelLab Layouts (variation-bank pick deferred to v2) | 5/6 | In progress — Plans 01-05 complete (generator + 2 greybox PNGs + both PIXLAB layouts + first-cell test + visual regression test against real PixelLab samples; PIXLAB-01..04 closed). Plan 06 closeout pending. | - |
| 4. Fallback Routing | 0/TBD | Not started | - |
| 5. Demo Refresh + Documentation + Release | 0/TBD | Not started | - |

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
| **(Pre-shipped flat templates) → restructured in Phase 2 (TEMPLATE-01)** | (existing PNGs migrated to co-located bundles next to layout `.gd` files) |
| **Total** | **58 / 58** |

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

The PROJECT.md identity constraint — "PentaTile must remain visibly smaller and simpler than TileMapDual" — is checked at four points across the roadmap:

- **End of Phase 1:** LOC checkpoint after the contract surface lands. The base class + AtlasSlot + PentaHorizontal/Vertical + integration in PentaTileMapLayer is the largest schema addition; if Phase 1 already pushes the budget, downstream phases have less room.
- **End of Phase 3:** LOC checkpoint after the standard 8 blob/wang/penta layouts ship. Each layout is roughly 40–80 LOC; the cumulative footprint should still stay well under TileMapDual.
- **End of Phase 3.5:** LOC contribution from the two PixelLab layouts plus the `variation_seed` deterministic-hash wiring (~80–120 LOC total for both layouts + variation pick). Re-check the cumulative footprint after the 11-layout milestone closes.
- **End of Phase 4:** Compare the runtime hot path (`_update_cells` → `layout.compute_mask` → `layout.mask_to_atlas` → `set_cell`) against v0.1's straight-line `match` to confirm no significant perf regression at demo scale.
- **Phase 5 final audit:** Total `addons/penta_tile/` LOC compared against TileMapDual's equivalent surface; result included in the release notes.

Per PROJECT.md, the quality bar is "works in my game" — visual regression on the demo is the primary verification mechanism, not a formal test suite. Demo-scale (~100–1k cells) is the only perf target; success criteria deliberately do NOT gate on perf.

Architectural anti-patterns explicitly NOT introduced (per `.planning/research/layouts/MASK_UNIFICATION.md` and the TileBitTools audit): no `EditorInspectorPlugin` polish, no Godot terrain peering-bit integration, no parallel painting API, no persistent coordinate cache, no watcher / signal-fanout systems, no multi-terrain transitions, no quarter-tile compositor.

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
- LOC checkpoint: this phase must not break the identity guardrail ("visibly smaller and simpler than TileMapDual").

**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 6 to break down — but only after v0.2.0 ships)

---
*Roadmap re-spun: 2026-04-25 after v0.2 pivot to layout library*

# Phase 2: Native Layouts + Architectural Simplification — Context

**Gathered:** 2026-04-26 (re-discussion / fifth supersession round)
**Supersedes:** the prior 02-CONTEXT.md authored at commit 8ca3231 (D-28..D-46), which is now HISTORICAL
**Status:** Ready for planning

> **Reading order for downstream agents.** This CONTEXT.md is the operative artifact. The architectural decisions it relies on are recorded across four supersession rounds in `02-DISCUSSION-LOG.md` (D-47..D-67). The fifth supersession round at the bottom of that log records this re-discussion. Read both files together: the log explains *why* every decision is what it is; this file states *what* the decisions are and where the open gates remain.

<domain>
## Phase Boundary

Phase 2 ships **five native layout subclasses** plus a sweeping architectural simplification of the v0.1/Phase 1 surface. Concretely:

### New layouts (5 ship)

| Layout | Atlas | Mask | Grid model |
|---|---|---|---|
| `PentaTileLayoutDualGrid16` | 4×4 (16 tiles) | 4-bit corner (TL=1/TR=2/BL=4/BR=8) | dual |
| `PentaTileLayoutWang2Edge` | 4×4 (16 tiles) | 4-bit edge (CR31 N=1/E=2/S=4/W=8) | single |
| `PentaTileLayoutWang2Corner` | 4×4 (16 tiles) | 4-bit corner (CR31 NE=1/SE=2/SW=4/NW=8) | single |
| `PentaTileLayoutMinimal3x3` | 3×3 (9 tiles) | 4-bit edge | single |
| `PentaTileLayoutPenta` (merged from Phase 1's H/V pair) | 1..5 × N strip × axis | 4-bit corner (Penta-anchored) | dual |

### Architectural sweep (delete a lot)

- **Delete `PentaTileAtlasContract` entirely.** `layout: PentaTileLayout` lives directly on `PentaTileMapLayer`. No wrapper; no `version: int`; no `variation_seed`; no `_DEFAULT_LAYOUT` static singleton. Per the no-forward-compat policy in [CLAUDE.md](../../../CLAUDE.md), there is no migration shim.
- **Delete the runtime `_overlay_layer`.** `PentaTileMapLayer` has exactly ONE child visual layer after Phase 2. All 5 archetypes (Fill / Border / InnerCorner / OuterCorner / OppositeCorners) are dispatched from a single layer; OppositeCorners is synthesized at load time. `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, and `AtlasSlot.diagonal_complement_atlas_coords` are removed.
- **Merge `PentaTileLayoutPentaHorizontal` + `PentaTileLayoutPentaVertical`** into a single `PentaTileLayoutPenta` class with `axis: Axis = HORIZONTAL` enum and `tile_count: TileCountMode { AUTO, AUTO_STRIP, ONE = 1, TWO = 2, THREE = 3, FOUR = 4, FIVE = 5 }` enum. Five progressive synthesis modes; AUTO is dimension-only, AUTO_STRIP is per-strip detection.
- **New slot ordering** across all Penta modes: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. **OuterCorner is implicit** — synthesized from slot 0's corners; never has a dedicated slot.
- **Rename `template_image` → `bitmask_template`.** Single PNG per layout serves as BOTH the inspector preview AND the prototyping fallback's source pixels. **Hide `fallback_tile_set`** from the inspector (replaced by `get_fallback_tile_set() -> TileSet` virtual that codegens at first call). **Delete `decoder_image`** (was speculative).
- **Co-locate bundled PNGs** next to layout `.gd` files. Tetra has 10 PNGs in `addons/penta_tile/layouts/penta_tile_layout_penta/` (5 modes × 2 axes); single-variant layouts use flat siblings under `addons/penta_tile/layouts/`. The entire `addons/penta_tile/templates/` folder is deleted; `addons/penta_tile/contracts/` folder is deleted; `addons/penta_tile/penta_tile_template.png` (original v0.1 reference) is deleted.

### What Phase 2 does NOT do (consumed in later phases)

- Fallback routing wiring (`tile_set == null` → `layout.get_fallback_tile_set()`) lands in Phase 4. Phase 2 only ships the codegen virtual + the bundled PNGs that feed it.
- TileBitTools-decoded layouts (Blob47Godot, TilesetterWang15, TilesetterBlob47) → Phase 3.
- PixelLab layouts → Phase 3.5.
- Demo refresh + README + CHANGELOG + release tag → Phase 5.

### Scope footprint

- **30 of 56 v1 requirements** owned by this phase.
- **17 success criteria** in ROADMAP.md.
- **7 waves** locked (see D-68 below).
- **Estimated +400-600 LOC** of net GDScript over the Phase 1 baseline (~530 LOC); cumulative ~930-1130 LOC. End-of-Phase identity-guardrail audit per ROADMAP.md.

</domain>

<decisions>
## Implementation Decisions

Decision IDs in this round start at **D-68**, continuing the trail in `02-DISCUSSION-LOG.md`. The architectural decisions D-47..D-67 are recorded across the **first**, **second**, **third**, and **fourth supersession rounds** in that log; this round is the **fifth supersession** and adds operational decisions only — no architectural changes.

### Wave breakdown

- **D-68: The 7-wave breakdown from the FOURTH SUPERSESSION (D-67) is locked verbatim; not re-litigated this round.** The size of Phase 2 (~30 reqs, 17 success criteria) was discussed and the user chose to keep it as one phase rather than split into Phase 2.0 / 2.5 — the dependency graph is tight enough that a split would not buy clarity.
  - **Wave 1 — Pre-work: Phase 1 verification migration + base-class renames.** Migrate `01-VERIFICATION.md`'s 26 tests (LAYER-05) to the new API surface — rewrites against `layout: PentaTileLayout` + `PentaTileLayoutPenta(axis=...)` + `bitmask_template` + single-layer dispatch. New tests added for TWO/THREE/FIVE modes + AUTO_STRIP. Phase 1's `01-VERIFICATION.md` marked historical. Rename `template_image` → `bitmask_template` on `PentaTileLayout` base; remove `fallback_tile_set` @export; add `get_fallback_tile_set()` virtual stub; delete `decoder_image`.
  - **Wave 2 — Synthesis machinery + overlay deletion + contract deletion + demo rebind.** Build `_synthesize_strip(strip_index, mode)` covering all 5 modes (ONE/TWO/THREE/FOUR/FIVE); fill the `get_fallback_tile_set()` stub from Wave 1 with runtime TileSet construction + collision/occlusion/navigation polygon copy. Delete `_overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, `AtlasSlot.diagonal_complement_atlas_coords`. Delete `PentaTileAtlasContract` class + `addons/penta_tile/contracts/` folder + `penta_tile_atlas_contract.gd` + `addons/penta_tile/penta_tile_template.png`. Delete the static `_DEFAULT_LAYOUT` singleton at `penta_tile_map_layer.gd:55-58, 193-198`. Replace `atlas_contract` property with `layout: PentaTileLayout` (idempotence guard + disconnect-before-reconnect on `layout.changed`). **Atomically rebind `addons/penta_tile/demo/penta_tile_demo.tscn`** — non-skippable Wave 2 acceptance criterion (LAYER-04).
  - **Wave 3 — Penta layout merge.** Merge `PentaTileLayoutPentaHorizontal` + `Vertical` into `PentaTileLayoutPenta` with `axis: Axis = HORIZONTAL` + `tile_count: TileCountMode { AUTO, AUTO_STRIP, ONE = 1, TWO = 2, THREE = 3, FOUR = 4, FIVE = 5 }`. Hide `bitmask_template` via `_validate_property` (axis × mode lookup table). Wire to `_synthesize_strip()` from Wave 2.
  - **Wave 4 — 4 native layouts in parallel.** DualGrid16, Wang2Edge, Wang2Corner, Min3x3 ship using the new conventions + flat-sibling PNG bundles. Each layout's `bitmask_template` and `get_fallback_tile_set()` wired up.
  - **Wave 5 — Asset relocation.** Delete `addons/penta_tile/templates/` folder. Migrate the 5 existing flat PNGs to co-located paths: 10 in `addons/penta_tile/layouts/penta_tile_layout_penta/{one,two,three,four,five}_{horizontal,vertical}.png`; 4 flat siblings (`penta_tile_layout_dual_grid_16.png`, `penta_tile_layout_wang_2_edge.png`, `penta_tile_layout_wang_2_corner.png`, `penta_tile_layout_minimal_3x3.png`). Update / rename the bitmask generator script (renamed from `_generate_greybox_templates.py`).
  - **Wave 6 — AUTO/AUTO_STRIP detection + warnings + baseline capture + demo refresh.** Implement detection algorithms (PENTA-SYNTH-02/03). Wire `update_configuration_warnings()` per PENTA-SYNTH-08 (atlas axis 0/6+, explicit-mode mismatch, AUTO_STRIP gaps). Capture FOUR-mode regression baseline per PENTA-SYNTH-12. Demo exercises ONE/FOUR/FIVE at minimum.
  - **Wave 7 — Closeout.** LOC checkpoint vs Phase 1 baseline (~530 LOC) flagging if cumulative materially exceeds ~1100. CHANGELOG entries per DOC-04.

### Plan-phase gates (open questions; plan-phase MUST resolve before Wave 2 task generation)

- **D-69: PENTA-SYNTH-05 ONE-mode sub-region anchoring is a HARD plan-phase gate.** The geometric question — *"where in slot 0 do the synthesized archetypes' sub-regions live? what tile-size constraints apply (square only? minimum dimensions?)? how does the anchoring degrade on non-square tiles?"* — is genuinely UNDEFINED. Spikes 001/002/003 covered DECODER feasibility, not synthesis-from-a-single-source. The user explicitly declined a Spike 004 round in this re-discussion (their words: *"i have no clue what spiking is, i just want this phase to be executed asap"*). Therefore: **plan-phase MUST lock the anchoring spec as a load-bearing decision, with explicit justification for the chosen anchoring convention, before Wave 2 generates tasks.** Required deliverables in PLAN.md:
  1. A diagram (ASCII or PNG) showing where each archetype's sub-rect lives within slot 0 for ONE mode.
  2. Tile-size constraints (e.g., "minimum 4×4 px," "must be square," or whatever the chosen convention requires).
  3. Degradation behavior on non-square / mid-tier-mode atlases (does sub-region anchoring still apply when slot 1 is authored? what's the contract?).
  4. The same anchoring math used in TWO/THREE/FOUR mode synthesis where slot 0 still feeds the missing archetypes.
  - Plan-phase failure mode to guard against: inventing a convention without verification. Mitigation: the plan-checker reviews the anchoring decision against `_synthesize_strip` task specs.

- **D-70: PENTA-SYNTH-06 polygon transform math is a HARD plan-phase gate.** D-49 (FIRST SUPERSESSION) commits to copying source-tile collision/occlusion/navigation polygons (`Vector2[]`) to synthesized tiles with appropriate transforms. The math is undefined. **Plan-phase MUST specify** before Wave 2 generates tasks:
  1. Polygon vertex transformation formulas under each `TRANSFORM_FLIP_H` / `FLIP_V` / `TRANSPOSE` flag (and combinations) — `Transform2D` or per-vertex math, with the local-origin convention pinned (tile-center vs tile-top-left).
  2. Sub-region polygon clipping approach for ONE/TWO/THREE modes where the synthesized tile uses only PART of slot 0's polygon area. Sutherland-Hodgman is the standard algorithm; alternatives (axis-aligned-rect intersection only, since sub-regions are rectangular) may be cheaper.
  3. Edge cases: a polygon that crosses the sub-region boundary; a polygon that lies entirely outside the sub-region (drop it); occlusion polygons with `polygon_index` > 0 (multiple polygons per tile); navigation polygons with hole loops.
  4. What is NOT copied (locked): animation frames, custom data layers, probability weights, Y-sort origin (PENTA-SYNTH-06 documents this as a layout-choice tradeoff).

### Documentation drift fix

- **D-71: Phase 1 directory name drift acknowledged and routed.** The actual on-disk directory is `.planning/phases/01-contract-skeleton-tetra-layouts/`. References in `REQUIREMENTS.md` (LAYER-05), `ROADMAP.md`, and `PROJECT.md` to `01-contract-skeleton-penta-layouts/` are stale — Phase 1.1's PentaTile rename swept source code + saved resources + most docs but left phase directory names untouched. This CONTEXT.md (canonical_refs section below) authors against the **actual** path. The cross-doc drift is captured as a deferred cleanup item (out of Phase 2 scope per the breaking-changes-but-no-cleanup-bloat heuristic; can be addressed in any future docs sweep). Downstream agents reading this CONTEXT.md should NOT trust the `penta-layouts/` paths in REQUIREMENTS.md / ROADMAP.md / PROJECT.md without first checking that the actual directory is named `tetra-layouts/`.

### Architectural decisions (locked elsewhere — pointers only)

The locked architecture is in the supersession trail. This section maps each requirement family to its source decision so plan-phase doesn't have to scan four supersession blocks.

| Requirement family | Locked at | Summary |
|---|---|---|
| LAYER-01 (`layout: PentaTileLayout` direct) | THIRD SUPERSESSION D-56 | No `PentaTileAtlasContract` wrapper |
| LAYER-02 (`_resolve_slot` reads `self.layout`) | THIRD SUPERSESSION D-56 | + delete `_DEFAULT_LAYOUT` singleton |
| LAYER-03 (file/folder deletions) | THIRD SUPERSESSION D-56, D-59; FOURTH D-66 | Contracts folder + atlas-contract `.gd` + v0.1 PNG + templates folder all deleted |
| LAYER-04 (demo scene rebind) | Wave 2 acceptance criterion (this round D-68) | Atomic with contract deletion |
| LAYER-05 (Phase 1 verification migration) | Wave 1 pre-work (this round D-68) | New tests added for TWO/THREE/AUTO_STRIP |
| LAYOUT-03 (`bitmask_template` rename) | THIRD SUPERSESSION D-59 | Single user-facing image; `decoder_image` deleted; `fallback_tile_set` hidden |
| LAYOUT-04 (`AtlasSlot` field deletion) | FIRST SUPERSESSION D-51 | `diagonal_complement_atlas_coords` deleted |
| LAYOUT-06 (`get_fallback_tile_set()` virtual) | THIRD SUPERSESSION D-59 | Default impl builds TileSet from `bitmask_template` at first call |
| LAYOUT-07 (co-located PNGs) | FOURTH SUPERSESSION D-66 | Tetra subfolder; flat siblings for single-variant |
| NATIVE-01..03, MIN3x3-01 | Carried forward unchanged | 4 single-variant layouts |
| PENTA-01 (merged class with `axis` enum) | THIRD SUPERSESSION D-57 | `PentaTileLayoutPenta` |
| PENTA-02 (`tile_count` enum) | FOURTH SUPERSESSION D-61, D-64 | 5 modes × 2 detection variants |
| PENTA-03 (visual regression vs captured baseline) | FOURTH SUPERSESSION D-67 | Baseline is fresh capture (slot ordering changed; NOT v0.1 bit-equivalence) |
| PENTA-SYNTH-01 (`tile_count` enum members) | FOURTH SUPERSESSION D-61 | `AUTO=0, AUTO_STRIP, ONE=1, TWO=2, THREE=3, FOUR=4, FIVE=5` |
| PENTA-SYNTH-02 (AUTO detect) | SECOND SUPERSESSION D-53; FOURTH D-61 | Dimension-only; uniform across strips |
| PENTA-SYNTH-03 (AUTO_STRIP detect) | FOURTH SUPERSESSION D-64 | Per-strip via `has_tile()` |
| PENTA-SYNTH-04 (no pixel inspection) | SECOND SUPERSESSION D-55 | Dimension-based only |
| PENTA-SYNTH-05 (sub-region anchoring) | **OPEN — this round D-69** | Plan-phase gate |
| PENTA-SYNTH-06 (polygons + what's not copied) | FIRST SUPERSESSION D-49 + **this round D-70** | Polygon math is plan-phase gate |
| PENTA-SYNTH-07 (overlay deletion) | FIRST SUPERSESSION D-51 | `_overlay_layer` + companions all gone |
| PENTA-SYNTH-08 (warnings) | FOURTH SUPERSESSION (warnings text per D-67) | Atlas axis 0/6+, explicit mismatch, AUTO_STRIP gaps |
| PENTA-SYNTH-09 (`_validate_property` hide) | THIRD SUPERSESSION D-60 | Class-level constant lookup table |
| PENTA-SYNTH-10 (single PNG per layout) | FOURTH SUPERSESSION D-65 | Bitmask AND fallback source |
| PENTA-SYNTH-11 (demo across modes) | FOURTH SUPERSESSION D-66 (Wave 6 in this round D-68) | ONE/FOUR/FIVE minimum |
| PENTA-SYNTH-12 (FOUR-mode baseline) | FOURTH SUPERSESSION D-67 | Captured baseline; protocol per REQUIREMENTS.md |
| PREVIEW-01 (`bitmask_template` inline) | THIRD SUPERSESSION D-59 | Free via Godot's `Texture2D` preview |
| PREVIEW-02 (`get_fallback_tile_set()` codegen) | THIRD SUPERSESSION D-59 | No `.tres` fallback files |
| TEMPLATE-01 (PNG locations) | FOURTH SUPERSESSION D-66 | `layouts/` folder; `templates/` deleted |
| TEMPLATE-03 (generator script) | FOURTH SUPERSESSION D-66 | Renamed; produces new structure |
| TEMPLATE-04 (slot positions match `mask_to_atlas`) | Carried forward | Visual regression of fallback output |

### Claude's Discretion

The user explicitly waved off the four-concerns deep-dive with *"only discuss things you deam critical or invalid or a potential issue."* Items NOT escalated this round and left to Claude/planner discretion:

- **Wave breakdown size.** The user accepted the 7-wave plan from D-68 without revision. Plan-phase may refine wave decomposition or sub-task ordering as long as the dependency invariants hold (Wave 1 pre-work → Wave 2 synthesis machinery → Wave 3 merge → Wave 4 native layouts in parallel → Wave 5 asset relocation → Wave 6 detection + baseline + demo → Wave 7 closeout). Don't split Phase 2 into 2.0/2.5 retroactively without re-discussion.
- **Phase 1 verification migration test count.** Wave 1 starts from 26 tests; new tests for TWO/THREE/FIVE modes + AUTO_STRIP grow that count. Final number is plan-phase's call.
- **Exact `update_configuration_warnings()` text** for the three failure modes in PENTA-SYNTH-08 (atlas axis 0/6+, explicit-mode mismatch, AUTO_STRIP gaps) — wording is plan-phase's call provided each failure mode is named clearly.
- **`_synthesize_strip` internal API** (helper function signature, return type, caching strategy when source `tile_set` changes) — plan-phase picks; constraint is that synthesis is deterministic and re-runs only when `layout`, `axis`, `tile_count`, or source `tile_set` changes (PENTA-SYNTH-06).
- **Pixel-hash baseline storage strategy for PENTA-SYNTH-12** — REQUIREMENTS.md offers two options (`Image.get_data().hash()` int OR `Image.save_png()` baseline file). Plan-phase picks; int hash is cheaper and stricter, PNG baseline is friendlier for visual debugging.
- **File/class naming for the merged Penta layout file.** Per existing convention: `addons/penta_tile/layouts/penta_tile_layout_penta.gd` → `class_name PentaTileLayoutPenta`. The Phase 1 files (`penta_tile_layout_penta_horizontal.gd` / `_vertical.gd`) and their classes are deleted in Wave 3.
- **Generator script rename target.** `_generate_greybox_templates.py` → some new name reflecting "bitmask templates" rather than "greybox templates" (e.g., `_generate_bitmask_templates.py`). Plan-phase picks; constraint is that the script lives somewhere that can produce all 14 PNGs from data definitions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

> ⚠ **Doc drift notice.** The actual Phase 1 directory on disk is `.planning/phases/01-contract-skeleton-tetra-layouts/`. References in `REQUIREMENTS.md`, `ROADMAP.md`, and `PROJECT.md` to `01-contract-skeleton-penta-layouts/` are stale (Phase 1.1 rename did not sweep phase directory names). The paths below use the **actual** directory name. See D-71 for the deferred cleanup.

### Project + roadmap

- `.planning/PROJECT.md` — milestone scope, identity guardrails ("PentaTile must remain visibly smaller and simpler than TileMapDual"), Out-of-Scope list, Key Decisions table
- `.planning/REQUIREMENTS.md` — v1 requirements; Phase 2 owns LAYER-01..05, LAYOUT-03/04/06/07, NATIVE-01..03, MIN3x3-01, PENTA-01..03, PENTA-SYNTH-01..12, PREVIEW-01/02, TEMPLATE-01/03/04 (30 reqs total)
- `.planning/ROADMAP.md` — phase breakdown; Phase 2 success criteria 1..17 are authoritative for the merge gate
- `.planning/STATE.md` — current position; Phase 1 + 1.1 complete, Phase 2 ready to plan

### LOAD-BEARING — supersession trail (the architecture lives here)

- `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md` — **REQUIRED READING.** Records the four supersession rounds (D-47..D-67) that locked the architecture, plus the fifth supersession round (this re-discussion) at the bottom. Plan-phase, researcher, and executor agents MUST read the FIRST/SECOND/THIRD/FOURTH SUPERSESSION sections to understand WHY each decision is what it is. Skipping the log will cause agents to re-litigate decisions that took 4 iterations to lock.

### Phase 1 carry-forward (note: actual directory is `tetra-layouts/`, not `penta-layouts/` per D-71)

- `.planning/phases/01-contract-skeleton-tetra-layouts/01-CONTEXT.md` — Phase 1 decisions (D-01..D-27); the axis-swap inheritance pattern (D-16) does NOT carry forward (Phase 2 merges H/V into one class)
- `.planning/phases/01-contract-skeleton-tetra-layouts/01-VERIFICATION.md` — 26 tests against the deleted API surface; Wave 1 migrates these (LAYER-05). Marked HISTORICAL after Wave 1 completes.
- `.planning/phases/01-contract-skeleton-tetra-layouts/01-PATTERNS.md` — naming/inheritance patterns from Phase 1; the snake_case-file-matches-class-name convention still applies, but the H/V-axis-swap inheritance pattern is superseded by the merged class with `axis` enum

### Research (architecture + design)

- `.planning/research/ARCHITECTURE.md` — `_resolve_slot` design; the overlay-layer rationale (now obsolete per FIRST SUPERSESSION D-51, but useful for understanding what's being deleted)
- `.planning/research/PITFALLS.md` — alternative_tile bit packing (§1), variation determinism (§2; not relevant in Phase 2 — variation is v2), Resource property renames (§3 — read for Wave 1 LAYOUT-03 rename), setter loops + `Resource.changed` storms (§4 — read for LAYER-01 setter), `TileMapLayer.visible = false` cleanup (§7 — already mitigated, don't regress)
- `.planning/research/STACK.md` — Godot 4.6 stack; `TRANSFORM_FLIP_*` flag values that drive transform math in synthesis
- `.planning/research/layouts/MASK_UNIFICATION.md` — load-bearing: polymorphic Resource selection, code shape; the synthesis approach in Phase 2 fits this architecture
- `.planning/research/layouts/RPG_MAKER.md` — deferred RPG Maker family (v0.3+); reference for what's NOT in Phase 2 scope
- `.planning/research/layouts/TAXONOMY.md` — 24-layout catalogue
- `.planning/research/layouts/COMPARISON.md` — artist-facing layout comparison
- `.planning/research/layouts/EDITORS.md` — Tilesetter / Tiled / LDtk / Unity / RPG Maker conventions
- `.planning/research/layouts/TEMPLATE_CONVENTIONS.md` — prior-art synthesis (dandeliondino + Better Terrain + Godot stock)
- `.planning/research/layouts/TILEBITTOOLS.md` — TBT addon audit + slot tables (relevant for Phase 3, but referenced for slot-table authoring discipline)
- `.planning/research/layouts/TILESETTER_AND_GODOT.md` — Tilesetter live-doc audit; "merging points" terminology contrast with Excalibur.js's "Opposite Corners"

### External references (community vocabulary; preserved from D-32 / D-44 / D-45 / D-46 in the old CONTEXT.md)

- Excalibur.js dual-grid article — https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/ — codifies the 5-archetype dual-grid set (`Filled / Edge / InnerCorner / OuterCorner / OppositeCorners`). PentaTile uses `Border` for what Excalibur calls `Edge` (the project's pre-existing archetype name). PentaTile's canonical paint anchors mask 9 (TL+BR) as `_ROTATE_0`; Excalibur's `calculateMeshSprite()` uses the opposite anchor (mask 6 = TR+BL). Both conventions are valid; document the divergence in `PentaTileLayoutPenta`'s class-level `##` doc-comment.
- Excalibur.js half-tile-offset rationale — Phase 5 README "Implementation Notes" expansion (the offset eliminates the ambiguous-tile problem). Phase 2 makes no README change for this; flagged as a Phase 5 deliverable.
- BorisTheBrave "Classification of Tilesets" — https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/ — tileset taxonomy reference
- BorisTheBrave "Quarter-Tile Autotiling" — https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/ — confirms the 5-tile rotation set

### Codebase maps

- `.planning/codebase/ARCHITECTURE.md` — overall system architecture; v0.1's overlay-layer rationale (deleted in Phase 2 — read for what's being removed)
- `.planning/codebase/CONCERNS.md` — known concerns; "Dual-layer composition for diagonals doubles tile ops" is now resolved by overlay-layer deletion
- `.planning/codebase/CONVENTIONS.md` — naming, file layout, GDScript style
- `.planning/codebase/INTEGRATIONS.md` — Godot integration points
- `.planning/codebase/STACK.md` — language/version specifics
- `.planning/codebase/STRUCTURE.md` — file/directory structure
- `.planning/codebase/TESTING.md` — testing approach (visual regression on demo)

### v0.1 + Phase 1 source (the surface being modified)

- `addons/penta_tile/penta_tile_map_layer.gd` (~298 LOC) — the layer file. Deletes in Wave 2: `_OVERLAY_LAYER_NAME` constant (line 7), `_overlay_layer` field (line 46), `_DEFAULT_LAYOUT` static singleton (lines 55-58, 193-198), `_paint_overlay_for_slot` (lines 177-181). Renames in Wave 2: `atlas_contract` property (line 14) → `layout`. Modifies in Wave 2: `_ensure_visual_layers` (212-217 — drop overlay branch), `_paint_via_layout` (146-158 — drop overlay paint call), `_clear_visual_layers` (266-269 — drop overlay layer iteration), `_sync_visual_layers` (236-250 — drop overlay layer iteration), `_resolve_layout` (193-198 — read `self.layout` directly), `_on_contract_changed` (297-298 — rename to `_on_layout_changed`).
- `addons/penta_tile/penta_tile_atlas_contract.gd` (~52 LOC) — DELETED in Wave 2.
- `addons/penta_tile/penta_tile_atlas_slot.gd` (~30 LOC) — modified in Wave 2: drop `diagonal_complement_atlas_coords` field (LAYOUT-04).
- `addons/penta_tile/layouts/penta_tile_layout.gd` — modified in Wave 1: rename `template_image` → `bitmask_template` (LOAYUT-03); remove `fallback_tile_set` @export (LAYOUT-03); add `get_fallback_tile_set()` virtual stub (LAYOUT-06); delete `decoder_image`. Filled in Wave 2 with the default `get_fallback_tile_set()` implementation that builds a TileSet from `bitmask_template`.
- `addons/penta_tile/layouts/penta_tile_layout_penta_horizontal.gd` (~133 LOC) — DELETED in Wave 3 (merged into new `penta_tile_layout_penta.gd`).
- `addons/penta_tile/layouts/penta_tile_layout_penta_vertical.gd` (~40 LOC) — DELETED in Wave 3.
- `addons/penta_tile/contracts/` — entire folder DELETED in Wave 2 (4 `.tres` files: `default_horizontal.tres`, `default_vertical.tres`, `penta_horizontal_default.tres`, `penta_vertical_default.tres`).
- `addons/penta_tile/penta_tile_template.png` (the v0.1 reference at addon root) — DELETED in Wave 2.
- `addons/penta_tile/templates/` — entire folder DELETED in Wave 5 (5 PNGs migrate to new co-located paths under `addons/penta_tile/layouts/`; the generator script + README.md are renamed/relocated as part of the migration).
- `addons/penta_tile/demo/penta_tile_demo.tscn` — modified in Wave 2: replace `[ext_resource ... contracts/default_horizontal.tres]` with the new `layout` ExtResource (LAYER-04). Atomic with contract deletion; non-skippable.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets (Phase 1 already shipped)

- **`PentaTileLayoutPentaHorizontal.mask_to_atlas`** (16-state match) — the case-table is being relocated into `PentaTileLayoutPenta` with the new slot ordering (slot 0 = IsolatedCell, slot 1 = Fill, slot 2 = Border, slot 3 = InnerCorner, slot 4 = OppositeCorners). The 16 cases each remap to the new slot indices; OuterCorner cases now resolve to slot 0 with rotation transforms.
- **`_pack_alternative(alt_id, transform_flags)`** helper on `PentaTileLayout` base (Phase 1 D-04, LAYOUT-05) — preserved unchanged. All Phase 2 layouts use it for transform packing.
- **`_make_slot` axis-swap helper pattern** — superseded. The merged `PentaTileLayoutPenta` branches on `self.axis` inside a single `_make_slot` instead of overriding the helper in a subclass.
- **Idempotence guard + `Resource.changed` hygiene** (Phase 1 D-08, PITFALLS §4) — preserved verbatim on the renamed `layout` setter.
- **`TileSetAtlasSource.get_atlas_grid_size()` + `has_tile()`** — the sole inputs to AUTO / AUTO_STRIP detection. No pixel content read (PENTA-SYNTH-04, D-55).

### Established patterns (carry forward)

- **Snake_case file matches class name** — applies to all 5 new layout files (`penta_tile_layout_penta.gd`, `penta_tile_layout_dual_grid_16.gd`, `penta_tile_layout_wang_2_edge.gd`, `penta_tile_layout_wang_2_corner.gd`, `penta_tile_layout_minimal_3x3.gd`).
- **`@tool`-mode safety** — `update_configuration_warnings()` for malformed atlases; `_validate_property` for inspector hiding.
- **Lazy creation** — `_primary_layer` lazily created in `_ensure_visual_layers`. After overlay deletion, this is the ONLY visual layer, so the helper simplifies considerably.
- **Single-grid pipeline** — already wired in Phase 1 (D-06; `_mark_affected_single_grid_cells` at line 134). Wang2Edge / Wang2Corner / Min3x3 are its first consumers in Phase 2.

### Integration points

- **`PentaTileLayout.get_fallback_tile_set() -> TileSet`** (NEW virtual on base) — read by `PentaTileMapLayer` when `tile_set == null`. Default implementation builds from `bitmask_template`; layouts can override.
- **`PentaTileMapLayer.layout: PentaTileLayout`** (NEW @export, replaces `atlas_contract`) — typed picker auto-registers all subclasses via `class_name`.
- **`_synthesize_strip(strip_index, mode)`** (NEW helper on `PentaTileLayoutPenta` or a synthesis utility module) — called from the layout's setup path; outputs a runtime `TileSet` owned by `PentaTileMapLayer._primary_layer`. User's source `tile_set` is never mutated. Re-runs only when `layout`, `axis`, `tile_count`, or source `tile_set` changes (PENTA-SYNTH-06).

### LOC budget (estimate; refine in plan-phase)

| File | Action | LOC delta |
|---|---|---|
| `penta_tile_map_layer.gd` (existing) | Delete overlay code path; rename `atlas_contract` → `layout`; delete `_DEFAULT_LAYOUT` | -50 to -70 |
| `penta_tile_atlas_contract.gd` | DELETE | -52 |
| `penta_tile_atlas_slot.gd` (existing) | Drop `diagonal_complement_atlas_coords` | -3 |
| `penta_tile_layout.gd` (existing) | Rename `template_image`; drop `fallback_tile_set`; add `get_fallback_tile_set()` virtual; drop `decoder_image` | +20 to +30 |
| `penta_tile_layout_penta_horizontal.gd` + `_vertical.gd` | DELETE | -170 |
| `penta_tile_layout_penta.gd` (NEW) | Merged class with `axis` + `tile_count` enums + `_validate_property` hide + class-level constant lookup table for 10 PNGs + delegation to `_synthesize_strip` | +200 to +280 |
| `_synthesize_strip()` machinery (NEW; location TBD) | 5-mode synthesis + collision polygon copy + runtime TileSet construction | +250 to +400 |
| `penta_tile_layout_dual_grid_16.gd` (NEW) | 16-state corner mask | ~80 |
| `penta_tile_layout_wang_2_edge.gd` (NEW) | 16-state edge mask, single-grid | ~80 |
| `penta_tile_layout_wang_2_corner.gd` (NEW) | 16-state corner mask, single-grid | ~80 |
| `penta_tile_layout_minimal_3x3.gd` (NEW) | 16-state edge mask on 3×3 grid, single-grid | ~60 |
| Generator script (rename + restructure) | Produce 14 PNGs from data definitions | +50 to +100 |
| Phase 1 verification migration | Test rewrites + new TWO/THREE/AUTO_STRIP tests | +100 to +200 |
| **Net add to addon** | | **+700 to +1000 LOC** |

Cumulative end-of-Phase-2 estimate: **~1230-1530 LOC** of GDScript across `addons/penta_tile/`. Trends close to TileMapDual's surface area (~700-900 LOC on its own scripts; full TileMapDual addon larger). **End-of-Phase-2 LOC checkpoint required per ROADMAP identity guardrails.** If the cumulative materially exceeds ~1500, flag for design review (e.g., is `_synthesize_strip` over-spec'd?).

### Migration / breaking changes

Per the [no-backwards-compat AND no-forward-compat policy](../../../CLAUDE.md#breaking-changes-policy-hard-rule), Phase 2 ships breaking changes freely:

- `atlas_contract: PentaTileAtlasContract` → `layout: PentaTileLayout` (any saved scene with the old property loses it on first load; demo scene rebound atomically)
- Slot ordering changed across all Penta atlases (slot 3 was OuterCorner, is now InnerCorner; slot 0 was Fill, is now IsolatedCell). Existing artist atlases authored against v0.1 / Phase 1 conventions WILL render incorrectly.
- `template_image` → `bitmask_template` rename (per PITFALLS §3, Resource property renames orphan saved scenes silently in Godot 4.6 — but per breaking-changes policy, no `@export_storage` shadow + `__migrate__()` two-step is added; CHANGELOG documents the breakage).
- `fallback_tile_set` no longer @export'd (any scene that set it loses the override; codegen replaces).
- `decoder_image` deleted.
- `PentaTileLayoutPentaHorizontal` + `PentaTileLayoutPentaVertical` classes deleted (third-party scenes referencing those `class_name` symbols break).
- `_overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, `AtlasSlot.diagonal_complement_atlas_coords` all deleted (third-party code reading these breaks).
- All template PNG paths changed (`templates/*.png` → `layouts/penta_tile_layout_penta/*.png` or flat siblings).

CHANGELOG entries required for ALL of the above (DOC-04 in Phase 5).

</code_context>

<specifics>
## Specific Ideas

### Phase 1 directory drift fix

Captured in D-71: the actual on-disk directory is `01-contract-skeleton-tetra-layouts/`. References in `REQUIREMENTS.md`, `ROADMAP.md`, `PROJECT.md` to `01-contract-skeleton-penta-layouts/` are stale. This CONTEXT.md uses the actual path everywhere; the cross-doc fix is deferred (see `<deferred>` below).

### Penta canonical paint anchoring (preserved from old D-32 / D-46)

PentaTile's canonical paint anchors **mask 9 (TL+BR, "\\" diagonal) as the unrotated case** for the OppositeCorners archetype. Excalibur.js's `calculateMeshSprite()` uses the opposite anchor (mask 6 = TR+BL = "/" diagonal). Both conventions are valid; PentaTile picks mask 9 = `_ROTATE_0` because it matches the project's TL=1 lowest-bit-first ordering (also used in `draw_corner_mask` in the bitmask generator script and across all corner-mask layouts in the project).

Document the divergence in `PentaTileLayoutPenta`'s class-level `##` doc-comment so an artist cross-referencing the Excalibur article (or a developer porting code) is not surprised by mirrored output. Suggested doc-comment: *"Note: PentaTile anchors mask 9 (TL+BR) as the unrotated OppositeCorners case. The Excalibur.js dual-grid reference uses the opposite anchor (mask 6 = TR+BL); both are valid conventions. If you author your OppositeCorners tile against the Excalibur convention, mask 6 and mask 9 will appear swapped — flip the sprite horizontally to match PentaTile's anchoring."*

### Marching Squares ↔ Wang2Edge cross-reference (preserved from old D-44)

In `PentaTileLayoutWang2Edge`'s class-level `##` doc-comment AND `description` field: *"16-tile 4-bit edge mask (CR31 N=1/E=2/S=4/W=8). Also known as 'Marching Squares' in algorithm-centric writeups (e.g., the Excalibur.js dual-grid article); same atlas, different vocabulary."* Lands in Wave 4 as part of the layout implementation. Helps users arriving via marching-squares search terms find the right layout.

### "Sacrificing quality for less quantity" — locked design intent

The five progressive modes (ONE/TWO/THREE/FOUR/FIVE) are intentionally tiered for fast prototyping (per FOURTH SUPERSESSION D-61). Mid-tier modes (TWO/THREE/FOUR) deliberately allow visual inconsistencies between artist-authored slots and synthesized archetypes. This is documented intent, not a bug. Plan-phase should NOT add complexity to detect/repair these inconsistencies (e.g., color matching, sub-region blending) — the artist owns the consistency tradeoff and chooses the mode accordingly.

### Codename discipline — "Penta" usage

Per CLAUDE.md "Coined-Term Discipline": "Penta" is reserved exclusively for the 5-archetype tileset format. Use `PentaTileLayoutPenta` (the merged class) and `PentaTileLayoutPenta(axis=...)` instances; do NOT coin "Penta" prefixes for unrelated subsystems. The synthesis machinery (`_synthesize_strip`) is named for what it does, not for the codename.

</specifics>

<deferred>
## Deferred Ideas

### Pushed to other phases (within v0.2 scope)

- **Fallback routing wiring** (`tile_set == null` → `layout.get_fallback_tile_set()`) — Phase 4 (PREVIEW-03/04). Phase 2 ships only the codegen virtual + bundled PNGs.
- **TileBitTools-decoded layouts** (Blob47Godot, TilesetterWang15, TilesetterBlob47) — Phase 3 (TBT-01..04, TEMPLATE-02, DOC-05).
- **PixelLab layouts** (TopDown, SideScroller) + variation-bank wiring — Phase 3.5 (PIXLAB-01..04). Variation-bank deterministic pick (VAR-PIXEL-01) deferred to v2 with VAR-01.
- **README "Layouts" section** + "Upgrading from 0.1.x" + "Authoring a Custom Layout" + CHANGELOG + demo refresh + release tag — Phase 5 (DEMO-01..03, DOC-01..05, REL-01..03).
- **End-of-Phase-2 LOC checkpoint** vs identity guardrail — Wave 7 closeout (D-68).
- **Phase 5 README half-tile-offset rationale paragraph** (preserved from old D-45) — Phase 5 deliverable, not Phase 2.

### Pushed to v0.3+ / future milestones

- **Y-axis variation** (VAR-01) — design-coupled with MULTITERR-01 + VAR-PIXEL-01; resolve together.
- **Top-tile support** (TOP-01).
- **RPG Maker A1/A2/A4 subtile composition** (RPGM-01..03) — research at `.planning/research/layouts/RPG_MAKER.md` recommends offline importer (Option 1) for v0.3+.
- **Multi-terrain transitions** (TERRAIN-01) and multi-terrain in one tileset (MULTITERR-01..05).
- **PentaBake** (procedural OppositeCorners generator) — TOOL-01. Now superseded by the synthesis machinery this phase ships, but the standalone tool is still parked.
- **Wang/blob → PentaTile converter** (TOOL-02), Tiled `.tsx` / LDtk `.ldtk` importers (IMPORT-01/02).
- **Shader fallback for diagonal compositing** (PERF-01) — partially obviated by overlay-layer deletion.
- **Asset Library distribution, MkDocs site, formal GUT test suite** (DIST-01/02).

### Doc-drift cleanup (deferred per D-71)

- Rename `.planning/phases/01-contract-skeleton-tetra-layouts/` → `01-contract-skeleton-penta-layouts/` OR fix the references in `REQUIREMENTS.md` (LAYER-05), `ROADMAP.md`, `PROJECT.md` to use the actual path. Out of Phase 2 scope. Can be folded into any Phase 5 docs sweep, or addressed in a standalone docs cleanup phase.

### Items considered and rejected during the supersession trail (preserved from the historical CONTEXT.md so future agents don't re-litigate)

- **Separate `Penta5Horizontal` / `Penta5Vertical` classes** — rejected in FIRST SUPERSESSION D-47..D-52 in favor of synthesis on the merged class.
- **`PentaTileLayoutSingleTile` separate class** for ONE-mode prototyping — rejected in SECOND SUPERSESSION D-53 in favor of `tile_count: ONE` mode on the merged Penta layout.
- **`needs_diagonal_overlay() -> bool` virtual** for runtime overlay-skip — rejected in FIRST SUPERSESSION D-51 in favor of full overlay-layer deletion.
- **`version: int` field on Resources** for forward-compat — rejected in THIRD SUPERSESSION D-56 per the no-forward-compat policy.
- **`decoder_image: Texture2D`** speculative property — rejected in THIRD SUPERSESSION D-59 (no consumer; deleted).
- **Two PNGs per layout** (`atlas.png` + `bitmask.png` split) — rejected in FOURTH SUPERSESSION D-65 in favor of single PNG per layout serving both roles.
- **Strict fill-percentage slot ordering** (100% → 75% → 50% → 50%) for the Penta archetypes — rejected in FOURTH SUPERSESSION D-63 in favor of visual-frequency ordering (Border at slot 2 before InnerCorner at slot 3).

</deferred>

---

*Phase: 02-native-layouts*
*Context regathered: 2026-04-26 (fifth supersession round)*
*Supersedes: 02-CONTEXT.md @ commit 8ca3231 (D-28..D-46) — historical*

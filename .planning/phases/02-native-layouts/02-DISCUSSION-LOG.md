# Phase 2: Native Layouts — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 02 — Native Layouts
**Areas discussed:** Layout name (Tetra5 root), 5th-tile rotation semantics, Dispatcher overlay-skip mechanism, Phase scope routing

---

## Trigger — user-driven scope expansion

The user asked to extend Phase 2's original scope (DualGrid16 / Wang2Edge / Wang2Corner / Min3x3) by appending a **5-tile** Tetra layout pair. The 5th tile is an explicit "edge connector" / diagonal art slot that obviates the runtime `_overlay_layer` for masks 6 (NE+SW) and 9 (NW+SE). Architectural lift: the dispatcher learns to skip the overlay layer when the active layout doesn't need it, which incidentally also benefits all other Phase-2/3/3.5 non-Tetra4 layouts.

User's framing of the architectural change:
- 4 tile = 2 child tilemap layers (primary visual + diagonal overlay)
- 5 tile, dual grid = 1 child tilemap layer (primary visual only)
- All other layouts = 1 child tilemap layer (primary visual only)

Note: the user's "no need for additional tilemap layers" framing for non-Tetra4 layouts conflates the user's own painted layer (the **logic** layer, hidden via `self_modulate.a`) with the visual layers. All layouts always need *one* visual TileMapLayer; what disappears for non-Tetra4 layouts is specifically the **overlay** / diagonal-composition layer (the 3rd one).

---

## Layout name

**Question:** What should the new 5-tile Tetra layouts be called?

### Round 1 (initial options)

| Option | Description | Selected |
|---|---|---|
| TetraEdge (Recommended) | Names the 5th tile's role — diagonal/edge connector. | |
| TetraPlus | Generic 'Tetra + one more tile'. | |
| Tetra5 | Numeric tile count. | |
| TetraConnected | Emphasizes diagonal connection. | |

**User's response:** "Either Tetra5 or TetraDiagonal, as 'edge' maybe be ambigious with the border tile. is there a standard name for those edge connector tiles? if so, i might want to use the standard and most popular name. research more and ask me again."

**Notes:** User flagged the `Edge` / `Border` archetype collision (TetraTile's existing `Border` archetype = Excalibur.js's `Edge` archetype). User asked Claude to research the community-standard name before re-asking.

### Research finding

Searched the autotile/Wang/dual-grid community vocabulary. Excalibur.js's dual-grid article ([Dual Tilemap Autotiling Technique](https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/)) codifies the 5-archetype dual-grid set:

> "Graphics Tilemap (overlay) Only 5 tiles: `Edge`, `InnerCorner`, `OuterCorner`, `Filled`, or `Opposite Corners`"

So the standard community name for the **5th archetype tile** is `Opposite Corners` (or `OppositeCorners`). BorisTheBrave's "Classification of Tilesets" ([link](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/)) doesn't override this. BorisTheBrave's "Quarter-Tile Autotiling" ([link](https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/)) confirms 5-tile rotation sets are sufficient for the entire tileset when tiles rotate.

The `Opposite Corners` term is for the **5th tile**, not the **layout itself** — leaving room for picking a layout class name.

### Round 2 (research-informed options)

| Option | Description | Selected |
|---|---|---|
| Tetra5 (Recommended) | TetraTile's own number-suffix convention (Wang2Edge, DualGrid16, Blob47, Min3x3). Terse, scannable. Templates: `tetra_5_horizontal.png` / `tetra_5_vertical.png`. | ✓ |
| TetraOpposite | Aligns with Excalibur.js community term. Reads slightly oddly out loud. | |
| TetraOppositeCorners | Spelled-out community term — unambiguous but long; class names get repetitive in Godot's typed-picker. | |
| TetraDiagonal | User's earlier instinct. 'Diagonal' is overloaded (diagonal stride vs the 6/9 disconnected-diagonal mask). | |

**User's choice:** `Tetra5 (Recommended)`

**Notes:**
- The community term `Opposite Corners` is preserved as the *archetype* name (used for the constant `_OPPOSITE_CORNERS`, in code comments, in the layout's `description` field, and in the templates/README cross-reference) — the choice is to use it where it adds clarity (the tile name) rather than where it adds friction (the class name).
- `Tetra5` matches `Wang2Edge` / `Wang2Corner` / `Blob47Godot` / `TilesetterWang15` / `TilesetterBlob47` / `Minimal3x3` / `DualGrid16` — every other layout in the project that is named by tile count uses a number suffix.

---

## 5th-tile rotation semantics

**Question:** How does the 5th tile cover the two diagonal masks (6 = NE+SW, 9 = NW+SE)?

| Option | Description | Selected |
|---|---|---|
| One sprite, runtime rotates (Recommended) | True 5-tile. Author paints ONE diagonal asset; runtime applies _ROTATE_0 / mirror for the second case. Smallest atlas, biggest art saving. | ✓ |
| Two sprites (becomes 6-tile) | Each diagonal gets its own asymmetric art. Maximum artistic freedom; layout no longer "5-tile". | |
| Author-mirrored sentinel | Author paints mask 6 only; runtime auto-FLIPS for mask 9. More fragile. | |

**User's choice:** `One sprite, runtime rotates (Recommended)`

**Notes:** Locks in `Tetra5` as a true 5-slot atlas. The exact transform_flags constant for mask 6 vs mask 9 (e.g. `_ROTATE_90` vs `TRANSFORM_FLIP_H`) is left to the planner — the choice is between "match the OUTER_CORNER rotation table for visual continuity" and "match the simplest pixel-flip semantics." Either yields visually correct output if the 5th-tile sprite is painted to match v0.1's overlay-composed reference.

---

## Dispatcher / overlay-skip optimization

**Question:** How does TetraTileMapLayer know to skip the diagonal overlay child layer for layouts that don't need it?

| Option | Description | Selected |
|---|---|---|
| Add `needs_diagonal_overlay()` virtual + extend skip to ALL non-Tetra4 layouts (Recommended) | Base declares the virtual (default `false`); Tetra4 overrides `true`. `_ensure_visual_layers` lazy-creates `_overlay_layer` only when `true`. Cleanest, broadest perf win. | ✓ |
| Sentinel-only (current behavior) | Keep the existing `diagonal_complement_atlas_coords == (-1,-1)` runtime guard. Overlay layer still always created; just never painted to. | |
| Both — virtual + sentinel | Defense-in-depth. | |

**User's choice:** `Add 'needs_diagonal_overlay()' virtual + extend skip to ALL non-Tetra4 layouts (Recommended)`

**Notes:**
- The user's choice extends the perf optimization to layouts that already don't need the overlay (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) — they currently pay for an empty overlay TileMapLayer at runtime that this refactor reclaims.
- D-35 in CONTEXT.md adds a defense-in-depth layer: `_paint_via_layout` reads `_overlay_layer != null` before attempting overlay paint, so a misconfigured layout that returns `false` from `needs_diagonal_overlay()` while still setting `diagonal_complement_atlas_coords` no-ops the overlay paint instead of crashing. `update_configuration_warnings()` flags the inconsistency.

---

## Phase scope routing

**Question:** Where do the new 5-tile layouts + overlay-skip refactor land in the roadmap?

### Round 1

| Option | Description | Selected |
|---|---|---|
| Inside Phase 2 (Recommended) | Phase 2 expands from 4 to 6 native layouts + dispatcher refactor. Adds ~80–120 LOC, 2 templates, 2 fallback TileSets. | |
| Phase 2.1 decimal insert | Phase 2 ships the 4 originally planned; Phase 2.1 adds the 5-tile pair + dispatcher refactor. | |
| Phase 1.1 dispatcher-first | Architectural change lands as a tiny standalone phase before Phase 2; Phase 2 picks up the 5-tile layouts using the new hook. | |

**User's response:** "im already working on phase 2, add it as phase 3 and push the other phases back one"

**Notes:** Picked a 4th option (insert as new Phase 3, renumber 3 → 4, 3.5 → 4.5, 4 → 5, 5 → 6).

### Round 2 (correction)

**User's correction:** "sorry i was wrong, please append is to phase 2, not add a new phase"

**Final choice:** `Inside Phase 2`

**Notes:** Reverts to the original recommendation. Phases 3 / 3.5 / 4 / 5 unchanged. Phase 2's plan count grows from `TBD` to `~6` (one plan per layout family, plus the dispatcher refactor as its own wave). New TETRA5-01..05 requirements added to REQUIREMENTS.md by the planner (per D-40); ROADMAP.md Phase 2 success criteria expanded (per D-41).

---

## Claude's Discretion (handed to planner)

Per D-29, D-31, D-37, D-39 in CONTEXT.md:

- Exact `transform_flags` value for mask 6 vs mask 9 in Tetra5 (`_ROTATE_90` vs `TRANSFORM_FLIP_H` vs `TRANSFORM_FLIP_V`)
- File naming convention for the new layout files (`tetra_tile_layout_tetra5_horizontal.gd` vs `tetra_tile_layout_tetra_5_horizontal.gd` — likely the latter per the `tetra_tile_layout_tetra_horizontal.gd` precedent)
- Whether `_OPPOSITE_CORNERS` constant lives on `Tetra5Horizontal` or on a shared base
- Exact `update_configuration_warnings()` text for the malformed-overlay-contract case
- Plan wave breakdown (suggested: dispatcher refactor → 4 originally-planned native layouts in parallel → Tetra5H+V → visual regression + LOC checkpoint)

## Deferred Ideas

Per `<deferred>` section in CONTEXT.md:

- TetraBake (procedural OppositeCorners generator from Tetra4 atlas) — newly motivated by Tetra5's existence but still parked in v2 backlog (TOOL-01)
- Asymmetric 6-tile variant — rejected per D-31 (breaks "5-tile" name, doubles authoring burden)
- Author-mirrored sentinel — rejected per D-31 (fragile)
- Class-name alternatives `TetraEdge` / `TetraOpposite` / `TetraOppositeCorners` / `TetraDiagonal` — rejected per D-29 in favor of `Tetra5`

---

## SUPERSESSION NOTICE — 2026-04-26

The Phase 2.1 brainstorm session reframed the Tetra5 plan. **The decisions in CONTEXT.md (D-28..D-46) and the rounds above are partially superseded.** The user's policy on breaking changes ("always allowed, always; never write compat shims") and the realization that the previously-deferred TetraBake idea (procedural OppositeCorners synthesis) is the *better* path — not a future "tool" — drove the pivot.

### What changed

| Before (CONTEXT D-28..D-46) | After (this supersession) |
|---|---|
| `TetraTileLayoutTetra5Horizontal` + `TetraTileLayoutTetra5Vertical` ship as NEW separate classes | The existing `TetraTileLayoutTetraHorizontal`/`TetraTileLayoutTetraVertical` (Phase 1) **gain load-time synthesis** of the 5th OppositeCorners archetype. Auto-detect 4-vs-5-tile sources. **No separate Tetra5 classes ship.** |
| `needs_diagonal_overlay() -> bool` virtual on base; `_overlay_layer` lazily skipped for layouts that return `false` | `_overlay_layer` is **deleted entirely**. `needs_diagonal_overlay()` virtual is removed. Every v0.2 layout renders via single-layer 5-archetype dispatch. `AtlasSlot.diagonal_complement_atlas_coords` is removed. |
| Tetra4 (Phase 1) keeps its v0.1 overlay rendering; only Tetra5/other layouts skip overlay | Tetra4 **changes rendering path** to load-time synthesis. Output is bit-identical to v0.1 overlay composition for masks 6/9 (verified via pixel-hash test). Breaking change for any code reading `_overlay_layer` directly; CHANGELOG entry covers it. |
| TETRA5-01..05 requirements added in Phase 2 | TETRA-SYNTH-01..06 requirements replace them in REQUIREMENTS.md |

### Decisions superseded

- **D-28** (append Tetra5H+V as 6th layout in Phase 2) → REPLACED. No separate Tetra5 classes. Tetra*Horizontal/Vertical gain synthesis.
- **D-29** (class root name `Tetra5`) → MOOT. No separate class.
- **D-30, D-32, D-46** (canonical paint anchoring for Tetra5's mask 6 vs mask 9) → STILL APPLY but to the synthesized OppositeCorners, not a separate class. Synthesis is parameterized by these conventions.
- **D-33** (`needs_diagonal_overlay() -> bool` virtual + lazy overlay skip) → REPLACED by full overlay-layer deletion (TETRA-SYNTH-04). The virtual is removed; not needed.
- **D-36** (Tetra5 atlas slot order = `[Fill, Inner, Border, Outer, OppositeCorners]`) → STILL APPLIES. Artists who hand-author 5 tiles use this order. Synthesis writes the OppositeCorners to slot 4 in the runtime atlas. Auto-detect: 4-tile source → synthesize; 5-tile source → use slot 4 directly.
- **D-39** (Tetra5Horizontal extends Tetra4Horizontal; Tetra5Vertical extends Tetra5Horizontal) → MOOT. No subclass needed. Single class auto-detects.
- **D-40** (TETRA5-* requirement IDs) → REPLACED by TETRA-SYNTH-01..06.
- **D-41** (Phase 2 success criterion expanded for Tetra5) → REPLACED by Phase 2 success criteria 6, 7, 8, 9 (synthesis pixel-identity, overlay removal, auto-detect, collision support).
- **D-43** (`update_configuration_warnings()` for malformed Tetra5 atlases) → STILL APPLIES with adjusted scope. Now warns on auto-detect ambiguity (e.g., `5 × 1` atlas where slot 4 is empty/identical-to-fill — the artist intended Tetra4 but accidentally added a 5th column). Warning text adjusts to the auto-detect framing.

### Decisions still in force unchanged

- D-31 (5-tile is the canonical convention; reject asymmetric 6-tile)
- D-34..D-35 (single-grid pipeline unchanged)
- D-37..D-38 (compute_mask + atlas dispatch via Vector2i unchanged)
- D-42 (mask 0 short-circuit unchanged)
- D-44..D-45 (marching-squares cross-references; regression-suite protections — both still apply to all v0.2 layouts)
- All four originally-planned native layouts (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) ship as planned.

### New decisions (Phase 2 plan should pick these up)

- **D-47: Tetra layouts auto-detect source atlas tile count.** `TetraTileLayoutTetraHorizontal` reads `TileSetAtlasSource.get_atlas_grid_size()` at contract-load. If width=4 (or height=4 for vertical): synthesize. If width=5 (or height=5): use slot 4 directly. Anything else: `update_configuration_warnings()` flags it.
- **D-48: Synthesis target lives in an internal runtime TileSet on `_primary_layer`.** User's source `tile_set` is never mutated. The synthesized atlas is allocated at `atlas_contract` setter time, freed when the contract changes. Deterministic — same source atlas + same layout → bit-identical synthesis output.
- **D-49: Synthesis copies collision/occlusion/navigation polygons from source archetypes to the synthesized OppositeCorners tile.** Two source-tile collision polygon sets are translated to the diagonal positions on the synthesized tile. Animation frames, custom data layers, probability weights, and Y-sort origin are NOT copied (explicitly out of scope for v0.2 synthesized tiles per TETRA-SYNTH-03; documented in DOC-03 as a layout-choice tradeoff).
- **D-50: Pixel-identity verification gate for Phase 2 plan.** A test renders v0.1's overlay-composed Tetra4 vs synthesis-produced Tetra4 for masks 6 and 9 and asserts pixel-hash equality. Failure blocks merge.
- **D-51: Overlay-layer code deletion is a breaking change documented in CHANGELOG.** `_overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, and `AtlasSlot.diagonal_complement_atlas_coords` are removed. Any external code reading these breaks. Per the user's breaking-changes policy (CLAUDE.md, PROJECT.md), this proceeds without compat shims.
- **D-52: Tetra5 (artist-authored 5th tile) is preserved as a USE CASE, not a separate class.** Artists who want a hand-drawn distinct OppositeCorners author 5 tiles in their atlas; auto-detect picks them up. Bundled `tetra_5_horizontal.png` and `tetra_5_vertical.png` greybox templates ship for this case (TETRA-SYNTH-06).

### What this means for the Phase 2 planner

- Drop "ship Tetra5Horizontal/Tetra5Vertical as new classes" from the plan
- Add "rewrite TetraTileLayoutTetraHorizontal/Vertical to synthesize 5th tile + auto-detect 4-vs-5"
- Add "delete overlay layer code path from TetraTileMapLayer + AtlasSlot"
- Add "pixel-identity test for synthesis output"
- The 4 originally-planned native layouts (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) ship unchanged
- Wave breakdown suggestion (planner free to recompose):
  - Wave 1: synthesis machinery (Image.blit_rect helper, runtime TileSet construction, collision polygon copy) + delete overlay layer path
  - Wave 2: rewrite Tetra Horizontal/Vertical to use synthesis (auto-detect, bit-identical output verification)
  - Wave 3: 4 originally-planned native layouts in parallel
  - Wave 4: 5-tile templates + bundled fallback TileSets + visual regression + LOC checkpoint

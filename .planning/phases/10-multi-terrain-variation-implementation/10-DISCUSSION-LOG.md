# Phase 10: Multi-Terrain + Variation Implementation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-30
**Phase:** 10-multi-terrain-variation-implementation
**Areas discussed:** Scope & phasing, Terrain encoding mechanism, Variation depth & coupling, compute_mask() signature change, Dual-grid terrain boundary dispatch

---

## Scope & Phasing

| Option | Description | Selected |
|--------|-------------|----------|
| All 6 sub-phases at once (Recommended) | Ship terrain group + index + terrain_mode + source_id + variation + slope + fallback in one phase. ~440 LOC. All layout types. | ✓ |
| Terrain + variation only (A, B, C, E, F) | Defer slope to Phase 11. ~320 LOC. | |
| Single-grid first, dual-grid later (A, B, C, F) | Defer Penta banks + dual-grid + variation + slope. ~170 LOC. | |
| Minimal: terrain index + terrain_mode only | Smallest surface area. ~170 LOC. | |

**User's choice:** All 6 sub-phases at once. Matches Phase 9 blueprint. User wants comprehensive delivery, not incremental.

---

## Terrain Encoding Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Both: atlas_coords.y + custom data (Recommended) | Use atlas_coords.y as default, penta_terrain_id custom data for overrides. ~20 LOC delta. | ✓ |
| Custom data layer only | Terrain identity exclusively in penta_terrain_id. | |
| atlas_coords.y only | No custom data layer. Terrain = what you painted. | |

**User's choice:** Both mechanisms. atlas_coords.y for paint-time encoding (leverages existing AUTO_STRIP), custom data layer for per-cell overrides. Resolution order: custom data → TileData.terrain → default (layouts[0]).

---

## Variation Depth & Coupling

| Option | Description | Selected |
|--------|-------------|----------|
| Full per-terrain variation (Recommended) | Each terrain's candidates pooled via TileData.probability. variation_mode enum. ~50 LOC. | ✓ |
| Basic variation hook only | Wire hash picker, SINGLE mode only. ~20 LOC. | |
| Defer all variation | Terrain dispatch only. Variation deferred to v2. | |

**User's choice:** Full per-terrain variation. variation_mode enum (SINGLE/PROBABILITY/STRIP) on PentaTileLayout base. Deterministic hash(coord, terrain_id, seed) per established pitfall §2 pattern.

---

## compute_mask() Signature Change

| Option | Description | Selected |
|--------|-------------|----------|
| Default parameter: compute_mask(coord, sample_fn, strip_index=0) (Recommended) | Add strip_index with default 0 to base + all 8 subclasses. ~9 signatures touched. | ✓ |
| New virtual: compute_terrain_mask() | Separate virtual. Zero signature changes to existing methods. | |
| Wrapper: filter in _paint_via_layout | Don't change compute_mask. Filter via wrapped sample_fn. | |

**User's choice:** Default parameter. strip_index=0 on base + all subclasses. Backwards-compat via default value means existing callers without strip_index continue working.

---

## Dual-Grid Terrain Boundary Dispatch

| Option | Description | Selected |
|--------|-------------|----------|
| Per-corner layered (most correct, most complex) | Each display cell gets painted up to 4 times, once per terrain present. Higher-precedence on top. ~100 LOC. | ✓ |
| Highest-precedence terrain (Recommended alternative) | Pick terrain with highest precedence among 4 neighbors. 1 tile per display cell. | |
| Dominant terrain (majority vote) | Most frequent terrain wins. Tiebreaker → precedence. | |

**User's choice:** Per-corner layered dispatch. Each display cell's TL/TR/BL/BR corners dispatch through their respective logic cell's terrain layout. Higher precedence paints on top. Heavily document in code. Add `.planning/` doc for highest-precedence fallback approach in case per-corner needs simplification.

**Notes:** User called this "important" and wants the more complex but correct dispatch. Fallback doc provides an escape hatch without polluting the primary implementation.

---

## the agent's Discretion

- Transition override table format (exact Dictionary key/value types)
- Slope subclass specifics (8-tile atlas, 3-state sampling, class name, file path)
- Penta per-terrain synthesis details
- Fallback tiling for TerrainGroup when transition tiles are missing
- Peering-bits-to-mask conversion (CellNeighbor enum verification against Godot 4.6 source)
- Precedence tiebreaker logic
- source_id field placement on AtlasSlot and routing through _paint_via_layout()

---

## Deferred Ideas

- GDScript port of spike 001-003 mask decoder (v0.4 tooling) — reviewed, not folded, out of scope

---

## Additional User Requirements

- **"Make sure you give me recommendations for every option"** — All question options included a "(Recommended)" label on the preferred choice.
- **"I want to def all user manual testing for this phase, you must automate every test"** — Captured as a hard constraint (D-14). All verification must use composed-canvas automated tests per CLAUDE.md § Test Methodology.

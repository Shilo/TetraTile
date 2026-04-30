# Phase 10: Multi-Terrain + Variation Implementation - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement terrain dispatch via `PentaTileTerrainGroup` Resource (Phase 9 architecture blueprint) + deterministic variation via `TileData.probability` + `source_id` field on `PentaTileAtlasSlot` + `terrain_mode()` virtual on `PentaTileLayout` base + `compute_mask(strip_index)` signature extension. Consumes Phase 9 architecture recommendation + spikes 006/007 findings. Ships all 6 sub-phases (A-F) from the architecture blueprint in one comprehensive phase: PentaTileTerrainGroup Resource, terrain index building, custom data layer wiring, slope layout subclass, variation mode wiring, and fallback + tests. One `PentaTileMapLayer` renders N terrain types with correct boundary transitions across all 8 layout subclasses (single-grid, Penta, dual-grid).

**Hard constraint from user:** All testing must be automated. Zero manual UAT for this phase.

</domain>

<decisions>
## Implementation Decisions

### Scope & Phasing
- **D-01:** Ship all 6 sub-phases (A-F) from the Phase 9 architecture blueprint in one comprehensive phase: PentaTileTerrainGroup Resource, terrain index building, custom data layer wiring, slope layout subclass, variation mode wiring, and fallback + tests. Total estimated delta: ~440 LOC.
- **D-02:** All 8 layout subclasses (DualGrid16, Wang2Edge, Wang2Corner, Min3x3, Blob47Godot, PixelLabTopDown, PixelLabSideScroller, PentaTileLayoutPenta) receive terrain-aware dispatch. Single-grid, Penta, and dual-grid all ship together.

### Terrain Encoding Mechanism
- **D-03:** Use both encoding mechanisms: `atlas_coords.y` as the default terrain identity at paint time (leverages existing AUTO_STRIP per-strip dispatch), and `penta_terrain_id` custom data layer for per-cell overrides.
- **D-04:** Resolution order: (1) read `penta_terrain_id` from logic cell's custom data; if >= 0, use that terrain. (2) If -1, read `TileData.terrain` (Godot native). (3) If still -1, use `terrain_group.layouts[0]` (first/default terrain).
- **D-05:** `set_cell()` stores terrain via `atlas_coords.y` — user paints `Vector2i(slot, terrain_id)`. The `_resolve_terrain_id()` helper in `PentaTileMapLayer` bridges atlas_coords.y and custom data layer.

### Variation Integration
- **D-06:** Full per-terrain variation pools. Each terrain's candidate tiles that share the same mask/peering-bit configuration are pooled via `TileData.probability` weighted selection.
- **D-07:** Variation pick uses deterministic hash: `hash(Vector4i(cell.x, cell.y, terrain_id, _global_variation_seed))` with `rng.seed = seed_value` then `rng.rand_weighted(weights)`. Same coord + same terrain + same seed = same variant. No shimmer on rebuild.
- **D-08:** Add `variation_mode: VariationMode` enum on `PentaTileLayout` base: `SINGLE` (one tile per mask, current behavior), `PROBABILITY` (weighted random from tiles sharing same peering-bit config, reads `TileData.probability`), `STRIP` (random pick from horizontal strip, PixelLab-style). Default: `SINGLE`.

### compute_mask() Signature Extension
- **D-09:** Add default `strip_index: int = 0` parameter to `compute_mask()` on `PentaTileLayout` base class and all 8 subclass overrides. Existing callers without strip_index continue working via default value.
- **D-10:** Cross-terrain mask filtering: each terrain only sees same-terrain cells as "filled". A Wall cell next to a Floor cell sees the Floor as "empty" — the Wall renders its own edge tiles at the boundary. Both sides produce clean boundaries.

### Dual-Grid Terrain Boundary Dispatch
- **D-11:** Per-corner layered dispatch: each dual-grid display cell gets painted up to 4 times — once per terrain present in the 4 neighboring logic cells (TL/TR/BL/BR). The TL corner dispatches through the TL logic cell's terrain layout, TR through TR cell's terrain, etc.
- **D-12:** Higher-precedence terrains paint on top. Terrain precedence is defined per `PentaTileTerrainGroup` (e.g., `terrain_precedence: Array[int]` where index = terrain_id, value = precedence weight). Higher value = paints later (on top).
- **D-13:** Heavily document per-corner dispatch in code AND add a `.planning/phases/10-multi-terrain-variation-implementation/10-DUAL-GRID-FALLBACK.md` document describing the highest-precedence-terrain fallback approach in case per-corner layered dispatch needs simplification in practice.

### Testing
- **D-14:** All testing must be automated. Zero manual UAT for this phase. Use composed-canvas tests (per established Phase 2 UAT methodology in CLAUDE.md § Test Methodology). Test coverage must include: terrain index correctness, boundary detection, mask dispatch per terrain, multi-terrain hollow/edge patterns, variation determinism, slope tile rendering, and the full 8-layout × N-terrain matrix.

### the agent's Discretion
- Transition override table format (`Dictionary[Vector2i(terrain_a, terrain_b), Dictionary[int, AtlasSlot]]` or equivalent)
- Slope subclass specifics (8-tile atlas, 4-bit corner mask, 3-state empty/floor/wall neighbor sampling)
- Penta per-terrain synthesis details (how `PentaTileSynthesis.synthesize_strip()` is called per terrain)
- Fallback tiling for `PentaTileTerrainGroup` when transition tiles are missing (`auto_fallback_transitions` default behavior)
- Exact peering-bits-to-mask conversion indices (must verify against Godot 4.6 source at implementation time — Spike 007 identifies CellNeighbor enum indexing as the main implementation risk)
- Precedence tiebreaker logic (when multiple terrains have equal precedence values)
- Exact `source_id` field placement on `PentaTileAtlasSlot` and routing through `_paint_via_layout()` to `visual_layer.set_cell()`
- PentaTileLayoutSlope file path, class name, and `@icon` resource

### Folded Todos
- **`compute_mask(strip_index)` signature extension** — Folded into D-09. Extends base `compute_mask(coord, sample_fn)` with `strip_index=0` default parameter to enable cross-terrain mask filtering.
- **`source_id` on `PentaTileAtlasSlot` (Phase 10 schema)** — Folded. AtlasSlot gains `source_id: int = -1` field for multi-source TileSet output routing. When `source_id >= 0`, `_paint_via_layout()` routes to that source instead of the global source.
- **`terrain_mode()` virtual on `PentaTileLayout` base** — Folded. New virtual `terrain_mode() -> int` declares which Godot `TerrainMode` each layout's mask system corresponds to. Used for peering-bits-to-mask conversion during candidate index building.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 9 Architecture Blueprint
- `.planning/phases/09-terrain-variation-authoring-research-spike/09-ARCHITECTURE-RECOMMENDATION.md` — Complete architecture: PentaTileTerrainGroup design, custom data layer, terrain index building, hot-path extension, slope handling, variation pools, atlas passthrough, 6-phase blueprint (~440 LOC), guardrail compliance, implementation risks. This is the authoritative design document.
- `.planning/phases/09-terrain-variation-authoring-research-spike/09-PDF-REVIEW.md` — Godot terrain sets PDF verification: alternative tile handling, center bit enforcement, Match Corners group-of-4 constraint, probability semantics.
- `.planning/phases/09-terrain-variation-authoring-research-spike/09-CONTEXT.md` — Phase 9 context: research scope, design decisions D-01..D-06.

### Spike Findings (consumed by this phase)
- `.planning/spikes/006-multi-terrain-dispatch-architecture/README.md` — Multi-terrain dispatch architecture (atlas_coords.y encoding, cross-terrain mask filtering, precedence resolution, single-grid-first validation).
- `.planning/spikes/007-godot-terrain-api-integration/README.md` — Godot terrain API integration (candidate index, peering-bits-to-mask conversion, terrain_mode() virtual, variation via probability).
- `.planning/spikes/005-slope-layout-architecture/README.md` — Slope layout architecture (3-state corner mask, 8-tile atlas, terrain-ID-aware neighbors).
- `.planning/spikes/004-virtumap-integration-requirements/README.md` — VirtuMap integration bridge requirements (atlas passthrough, multi-terrain, slope handling).

### Prior Multi-Terrain Research
- `.planning/phases/08-research-triage-v0-3-scope-selection/08-MULTI-TERRAIN-RESEARCH.md` — Focused multi-terrain research: MULTITERR-01..08 requirements, Godot terrain metadata input-only policy, single-grid → dual-grid → Penta shipping order, cross-terrain transition art-cost limits.

### Existing Source Files (modified in this phase)
- `addons/penta_tile/penta_tile_map_layer.gd` — Primary integration point. Gains terrain_group setter, _build_terrain_index(), _resolve_terrain_id(), set_cell_passthrough(), per-corner dual-grid dispatch, variation picker.
- `addons/penta_tile/layouts/penta_tile_layout.gd` — Base layout. Gains terrain_mode() virtual (+ default -1 return), variation_mode enum + property, compute_mask(strip_index=0) signature.
- `addons/penta_tile/penta_tile_atlas_slot.gd` — Gains source_id: int field.
- `addons/penta_tile/penta_tile_synthesis.gd` — Synthesis engine. Gains per-terrain synthesis support (called per terrain within TerrainGroup).

### Existing Layout Subclasses (signature updated in this phase)
- `addons/penta_tile/layouts/penta_tile_layout_penta.gd` — Gains strip_index-aware compute_mask, terrain_mode() override → MATCH_CORNERS.
- `addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd` — Gains strip_index-aware compute_mask, terrain_mode() override → MATCH_CORNERS.
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd` — terrain_mode() override → MATCH_SIDES.
- `addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd` — terrain_mode() override → MATCH_CORNERS.
- `addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd` — terrain_mode() override → MATCH_SIDES.
- `addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd` — terrain_mode() override → MATCH_CORNERS_AND_SIDES.
- `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd` — terrain_mode() override → MATCH_CORNERS.
- `addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd` — terrain_mode() override → MATCH_CORNERS.

### New Files (created in this phase)
- `addons/penta_tile/layouts/penta_tile_terrain_group.gd` — PentaTileTerrainGroup Resource class (~60 LOC).
- `addons/penta_tile/layouts/penta_tile_layout_slope.gd` — PentaTileLayoutSlope subclass (~120 LOC).
- `.planning/phases/10-multi-terrain-variation-implementation/10-DUAL-GRID-FALLBACK.md` — Documented highest-precedence-terrain fallback approach per D-13.

### Project Identity and Constraints
- `.planning/PROJECT.md` § Identity Guardrails — No watcher/signal-fanout, no persistent coordinate cache, no EditorInspectorPlugin, no version fields, no forwards-compat hooks. Must comply.
- `.planning/REQUIREMENTS.md` § MULTITERR-01..08 — Multi-terrain requirements from Phase 8 research. Godot terrain metadata is input only; no Godot solver delegation.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`PentaTileMapLayer._update_cells()`** — Main autotile egress point. Terrain dispatch extends `_paint_via_layout()` and `_paint_dual_grid()` within this pipe. Hot-path addition: ~15 lines for terrain resolution.
- **`PentaTileLayoutPenta` AUTO_STRIP** — Existing `resolve_display_strip()` and per-strip dispatch are the natural foundation for terrain-as-strip-index. Per-terrain Penta strips already align with AUTO_STRIP's per-strip synthesis pipeline.
- **`PentaTileSynthesis`** — Existing synthesis engine (Liang-Barsky clipper, Gate 1/2, signature-based cache). Per-terrain synthesis calls this per terrain within the group.
- **`rand_weighted()` pattern** — Already used in v0.2.0 for Penta synthesis. Variation repurposes this with terrain_id in the hash seed.

### Established Patterns
- **`_queue_rebuild` deferred coalescer** — Terrain group setter rides the same deferred-rebuild path as layout/tile_set setters. No new queue mechanism.
- **Custom data layers** — Existing `penta_role` and `penta_lock_rotation` layers establish the custom-data-for-metadata pattern. `penta_terrain_id` follows this.
- **`@export_group` + typed exports** — PentaTileTerrainGroup uses this for inspector surface. No EditorInspectorPlugin.
- **Deterministic hashing** — All variation uses `RandomNumberGenerator.seed = hash(Vector4i(...))` per PITFALLS.md §2. Never `randi()`.
- **Composed-canvas tests** — Established in Phase 2 UAT (CLAUDE.md § Test Methodology). All terrain tests must use this pattern.

### Integration Points
- **`set_cell()` / `erase_cell()`** — User painting continues unchanged. Terrain identity flows via `atlas_coords.y` in set_cell. Erased cells have no terrain.
- **`_resolve_source_id()`** — Currently returns global source. Gains terrain-aware routing when `PentaTileAtlasSlot.source_id >= 0`.
- **`_pack_alternative()`** — Existing bit-packing helper. Unchanged; terrain-aware alternatives use the same packing.
- **`get_fallback_tile_set()`** — Gains TerrainGroup-aware extension: fallback TileSet from first layout in group when terrain_group is set.
- **VirtuMap adapter** — External consumer. `set_cell_passthrough()` method added for VirtuMap's atlas passthrough requirement. Cells marked `penta_passthrough = true` copy directly logic→visual without solver.
</code_context>

<specifics>
## Specific Ideas

- Documentation requirements: per-corner dual-grid dispatch must be heavily documented in code. A `.planning/phases/10-multi-terrain-variation-implementation/10-DUAL-GRID-FALLBACK.md` document must describe the highest-precedence-terrain fallback approach in case per-corner layered dispatch needs simplification in practice.
- All testing must be automated. Zero manual UAT for this phase. Tests must cover the full layout × terrain × pattern matrix.
- Terrain encoding uses both mechanisms (atlas_coords.y + custom data) so that both paint-time encoding AND per-cell overrides are possible without API changes.
- Variation picks must be deterministic per (coord, terrain_id, seed) — same input always produces same output across rebuilds.
- Slope tiles use 3-state neighbor lookup (empty/floor/wall) derived from terrain IDs, not binary filled/empty — this is the layout's responsibility in `compute_mask()`.

</specifics>

<deferred>
## Deferred Ideas

- GDScript port of spike 001-003 mask decoder (v0.4 tooling) — reviewed, out of scope for Phase 10.
- RPG Maker quarter-tile composition (RPGM-01/02) — reserved for v0.3+.
- Per-cell per-neighbor terrain weights (TileMapDual/BetterTerrain territory) — explicitly rejected; conflicts with identity guardrail.
- TileBitTools Tilesetter layouts (TBT-01-DEFERRED, TBT-02-DEFERRED) — await v0.3+ planning.
- Top-tile explicit per-mask layout data (TOP-01) — v2 backlog.
- Multi-terrain outer transition tile support (TERRAIN-01) — distinct R&D track, not Phase 10.
- PentaBake procedural 5th-tile composition — parking-lot idea.
- Hex/isometric/grid-agnostic expansion — not v0.3.

### Reviewed Todos (not folded)
- **GDScript port of spike 001-003 mask decoder (v0.4 tooling)** — Not folded. This is future tooling work for v0.4+. No impact on Phase 10 terrain/variation implementation.

</deferred>

---

*Phase: 10-multi-terrain-variation-implementation*
*Context gathered: 2026-04-30*

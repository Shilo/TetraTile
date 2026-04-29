# PentaTile

## What This Is

PentaTile is a lightweight dual-grid autotiling addon for Godot 4.6 that exposes a single public node, `PentaTileMapLayer`, on top of the engine's native `TileMapLayer` API. It is built for game developers (initially the author's own projects) who want a small, lean autotiler they can drop into a Godot project and drive with the standard painting and runtime APIs.

## Core Value

Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.

## Requirements

### Validated

<!-- Shipped in v0.1.0 and confirmed working in the demo. -->

- ✓ Single public `PentaTileMapLayer` node extending `TileMapLayer` — v0.1.0
- ✓ Native painting API support (`set_cell()`, `erase_cell()`, editor tools) — v0.1.0
- ✓ 4-tile binary atlas contract (Fill, Inner Corner, Border, Outer Corner) — v0.1.0
- ✓ Horizontal (4×1) and vertical (1×4) atlas layouts — v0.1.0
- ✓ 16-state mask-driven tile selection with transform rotations — v0.1.0
- ✓ Two-layer composition for disconnected diagonal masks (6 and 9) — v0.1.0
- ✓ Hidden logic layer via `self_modulate.a` (avoids Godot cleanup behavior) — v0.1.0
- ✓ Generated visual-layer collisions sourced from TileSet physics polygons — v0.1.0
- ✓ Public `rebuild()` helper for full visual regeneration — v0.1.0
- ✓ Demo scene with platformer player and runtime drag-paint — v0.1.0
- ✓ Codebase mapped in `.planning/codebase/` — v0.1.0

### Active

<!-- This milestone: layout library — every popular autotiling atlas convention is a pluggable Resource. -->

- [ ] `PentaTileMapLayer.layout: PentaTileLayout` exported directly (no contract wrapper — the original `PentaTileAtlasContract` plan was overengineered and is deleted in Phase 2)
- [ ] `PentaTileLayout` base class with virtual `compute_mask`, `mask_to_atlas`, `get_fallback_tile_set` dispatch
- [ ] Single merged `PentaTileLayoutPenta` class with `axis: Axis` and `tile_count: TileCountMode` enums (auto-detect of 1/2/3/4/5 source tiles per strip; ONE through FIVE progressive synthesis modes)
- [ ] DualGrid16 + Wang2Edge + Wang2Corner + Min3x3 layouts (PentaTile-native conventions)
- [ ] Blob47Godot + TilesetterWang15 + TilesetterBlob47 layouts (slot tables transcribed from TileBitTools, MIT, attributed)
- [ ] PixelLab Top-down + Side-scroller layouts
- [ ] Per-layout `bitmask_template: Texture2D` rendered inline as inspector preview AND used as the prototyping fallback (single image per layout, both roles)
- [ ] Per-layout `description: String` (multiline, inspector-editable) plus class-level `##` doc-comment
- [ ] Bundled bitmask PNGs co-located next to layout `.gd` files (`addons/penta_tile/layouts/penta_tile_layout_penta/{one,two,three,four,five}_{horizontal,vertical}.png` + flat siblings for single-variant layouts)
- [ ] Updated demo scene showcasing layout switching across the library
- [ ] README "Layouts" section + "Upgrading from 0.1.x" + "Authoring a Custom Layout"
- [ ] GitHub release tagged `v0.2.0`

### Out of Scope

<!-- Explicitly deferred for this milestone. -->

- Y-axis variation support — Pushed to a future milestone; needs its own discussion (was originally planned for v0.2 but the layout library re-prioritized first)
- Top-tile support — Pushed to a future milestone; needs design after layout library lands
- Non-rotating tileset feature — Largely *delivered* by the DualGrid16 / Wang2Corner / Wang2Edge layouts; any remaining "non-rotating" needs roll into a future milestone if surfaced
- RPG Maker A1/A2/A4 subtile composition — Architecturally reserved (`PentaTileLayout` slot exists) but the quarter-tile compositor is a v0.3+ refactor
- Tiled `.tsx` / LDtk `.ldtk` rule importers — Both editors store autotile rules in project files, not atlases; full support requires rule-importer infrastructure out of scope here
- Excalibur / jaconir Blob 47 convention — Web-game indie convention; no demonstrated Godot adoption; dropped
- Stormcloak / OpenGameArt CR31 community blob variants — Dropped per user direction; insufficient adoption signal
- Godot `MATCH_SIDES` mask layout — Engine semantics disputed in [Godot issue #79411](https://github.com/godotengine/godot/issues/79411); skipped until engine clarifies
- PentaBake (procedural 5th-tile composition) — Parking-lot idea; not needed to unblock author's games
- Tileset converter (Wang/blob → PentaTile) — Authoring tooling deferred
- Outer transition tile support (multi-terrain) — Distinct R&D track
- Shader fallback for diagonal compositing — Performance optimization not needed at demo scale
- Collision authoring / auto-collision generation — TileSet-physics path is sufficient
- Godot Asset Library distribution — GitHub-only this milestone
- Formal automated test suite (GUT) — "Works in my game" quality bar
- Large-map performance benchmarking (>10k cells) — Demo-scale only
- Backwards compatibility for v0.1.0 atlases / API — Pre-1.0; breaking changes accepted with migration notes
- Custom layout authoring polished surface (`EditorInspectorPlugin`) — Subclassing `PentaTileLayout` works but is documented as experimental; no editor polish

## Context

- Existing implementation is ~261 LOC of GDScript in a single class plus a working demo scene with a `CharacterBody2D` player and runtime drag-paint script. No external dependencies beyond Godot 4.6.
- Architecture is intentionally lean: no persistent coordinate cache, no signal fanout, no watchers — `_update_cells()` recomputes affected masks on demand and writes directly to two internal `TileMapLayer`s.
- v0.2 pivots from "expand the contract for variation/top/non-rotating" to "ship a library of pluggable layout Resources covering every popular Godot autotiling atlas convention." The user's pain point shifted: the strict 4-tile atlas isn't just visually limiting, it's incompatible with atlases authored anywhere else (Tilesetter, OpenGameArt 47-blob, Godot stock terrain templates, etc.). Solving the layout zoo solves the lock-in.
- Layout-library research lives in `.planning/research/layouts/` — TAXONOMY (24 layouts catalogued), EDITORS (Tiled / LDtk / Tilesetter / Unity / RPG Maker conventions), GODOT_TERRAIN (the engine's stock terrain mechanics + why PentaTile bypasses them), MASK_UNIFICATION (architecture: polymorphic layout Resource), TILESETTER_AND_GODOT (live-doc audit), TILEBITTOOLS (TBT addon audit + slot tables we transcribe), COMPARISON (the artist-facing side-by-side reference).
- TileBitTools (MIT, dandeliondino) already decoded the Tilesetter slot tables. PentaTile transcribes those with attribution rather than empirically fingerprinting, eliminating a research bottleneck.
- The user is comparing PentaTile against TileMapDual; PentaTile's selling point has been minimalism and the 4-tile contract. The layout library expands surface area to one base class + 10 subclasses (5 Phase 2 + 3 Phase 3 + 2 Phase 3.5). Original LOC estimate was ~520 total; actual runtime LOC at Phase 2 close is 1827 — above the ~1500 informational trigger. Hard gate is end of Phase 4; final audit at Phase 5 decides whether a focused trim pass is needed before v0.2.0 ships, vs accepting the LOC growth with a "still simpler than TileMapDual" rationale (see `.planning/phases/02-native-layouts/02-07-LOC-CHECKPOINT.md`).
- Variation, top tiles, and non-rotating tilesets pushed to future milestones. Non-rotating is largely *delivered* by the new DualGrid16 / Wang2Corner / Wang2Edge layouts since those are explicitly per-direction-authored. Variation and top tiles need their own discussion against the new layout shape.

## Constraints

- **Tech stack**: Godot 4.6+ stable. Pure GDScript. No C#, no GDExtension, no third-party dependencies.
- **Engine API**: Implementation must continue to ride `TileMapLayer._update_cells()`. No persistent coordinate cache, signal fanout, or watcher systems (per the existing architecture's "lean" stance).
- **Distribution**: GitHub releases with plain semver tags (no `-pre`, `-alpha`, `-dev` suffixes). No Asset Library submission this milestone.
- **Audience**: The author's own games. No public-API SLA. **Breaking changes are always allowed and explicitly encouraged when they enable improvements; never write backwards-compatibility shims, never defer features because they would break v0.1. Equally: never speculate about forward-compat — no `version: int` fields, schema markers, or speculative extension points "in case a future feature needs them."** Migration notes go in CHANGELOG and release notes; that's the only "compat" work in either direction.
- **Performance**: Demo-scale target (~100–1k cells). Interactive painting and runtime drag-paint must remain fluid; large-map perf is not a milestone gate.
- **Identity**: PentaTile prioritizes hot-path minimalism and anti-pattern absence over raw LOC delta vs TileMapDual. The runtime path stays short (`_update_cells → compute_mask → mask_to_atlas → set_cell`), and the addon does not adopt tile caches, watcher / signal-fanout systems, persistent coordinate caches, parallel paint APIs, or `EditorInspectorPlugin` polish. Terrain support, if pursued, reads Godot `TileData` terrain metadata as input while PentaTile remains the solver; it does not delegate generated visuals to Godot's terrain painter. LOC is reported as data, not a verdict (D-05-11).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| v0.2 pivots from "expand the contract" to "layout library" | Layout-library work surfaces the design questions for top tiles + variation + non-rotating; better to land the contract surface area first and discuss those features against a stable foundation | — Pending |
| ~~Layout is a typed `Resource` subclass (`PentaTileLayout`) attached to `PentaTileAtlasContract`~~, NOT a `RotationMode` enum | The strategy pattern absorbs RPG Maker subtile composition (and other future mask systems) without modifying `_update_cells()`; analyzed and recommended in `.planning/research/layouts/MASK_UNIFICATION.md` | — **Superseded by Phase 2:** `PentaTileAtlasContract` deleted; `layout: PentaTileLayout` lives directly on `PentaTileMapLayer`. Strategy pattern preserved. |
| ~~Each layout Resource exposes `template_image: Texture2D` + `fallback_tile_set: TileSet`~~ for inspector preview and zero-config prototyping | Drop a fresh `PentaTileMapLayer` into a scene with just a layout Resource and start painting — best-in-class onboarding UX, no `EditorInspectorPlugin` required | — **Superseded by Phase 2:** `template_image` renamed `bitmask_template`; `fallback_tile_set` @export deleted (now virtual `get_fallback_tile_set()` codegen from `bitmask_template`). UX outcome unchanged. |
| Tilesetter slot tables decoded from TileBitTools (MIT) rather than fingerprinted | TBT already published `tilesetter_blob.tres` and `tilesetter_wang.tres` with slot maps; transcribing with attribution is faster and lower-risk than empirical fingerprinting | — Pending |
| Tilesetter Wang is 15 tiles in a 5×3 atlas with one stray fill, not 16 in 4×4 | TBT's verified slot table; earlier secondary-source claim was wrong | — Pending |
| Tilesetter Blob is 11×5 with discrete sub-block gaps, not 7×8 with trailing unused cells | TBT's verified slot table; matches user's reference images | — Pending |
| Variation, top tiles, and "non-rotating" pushed to a future milestone (post-v0.2) | DualGrid16 / Wang2Corner / Wang2Edge layouts cover the asymmetric-art case the user wanted; variation and platformer top tiles need design discussion against the new layout-library shape | — Pending |
| Excalibur / jaconir / Stormcloak / OpenGameArt CR31 dropped from layout library | No demonstrated Godot adoption; user only cares about Godot-native and Tilesetter conventions | — Pending |
| Godot `MATCH_SIDES` skipped | Engine semantics disputed (issue #79411); revisit when engine clarifies | — Pending |
| RPG Maker A2/A4 architecturally reserved but deferred | Quarter-tile subtile composition doesn't fit the unified `_update_cells` dispatch — it's a separate pipeline; v0.3+ work | — Pending |
| Greyboxed templates ship via committed `_generate_bitmasks.py` (Pillow) | Reproducible, regenerable; no opaque pixel data; user edits the silhouettes into final art | — **Validated in Phase 2** (script renamed from `_generate_greybox_templates.py`; produces 14 PNGs at co-located paths) |
| PentaTile does NOT delegate output to Godot's stock terrain solver | Godot's terrain painter solves native terrain layouts, while PentaTile owns dual-grid/Penta synthesis/custom layout dispatch. 2026-04-29 multi-terrain research corrects the earlier broader rejection: Godot `TileData.terrain_set`, `terrain`, and peering bits are acceptable as authoring/indexing input when PentaTile remains the runtime solver. | — Active research direction |
| TileBitTools' `EditorInspectorPlugin` architecture explicitly NOT copied | Their addon is ~3,800 LOC of edit-time UI; PentaTile's identity is small runtime + zero editor polish | — Pending |
| Breaking changes always allowed and encouraged; never add backwards-compat shims | Pre-1.0; audience is the author's own games. User explicit policy 2026-04-26: never defer features or write fallbacks for compat reasons. CHANGELOG entries are the only acceptable "compat" work. | — Active |
| v0.2 architecture: every layout renders via load-time synthesis to a 5-archetype dispatch; runtime overlay layer removed entirely | Eliminates a TileMapLayer per node, simplifies AtlasSlot (drops `diagonal_complement_atlas_coords`), folds Penta4 + Penta5 into one auto-detect layout, makes Single-Tile and any future synthesized layouts share one render path. Synthesis happens at `layout` setter time (editor + runtime); produces the OppositeCorners archetype for masks 6/9. | — **Validated in Phase 2** |
| GitHub release only; no Asset Library | Audience is private; Asset Library discoverability is not a goal this milestone. (Original "no MkDocs" stance reversed 2026-04-29 when Phase 7 added MkDocs docs site as v0.2.0 follow-up.) | — Pending |
| Quality bar is "works in my game" — no formal test suite, no perf benchmarks | Keeps milestone scope tight on the layout library | — Pending |
| One expanded demo scene over multiple per-feature demos | Simpler maintenance; surface area stays small as layouts land | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-25 after v0.2 pivot to layout library*

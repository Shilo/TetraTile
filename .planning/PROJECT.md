# TetraTile

## What This Is

TetraTile is a lightweight dual-grid autotiling addon for Godot 4.6 that exposes a single public node, `TetraTileMapLayer`, on top of the engine's native `TileMapLayer` API. It is built for game developers (initially the author's own projects) who want a small, lean autotiler they can drop into a Godot project and drive with the standard painting and runtime APIs.

## Core Value

Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.

## Requirements

### Validated

<!-- Shipped in v0.1.0 and confirmed working in the demo. -->

- ✓ Single public `TetraTileMapLayer` node extending `TileMapLayer` — v0.1.0
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

- [ ] Atlas contract Resource (`TetraTileAtlasContract`) hosting a typed `layout: TetraTileLayout` reference
- [ ] `TetraTileLayout` base class with virtual `compute_mask` + `mask_to_atlas` dispatch
- [ ] Tetra Horizontal + Tetra Vertical layouts (v0.1 inheritance, ship as the addon's two defaults)
- [ ] DualGrid16 + Wang2Edge + Wang2Corner layouts (TetraTile-native conventions)
- [ ] Blob47Godot + TilesetterWang15 + TilesetterBlob47 layouts (slot tables transcribed from TileBitTools, MIT, attributed)
- [ ] Per-layout `template_image: Texture2D` rendered as inline inspector preview
- [ ] Per-layout `fallback_tile_set: TileSet` used when `TetraTileMapLayer.tile_set` is null (instant prototyping)
- [ ] Per-layout `description: String` (multiline, inspector-editable) plus class-level `##` doc-comment
- [ ] Greyboxed template PNGs for every shipped layout (5 already shipped; 3 pending TBT slot-table transcription)
- [ ] Updated demo scene showcasing all 8 layouts (runtime switching or side-by-side)
- [ ] README "Layouts" section + "Upgrading from 0.1.x" + "Authoring a Custom Layout"
- [ ] `addons/tetra_tile/ATTRIBUTION.md` crediting TileBitTools (MIT)
- [ ] GitHub release tagged `v0.2.0`

### Out of Scope

<!-- Explicitly deferred for this milestone. -->

- Y-axis variation support — Pushed to a future milestone; needs its own discussion (was originally planned for v0.2 but the layout library re-prioritized first)
- Top-tile support — Pushed to a future milestone; needs design after layout library lands
- Non-rotating tileset feature — Largely *delivered* by the DualGrid16 / Wang2Corner / Wang2Edge layouts; any remaining "non-rotating" needs roll into a future milestone if surfaced
- RPG Maker A1/A2/A4 subtile composition — Architecturally reserved (`TetraTileLayout` slot exists) but the quarter-tile compositor is a v0.3+ refactor
- Tiled `.tsx` / LDtk `.ldtk` rule importers — Both editors store autotile rules in project files, not atlases; full support requires rule-importer infrastructure out of scope here
- Excalibur / jaconir Blob 47 convention — Web-game indie convention; no demonstrated Godot adoption; dropped
- Stormcloak / OpenGameArt CR31 community blob variants — Dropped per user direction; insufficient adoption signal
- Godot `MATCH_SIDES` mask layout — Engine semantics disputed in [Godot issue #79411](https://github.com/godotengine/godot/issues/79411); skipped until engine clarifies
- TetraBake (procedural 5th-tile composition) — Parking-lot idea; not needed to unblock author's games
- Tileset converter (Wang/blob → TetraTile) — Authoring tooling deferred
- Outer transition tile support (multi-terrain) — Distinct R&D track
- Shader fallback for diagonal compositing — Performance optimization not needed at demo scale
- Collision authoring / auto-collision generation — TileSet-physics path is sufficient
- MkDocs documentation site — GitHub README is enough
- Godot Asset Library distribution — GitHub-only this milestone
- Formal automated test suite (GUT) — "Works in my game" quality bar
- Large-map performance benchmarking (>10k cells) — Demo-scale only
- Backwards compatibility for v0.1.0 atlases / API — Pre-1.0; breaking changes accepted with migration notes
- Custom layout authoring polished surface (`EditorInspectorPlugin`) — Subclassing `TetraTileLayout` works but is documented as experimental; no editor polish

## Context

- Existing implementation is ~261 LOC of GDScript in a single class plus a working demo scene with a `CharacterBody2D` player and runtime drag-paint script. No external dependencies beyond Godot 4.6.
- Architecture is intentionally lean: no persistent coordinate cache, no signal fanout, no watchers — `_update_cells()` recomputes affected masks on demand and writes directly to two internal `TileMapLayer`s.
- v0.2 pivots from "expand the contract for variation/top/non-rotating" to "ship a library of pluggable layout Resources covering every popular Godot autotiling atlas convention." The user's pain point shifted: the strict 4-tile atlas isn't just visually limiting, it's incompatible with atlases authored anywhere else (Tilesetter, OpenGameArt 47-blob, Godot stock terrain templates, etc.). Solving the layout zoo solves the lock-in.
- Layout-library research lives in `.planning/research/layouts/` — TAXONOMY (24 layouts catalogued), EDITORS (Tiled / LDtk / Tilesetter / Unity / RPG Maker conventions), GODOT_TERRAIN (the engine's stock terrain mechanics + why TetraTile bypasses them), MASK_UNIFICATION (architecture: polymorphic layout Resource), TILESETTER_AND_GODOT (live-doc audit), TILEBITTOOLS (TBT addon audit + slot tables we transcribe), COMPARISON (the artist-facing side-by-side reference).
- TileBitTools (MIT, dandeliondino) already decoded the Tilesetter slot tables. TetraTile transcribes those with attribution rather than empirically fingerprinting, eliminating a research bottleneck.
- The user is comparing TetraTile against TileMapDual; TetraTile's selling point has been minimalism and the 4-tile contract. The layout library expands surface area but keeps the runtime contract small (one base class + 8 subclasses, ~520 LOC estimated total — still well under TileMapDual's ~700–900 LOC).
- Variation, top tiles, and non-rotating tilesets pushed to future milestones. Non-rotating is largely *delivered* by the new DualGrid16 / Wang2Corner / Wang2Edge layouts since those are explicitly per-direction-authored. Variation and top tiles need their own discussion against the new layout shape.

## Constraints

- **Tech stack**: Godot 4.6+ stable. Pure GDScript. No C#, no GDExtension, no third-party dependencies.
- **Engine API**: Implementation must continue to ride `TileMapLayer._update_cells()`. No persistent coordinate cache, signal fanout, or watcher systems (per the existing architecture's "lean" stance).
- **Distribution**: GitHub releases with plain semver tags (no `-pre`, `-alpha`, `-dev` suffixes). No Asset Library submission this milestone.
- **Audience**: The author's own games. No public-API SLA. **Breaking changes are always allowed and explicitly encouraged when they enable improvements; never write backwards-compatibility shims, never defer features because they would break v0.1.** Migration notes go in CHANGELOG and release notes; that's the only "compat" work.
- **Performance**: Demo-scale target (~100–1k cells). Interactive painting and runtime drag-paint must remain fluid; large-map perf is not a milestone gate.
- **Identity**: TetraTile must remain visibly smaller and simpler than TileMapDual; expansions should not pull in terrain metadata, tile caches, or watcher infrastructure.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| v0.2 pivots from "expand the contract" to "layout library" | Layout-library work surfaces the design questions for top tiles + variation + non-rotating; better to land the contract surface area first and discuss those features against a stable foundation | — Pending |
| Layout is a typed `Resource` subclass (`TetraTileLayout`) attached to `TetraTileAtlasContract`, NOT a `RotationMode` enum | The strategy pattern absorbs RPG Maker subtile composition (and other future mask systems) without modifying `_update_cells()`; analyzed and recommended in `.planning/research/layouts/MASK_UNIFICATION.md` | — Pending |
| Each layout Resource exposes `template_image: Texture2D` + `fallback_tile_set: TileSet` for inspector preview and zero-config prototyping | Drop a fresh `TetraTileMapLayer` into a scene with just a layout Resource and start painting — best-in-class onboarding UX, no `EditorInspectorPlugin` required | — Pending |
| Tilesetter slot tables decoded from TileBitTools (MIT) rather than fingerprinted | TBT already published `tilesetter_blob.tres` and `tilesetter_wang.tres` with slot maps; transcribing with attribution is faster and lower-risk than empirical fingerprinting | — Pending |
| Tilesetter Wang is 15 tiles in a 5×3 atlas with one stray fill, not 16 in 4×4 | TBT's verified slot table; earlier secondary-source claim was wrong | — Pending |
| Tilesetter Blob is 11×5 with discrete sub-block gaps, not 7×8 with trailing unused cells | TBT's verified slot table; matches user's reference images | — Pending |
| Variation, top tiles, and "non-rotating" pushed to a future milestone (post-v0.2) | DualGrid16 / Wang2Corner / Wang2Edge layouts cover the asymmetric-art case the user wanted; variation and platformer top tiles need design discussion against the new layout-library shape | — Pending |
| Excalibur / jaconir / Stormcloak / OpenGameArt CR31 dropped from layout library | No demonstrated Godot adoption; user only cares about Godot-native and Tilesetter conventions | — Pending |
| Godot `MATCH_SIDES` skipped | Engine semantics disputed (issue #79411); revisit when engine clarifies | — Pending |
| RPG Maker A2/A4 architecturally reserved but deferred | Quarter-tile subtile composition doesn't fit the unified `_update_cells` dispatch — it's a separate pipeline; v0.3+ work | — Pending |
| Greyboxed templates ship via committed `_generate_greybox_templates.py` (Pillow) | Reproducible, regenerable; no opaque pixel data; user edits the silhouettes into final art | — Pending |
| TetraTile does NOT integrate with Godot's stock terrain peering bits | Defeats the v0.1 selling point of "no manual bitmask authoring." Comparison and reasoning in `.planning/research/layouts/GODOT_TERRAIN.md` | — Pending |
| TileBitTools' `EditorInspectorPlugin` architecture explicitly NOT copied | Their addon is ~3,800 LOC of edit-time UI; TetraTile's identity is small runtime + zero editor polish | — Pending |
| Breaking changes always allowed and encouraged; never add backwards-compat shims | Pre-1.0; audience is the author's own games. User explicit policy 2026-04-26: never defer features or write fallbacks for compat reasons. CHANGELOG entries are the only acceptable "compat" work. | — Active |
| v0.2 architecture: every layout renders via load-time synthesis to a 5-archetype dispatch; runtime overlay layer removed entirely | Eliminates a TileMapLayer per node, simplifies AtlasSlot (drops `diagonal_complement_atlas_coords`), folds Tetra4 + Tetra5 into one auto-detect layout, makes Single-Tile and any future synthesized layouts share one render path. Synthesis happens at `atlas_contract` setter time (editor + runtime), bit-identical to v0.1 overlay output for masks 6/9. | — Pending (Phase 2) |
| GitHub release only; no Asset Library, no MkDocs | Audience is private; discoverability and full docs site are not goals this milestone | — Pending |
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

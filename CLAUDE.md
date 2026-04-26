# TetraTile — Claude Code Project Guide

## Project

TetraTile is a lightweight dual-grid autotiling addon for **Godot 4.6** built around a single public node, `TetraTileMapLayer`, that subclasses `TileMapLayer`. Users paint with the native `set_cell()` / `erase_cell()` API and the addon generates dual-grid visuals automatically through `_update_cells()`.

The current codebase is v0.1.0 (4-tile binary atlas: Fill, Inner Corner, Border, Outer Corner). The active milestone is **v0.2.0 — "Layout Library + Preview Fallback"** which ships a library of pluggable `TetraTileLayout` Resources covering every popular Godot autotiling atlas convention (Tetra, DualGrid16, Wang2Edge, Wang2Corner, Min3x3, TBT-decoded Blob/Wang, PixelLab, plus a Single-Tile prototyping layout). The original v0.2 pillars (Y-axis variation, top tiles, non-rotating tilesets) deferred to v2 backlog. See `.planning/ROADMAP.md` for current phases.

## Stack

- **Engine:** Godot 4.6.x stable, Windows (executable: `C:\Programming_Files\Godot\Godot_v4.6.2-stable_win64.exe`)
- **Language:** GDScript 2 (`@tool`, `class_name`, typed `Array[Resource]`, `@export_group`)
- **No third-party deps.** No C#, no GDExtension, no GUT — pure Godot native.
- **Distribution:** GitHub releases only (no Asset Library this milestone), tagged `vX.Y.Z` (no `-pre`/`-alpha`/`-dev` suffixes).

Key Godot APIs in use:
- `TileMapLayer._update_cells(coords, forced_cleanup)` — the single autotile egress point
- `TileSetAtlasSource` + `alternative_tile` int packing (`TRANSFORM_FLIP_H=4096 | FLIP_V=8192 | TRANSPOSE=16384` OR'd with low-bit alt-IDs)
- `TileData.probability` — read-only weights for variation (Godot does NOT auto-pick at `set_cell` time; the addon runs its own deterministic-hash `rand_weighted` inside `_update_cells`)
- `TileSet.custom_data_layers` — for per-tile flags like `tetra_role` and `tetra_lock_rotation`

## Layout

```
addons/tetra_tile/
  plugin.cfg
  tetra_tile_map_layer.gd          # core class (~261 LOC at v0.1.0)
  tetra_tile_template.png          # blank 4-tile reference template
  demo/
    tetra_tile_demo.tscn           # main demo scene (entry point)
    demo_player.gd                 # CharacterBody2D platformer player
    demo_runtime_painter.gd        # left-click paint, right-click erase, drag-paint
    tetra_tile_ground.png/.tres    # demo TileSet with collision polygons
.planning/                         # GSD planning artifacts (committed to git)
  PROJECT.md                       # what we're building, why, constraints
  REQUIREMENTS.md                  # 30 v1 REQ-IDs + v2 deferred + Out of Scope
  ROADMAP.md                       # 5-phase plan with success criteria
  STATE.md                         # current position, decisions, blockers
  config.json                      # workflow config (interactive, standard, parallel, opus quality)
  research/                        # SUMMARY.md + STACK/FEATURES/ARCHITECTURE/PITFALLS
  codebase/                        # ARCHITECTURE/CONCERNS/CONVENTIONS/etc. from /gsd-map-codebase
```

## GSD Workflow

This project uses Get Shit Done (GSD) for structured execution. The phases of v0.2.0 are:

1. **Contract Skeleton + Tetra Layouts** ✅ DONE — `TetraTileAtlasContract` + `TetraTileLayout` base + `AtlasSlot`; Tetra Horizontal + Vertical layouts.
2. **Native Layouts** — DualGrid16, Wang2Edge, Wang2Corner, Min3x3 + Tetra layouts gain load-time synthesis of the 5th `OppositeCorners` archetype (drops the runtime overlay layer entirely).
2.1 **Single-Tile Layout (Prototyping)** — `TetraTileLayoutSingleTile` slices ONE source image into 5 archetypes at load time.
3. **TileBitTools-Decoded Layouts** — Blob47Godot, TilesetterWang15, TilesetterBlob47 with attribution.
3.5 **PixelLab Layouts + Variation-Bank Wiring** — PixelLabTopDown + PixelLabSideScroller (8×8 atlas, internal variation banks).
4. **Fallback Routing** — `tile_set == null` → `layout.fallback_tile_set`.
5. **Demo Refresh + Documentation + Release** — updated demo, README, CHANGELOG, `v0.2.0` tag.

Authoritative source: `.planning/ROADMAP.md` (this list is a summary, not the spec).

**Workflow commands:**
- `/gsd-progress` — current position, next action
- `/gsd-plan-phase N` — plan a phase before executing it
- `/gsd-discuss-phase N` — clarify approach before planning
- `/gsd-execute-phase N` — execute the planned phase
- `/gsd-verify-work` — UAT against requirements after a phase
- `/gsd-help` — full command list

The active config is in `.planning/config.json`: interactive mode, standard granularity, parallel plan execution, "quality" model profile (Opus for research/roadmap), with research/plan-check/verifier all enabled.

## Identity Guardrails

The PROJECT.md identity constraint is **"TetraTile must remain visibly smaller and simpler than TileMapDual."** When making implementation decisions, reject:

- Terrain peering metadata or terrain rule tries (TileMapDual / Better Terrain territory)
- Multi-terrain transitions (deferred to a future milestone)
- Watcher / signal-fanout systems (TileMapDual's leaks/crashes are cited evidence)
- Persistent coordinate caches (demo-scale doesn't need them)
- Custom drawing API parallel to `set_cell()` (defeats the v0.1 native-API win)
- `EditorInspectorPlugin` polish (typed `@export` + `@export_group` is enough)

LOC checkpoints fire at end of Phase 1, end of Phase 4, and end of Phase 5 (final audit vs. TileMapDual's surface area).

## Quality Bar

**"Works in my game."** No formal test suite (GUT) this milestone. Visual regression on the demo is the primary verification mechanism. Demo-scale only (~100–1k cells); no large-map perf benchmarks.

## Breaking Changes Policy (HARD RULE)

**Breaking changes are always allowed. Always.** This project is pre-1.0 and the audience is the author's own games.

- **Never** write backwards-compatibility shims, deprecation aliases, version-detection branches, or migration fallbacks to preserve v0.1 behavior.
- **Never** defer or scope-down a feature/refactor because it would break existing code or saved scenes.
- **Never** keep an obsolete code path "for compatibility" — delete it.
- When the new design is better, ship it. Document the breakage in CHANGELOG and release notes; that is the only acceptable "compat" work.
- This rule OVERRIDES any default Claude Code instinct to preserve existing behavior or add fallbacks.

If a refactor reveals breaking changes mid-implementation, do not stop to ask — note them in the commit message and proceed. Discuss only when the user invites a design conversation, not to gate breakage approval.

## Critical Pitfalls (from research)

When implementing v0.2.0 features, watch for:

1. **`alternative_tile` bit packing** — alt-ID and `TRANSFORM_FLIP_*` flags share one int; always OR them together via `_pack_alternative()`; assert `alt_id < 4096`.
2. **Variation determinism** — never `randi()`. Always `RandomNumberGenerator.seed = hash(Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_seed)` then `rand_weighted()`. Otherwise `rebuild()` shimmers.
3. **Resource property renames orphan saved scenes silently** — Godot 4.6 has no automatic property-rename migration. Use `@export_storage` shadow + `__migrate__()` two-step pattern; CHANGELOG every rename.
4. **Setter loops + `Resource.changed` storms** — idempotence guard (`if value == _atlas_contract: return`), disconnect-before-reconnect on `Resource.changed`, ride the existing `_queue_rebuild` deferred coalescer.
5. **Non-rotating tileset table** — 16 runtime entries GENERATED from the rotating table at contract-load time. Never hand-write 64 entries. Mask 0 special-cased on the FIRST line of the paint function.
6. **Top-tile assignment must be EXPLICIT per-mask in the contract** — never inferred via "tile below is filled" heuristics. Auto-detection bakes platformer assumptions into the addon.
7. **`TileMapLayer.visible = false` cleanup behavior** — already mitigated in v0.1 via `self_modulate.a` on the logic layer. Don't regress.

Full pitfall analysis is in `.planning/research/PITFALLS.md`.

## Coding Conventions

- Class names: PascalCase (`TetraTileMapLayer`, `TetraTileAtlasContract`)
- Public methods: `snake_case` without leading underscore (`rebuild()`, `set_cell()`)
- Private methods: `_snake_case` (`_resolve_slot()`, `_pick_alternative()`)
- Constants: `_UPPER_SNAKE_CASE` (private, `_FILL`, `_ROTATE_90`)
- Enum members: `UPPER_CASE` (`HORIZONTAL`, `NON_ROTATING`)
- Export properties: `snake_case` (`atlas_source_id`, `atlas_contract`)
- File names: snake_case matching class name (`tetra_tile_map_layer.gd` → `TetraTileMapLayer`)

## Next Step

Run `/gsd-progress` to see current position, or jump into Phase 1 with `/gsd-discuss-phase 1` (recommended) or `/gsd-plan-phase 1`.

---
gsd_state_version: 1.0
milestone: v0.2.0
milestone_name: milestone
status: planning
stopped_at: Phase 2 context gathered (Tetra5 append + overlay-skip refactor)
last_updated: "2026-04-26T08:19:53.959Z"
last_activity: 2026-04-26
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 5
  completed_plans: 5
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-25 after v0.2 pivot to layout library)

**Core value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.
**Current focus:** Phase 2 — Native Layouts (DualGrid16, Wang2Edge, Wang2Corner, Minimal3x3)

## Current Position

Phase: 2
Plan: Not started
Status: Ready to plan
Last activity: 2026-04-26

Progress: [░░░░░░░░░░] 0%

> Out-of-band progress: 5 of 8 greyboxed template PNGs + the generator script shipped in commit e86036f as part of the discovery pass. Counted as TEMPLATE-01 + TEMPLATE-03 covered. The remaining 3 templates (Blob47Godot, TilesetterWang15, TilesetterBlob47) ship in Phase 3 once their slot tables are transcribed from TileBitTools.

## Performance Metrics

**Velocity:**

- Total plans completed: 5
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 5 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Roadmap Evolution

- 2026-04-26: Phase 2.1 inserted after Phase 2 (single-tile-layout) — ships `TetraTileLayoutSingleTile`. Adds 5 requirements (SINGLE-01..05). Companion artifact: `.planning/research/layouts/RPG_MAKER.md` audits the RPG Maker family and recommends offline-importer path for v0.3+ — out of scope for v0.2.0.
- 2026-04-26 (later): **Architectural pivot — overlay-layer removal + unified Tetra synthesis.** The Phase 2.1 brainstorm session reframed Phase 2's Tetra5 work. Instead of shipping `TetraTileLayoutTetra5Horizontal`/`Vertical` as separate classes (CONTEXT.md D-28..D-46), the existing Tetra layouts gain load-time synthesis of the 5th OppositeCorners archetype from the OuterCorner tile. The runtime `_overlay_layer` is **deleted entirely** — every v0.2 layout renders via single-layer 5-archetype dispatch. Tetra layouts auto-detect 4-vs-5 source tiles. Single-Tile (Phase 2.1) updated to slice into 5 archetypes (not 4). Adds 6 new requirements (TETRA-SYNTH-01..06), supersedes Phase 2's planned TETRA5-* IDs (which never landed in REQUIREMENTS.md). Multi-terrain Y-axis convention added to v2 backlog (MULTITERR-01..05) with explicit design-coupling note to VAR-01 (variation). Full supersession notice in `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md`. Coverage 50 → 56 requirements.
- 2026-04-26 (later): **User policy update — breaking changes always allowed.** Recorded as feedback memory + CLAUDE.md "Breaking Changes Policy (HARD RULE)" + PROJECT.md constraint update. Never write backwards-compat shims. Never defer features for compat reasons. CHANGELOG entries are the only acceptable compat work.
- 2026-04-26 (later): **Phase 2.1 collapsed back into Phase 2 — TETRA1 mode folded into the Tetra layout via auto-detect.** The unified `TetraTileLayoutTetraHorizontal`/`Vertical` classes now handle three modes (TETRA1 / TETRA4 / TETRA5) via auto-detection of the source atlas strip-axis tile count. `TileCountMode` enum (`AUTO` / `TETRA1` / `TETRA4` / `TETRA5`) provides explicit override. Single class per axis covers all modes; SINGLE-01..05 retired and TETRA-SYNTH-* expanded from 6 to 9 requirements. Phase 2.1 directory removed (was empty). Coverage 56 → 54. Total phases 7 → 6. Naming convention: enum members use `TETRA1`/`TETRA4`/`TETRA5` (UPPER_SNAKE_CASE per GDScript style); requirement IDs remain `TETRA-SYNTH-*`. Full algorithm + edge-case handling captured in Phase 2 DISCUSSION-LOG D-53..D-55.

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v0.2 pivot from "expand the contract" (variation + top tiles + non-rotating) to "layout library" (8 pluggable layout Resources)
- Layout = typed `Resource` subclass (`TetraTileLayout`) hung off `TetraTileAtlasContract`, NOT a `RotationMode` enum on the contract
- Each layout exposes `template_image: Texture2D` + `fallback_tile_set: TileSet` + `description: String` for inspector preview and zero-config prototyping
- Tilesetter slot tables transcribed from TileBitTools (MIT, attributed) rather than empirically fingerprinted
- Tilesetter Wang is 15 tiles in 5×3, not 16 in 4×4 (per TBT verified slot table)
- Tilesetter Blob is 11×5 with sub-block gaps, not 7×8 (per TBT verified slot table)
- Variation, top tiles, "non-rotating" pushed to a future milestone — DualGrid16/Wang2Corner/Wang2Edge layouts cover the asymmetric-art case the user wanted
- Excalibur/jaconir/Stormcloak/OpenGameArt CR31 dropped from the layout library (no Godot adoption signal)
- Godot `MATCH_SIDES` skipped (engine semantics disputed in issue #79411)
- RPG Maker A2/A4 architecturally reserved (subtile compositor) but deferred to v0.3+
- TetraTile does NOT integrate with Godot's stock terrain peering bits (defeats v0.1's "no manual bitmask authoring" selling point)
- TileBitTools' `EditorInspectorPlugin` architecture explicitly not copied (3,800-LOC editor UI conflicts with TetraTile's "small runtime + no editor polish" identity)
- **Breaking changes always allowed and encouraged** (user policy 2026-04-26). Never write backwards-compat shims; never defer features because they would break v0.1. CHANGELOG entries are the only acceptable compat work. CLAUDE.md "Breaking Changes Policy (HARD RULE)" formalizes this; PROJECT.md constraint updated.
- **Overlay-layer removal + unified 5-archetype synthesis** (2026-04-26). All v0.2 layouts render via single-layer 5-archetype dispatch. Tetra layouts auto-detect 4-vs-5 source tile counts and synthesize the 5th OppositeCorners archetype from the OuterCorner tile when needed. `_overlay_layer`, `_paint_overlay_for_slot`, `AtlasSlot.diagonal_complement_atlas_coords`, and the planned `needs_diagonal_overlay()` virtual are all deleted. Synthesis is bit-identical to v0.1 overlay output for masks 6/9 (verified via pixel-hash test). Phase 2 supersedes the previously-planned separate Tetra5* layout classes. See `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md` SUPERSESSION NOTICE for D-47..D-52.
- **Multi-terrain in v2 backlog** (MULTITERR-01..05) with explicit design-coupling to VAR-01 (Y-axis variation) — both compete for atlas Y-axis interpretation; future brainstorm must resolve them together. Strip layouts (Single-Tile, Tetra) use Y-as-terrain; block layouts (DualGrid16, Wang*, PixelLab) need a different mechanism (likely multiple atlas sources).

### Pending Todos

None yet.

### Blockers/Concerns

- **Phase 3 TBT slot-table transcription:** the load-bearing data work for Phase 3. Each `.tres` from TBT needs to be read and translated into a TetraTile mask-to-slot table; mistakes here corrupt rendering for that layout. Mitigated by visual regression on the demo for each shipped layout.
- **`atlas_layout` enum deprecation:** v0.1's `atlas_layout: AtlasLayout` enum (`HORIZONTAL` / `VERTICAL`) is replaced by the explicit `TetraTileLayoutTetraHorizontal` / `Vertical` Resources. Existing scenes using the enum need migration; flagged for CHANGELOG.

## Deferred Items

Items acknowledged and carried forward as v2 requirements (see REQUIREMENTS.md v2 section):

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Variation | Y-axis variation via `TileData.probability` (VAR-01) | future milestone | 2026-04-25 (v0.2 pivot) |
| Top Tiles | Designated top-edge visuals (TOP-01) | future milestone | 2026-04-25 (v0.2 pivot) |
| RPG Maker | Subtile compositor for A2/A4 (RPGM-01/02) | v0.3+ | 2026-04-25 |
| External Editors | Tiled `.tsx` / LDtk `.ldtk` rule importers (IMPORT-01/02) | v0.3+ | 2026-04-25 |
| Tooling | TetraBake / Wang→TetraTile converter (TOOL-01/02) | v2 | 2026-04-25 |
| Multi-terrain | Outer transition tiles (TERRAIN-01) | v2 | 2026-04-25 |
| Performance | Shader fallback / large-map benchmarks (PERF-01/02) | v2 | 2026-04-25 |
| Distribution | Asset Library / GUT test suite (DIST-01/02) | v2 | 2026-04-25 |

## Session Continuity

Last session: --stopped-at
Stopped at: Phase 2 context gathered (Tetra5 append + overlay-skip refactor)
Resume file: --resume-file

**Completed Phase:** 01 (Contract Skeleton + Tetra Layouts) — 5/5 plans, 14/14 requirements, 26/26 automated tests PASS — 2026-04-26
**Next Phase:** 02 (Native Layouts) — DualGrid16, Wang2Edge, Wang2Corner, Minimal3x3 (subclass adds; single-grid pipeline already wired by Phase 1's D-06)

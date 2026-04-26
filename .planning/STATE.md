# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-25 after v0.2 pivot to layout library)

**Core value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.
**Current focus:** Phase 1 — Contract Skeleton + Tetra Layouts

## Current Position

Phase: 1 of 5 (Contract Skeleton + Tetra Layouts)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-04-25 — Roadmap re-spun for layout library; 39/39 requirements mapped

Progress: [░░░░░░░░░░] 0%

> Out-of-band progress: 5 of 8 greyboxed template PNGs + the generator script shipped in commit e86036f as part of the discovery pass. Counted as TEMPLATE-01 + TEMPLATE-03 covered. The remaining 3 templates (Blob47Godot, TilesetterWang15, TilesetterBlob47) ship in Phase 3 once their slot tables are transcribed from TileBitTools.

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

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

Last session: 2026-04-25
Stopped at: Roadmap re-spun for layout library; ready to plan Phase 1
Resume file: None

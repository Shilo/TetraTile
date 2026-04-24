# TetraTile

TetraTile is a lightweight dual-grid autotiling addon for Godot 4.6. It exposes one public node, `TetraTileMapLayer`, which subclasses `TileMapLayer` and uses Godot's native painting/runtime API. Draw with the normal TileMap tools or call `set_cell()`/`erase_cell()`; the generated dual-grid visuals update through `_update_cells()`.

The core atlas contract is intentionally small: four tiles in order:

1. Fill
2. Inner Corner
3. Border
4. Outer Corner

The two disconnected diagonal states are handled by composing two transformed outer corners on an internal overlay layer. This preserves the four-tile source template without pretending those masks can be represented by a single transformed tile.

## Addon Layout

```text
addons/tetra_tile/
  plugin.cfg
  tetra_tile_map_layer.gd
  tetra_tile_template.png
  demo/
    demo_player.gd
    tetra_tile_demo.tscn
    tetra_tile_ground.png
    tetra_tile_ground.tres
```

`tetra_tile_template.png` is the blank 4-tile template. `demo/tetra_tile_ground.png` and `demo/tetra_tile_ground.tres` are the demo atlas/TileSet.

## Current API

`TetraTileMapLayer` extends `TileMapLayer`.

Use the native TileMapLayer API:

- `set_cell()`
- `erase_cell()`
- editor painting tools
- `tile_set`
- inherited TileMapLayer rendering/physics properties where applicable

Additional exported properties:

| Property | Purpose |
| --- | --- |
| `atlas_source_id` | Atlas source to read from. `-1` uses the first source in the TileSet. |
| `atlas_layout` | Supports horizontal 4x1 or vertical 1x4 atlas layouts. |
| `logic_layer_opacity` | Opacity for the hidden/editable logic layer. Defaults to `0.0`. |
| `visual_z_index_offset` | Z index applied to generated internal visual layers. |
| `generated_collision_enabled` | Enables collisions on generated visual layers when the TileSet tiles have physics polygons. |
| `logic_collision_enabled` | Enables collisions on the source logic layer. Defaults to `false` to avoid hidden full-cell colliders. |

Public helper:

| Method | Purpose |
| --- | --- |
| `rebuild()` | Clears and regenerates all visual cells from the current logic cells. |

## TetraTile vs TileMapDual API

| Area | TetraTile | TileMapDual |
| --- | --- | --- |
| Public node | `TetraTileMapLayer` | `TileMapDual` plus supporting addon classes |
| Drawing API | Native `TileMapLayer.set_cell()` / editor painting | Native painting plus custom helpers such as `draw_cell(cell, terrain)` |
| Update hook | `_update_cells(coords, forced_cleanup)` directly recomputes affected masks | `_update_cells()` forwards into display/cache/watcher systems |
| Terrain model | Binary occupied/empty terrain for V1 | Terrain peering bits and terrain rules |
| Tile requirement | Four source tiles, with two-layer composition for diagonals | 15-16 tile dual-grid/Wang-style sets |
| Internal state | No persistent coordinate cache; direct 4-bit sampling | Tile caches, terrain rule tries, watchers, signals |
| TileSet setup | Strict atlas order, no terrain metadata required | Terrain metadata and optional editor autotile setup |
| Grid scope | Square orthogonal V1 | Broader grid-shape handling |
| Collisions | Generated visual layers can use TileSet physics polygons | Display layers copy collision-related properties from the parent |

TetraTile is smaller because it gives up TileMapDual's multi-terrain/general-grid flexibility. TileMapDual remains the better fit when you need complex transitions, terrain metadata workflows, or established 16-tile dual-grid sets.

## Demo

Open `res://addons/tetra_tile/demo/tetra_tile_demo.tscn`.

The demo includes:

- a `TetraTileMapLayer`
- a demo TileSet with collision polygons on all four template tiles
- generated visual-layer collisions enabled
- hidden logic-layer collisions disabled
- a `CharacterBody2D` using Godot's `icon.svg`, a capsule collision shape, gravity, arrow-key movement, and jump with Up/Space

## Implementation Notes

Mask bits use:

| Bit | Quadrant |
| --- | --- |
| `1` | Top-left |
| `2` | Top-right |
| `4` | Bottom-left |
| `8` | Bottom-right |

The diagonal masks are `6` and `9`. They are drawn by placing one outer corner on the primary visual layer and the other on the internal overlay layer.

The logic layer is hidden with `self_modulate.a`, not `visible = false`, because Godot may force cleanup behavior when a `TileMapLayer` is disabled, hidden, removed, or missing a TileSet.

## Roadmap

Future ideas remain intentionally separate from the V1 API:

- **TetraBake:** edit-time utility to procedurally compose a fifth edge/diagonal connector tile when useful.
- **Y-axis variations:** support atlas rows for deterministic/random visual variation.
- **Shader fallback:** single-pass shader option for diagonal compositing.
- **Collision tooling:** research automatic collision generation and better collision presets. V1 supports TileSet-authored collision polygons on generated visual layers.
- **Outer transition tile support:** support transitions between terrain types, such as grass to dirt.
- **Top tiles:** support tilesets with designated top visuals for platformer-style grass caps.
- **Non-rotating tilesets:** support perspectives where top/bottom/left/right are not interchangeable.
- **MkDocs:** fuller documentation inspired by TileMapDual's docs.
- **Tileset converter:** convert Wang/blob tilesets or single-tile inputs into TetraTile-compatible atlases.

## Attributions

- `addons/tetra_tile/demo/tetra_tile_ground.png` is derived from Kenney's [Pico-8 Platformer](https://kenney.nl/assets/pico-8-platformer) asset pack (CC0).

# 🍀 TetraTile

Lightweight **autotiling addon** for Godot designed to simplify tileset creation by using a 4-tile template instead of the traditional 47-tile blob set. It uses a **Dual-Grid logic engine** to generate complex tiling visuals from a minimal set of source assets.

By utilizing the Dual Grid concept, TetraTile takes four base tiles, **Fill, Inner Corner, Border, and Outer Corner**, and expands them into a complete tileset with the same visual coverage as a traditional 47-tile set, but with significantly reduced asset requirements.

<div style="image-rendering: pixelated; image-rendering: crisp-edges;">
  <img src="addons/tetra_tile/templates/tetra_horizontal.png" width="256" alt="Tetra Horizontal Tileset Template">
</div>

## 📑 Table of Contents

1. [Why TetraTile?](#-why-tetratile)
2. [The Tetra-System Template](#-the-tetra-system-template)
3. [Comparison: TetraTile vs. TileMapDual](#-tetratile-vs-tilemapdual-api)
4. [Choosing the Right Tool](#-choosing-the-right-tool)
5. [Addon Layout](#-addon-layout)
6. [Current API](#-current-api)
7. [Demo](#-demo)
8. [Implementation Notes](#-implementation-notes)
9. [Roadmap](#-roadmap)
10. [External Resources](#-external-resources)

## 🚀 Why TetraTile?

- **Reduced Tile Requirements:** Creating 47 tiles for a single terrain type is a time-consuming task. TetraTile reduces this requirement to just four tiles, lowering the barrier for creating custom game art while maintaining professional results.
- **Efficient Visual Variation:** Managing only **four base tiles** allows for easier creation of **multiple variations**. Instead of redrawing dozens of tiles for a single alternative set, you can quickly iterate on the core four tiles to add organic variety and reduce repetitive patterns.
- **Native Integration:** Built as a single-class subclass of `TileMapLayer`, TetraTile hooks directly into Godot's native API. It listens to standard drawing commands and updates the visual layers in real-time without requiring a custom drawing interface.

## 🎨 The Tetra-System Template

To use the system, your atlas needs these four essential components arranged horizontally or vertically:

1.  **Fill** (The solid core)
2.  **Inner Corner** (For internal nooks)
3.  **Border** (Straight edges)
4.  **Outer Corner** (The finishing touch)

The two disconnected diagonal states are handled by composing two transformed outer corners on an internal overlay layer. This preserves the four-tile source template without requiring unique tiles for diagonal connections.

## ⚔️ TetraTile vs. TileMapDual API

While [TileMapDual](https://github.com/pablogila/TileMapDual) is a established solution for Dual Grid systems in Godot, **TetraTile** focuses on minimizing the technical overhead and asset requirements for standard orthogonal grids.

| Area             | TetraTile                                                                  | TileMapDual                                                            |
| ---------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Public node      | `TetraTileMapLayer`                                                        | `TileMapDual` plus supporting addon classes                            |
| Drawing API      | Native `TileMapLayer.set_cell()` / editor painting                         | Native painting plus custom helpers such as `draw_cell(cell, terrain)` |
| Update hook      | `_update_cells(coords, forced_cleanup)` directly recomputes affected masks | `_update_cells()` forwards into display/cache/watcher systems          |
| Terrain model    | Binary occupied/empty terrain for V1                                       | Terrain peering bits and terrain rules                                 |
| Tile requirement | Four source tiles, with two-layer composition for diagonals                | 15-16 tile dual-grid/Wang-style sets                                   |
| Internal state   | No persistent coordinate cache; direct 4-bit sampling                      | Tile caches, terrain rule tries, watchers, signals                     |
| TileSet setup    | Strict atlas order, no terrain metadata required                           | Terrain metadata and optional editor autotile setup                    |
| Grid scope       | Square orthogonal V1                                                       | Broader grid-shape handling                                            |
| Collisions       | Generated visual layers can use TileSet physics polygons                   | Display layers copy collision-related properties from the parent       |

TetraTile is smaller because it focuses on a specific subset of the multi-terrain/general-grid flexibility offered by TileMapDual.

## ⚖️ Choosing the Right Tool

### Why choose TetraTile?

- **Scalability of Variations:** Because the requirement is only 4 tiles, creating multiple visual variations is significantly faster and more manageable.
- **Engine Purity:** TetraTile acts as a lightweight extension of the native `TileMapLayer`. It allows you to use Godot's native painting tools as intended, with the system handling the transformation logic automatically.
- **Direct Logic:** It uses direct bitwise math to determine rotations and flips, avoiding complex dictionary lookups or signal-heavy architectures.

### Why choose [TileMapDual](https://github.com/pablogila/TileMapDual)?

- **Complex Transitions:** For projects requiring complex "Grass-to-Sand-to-Rock" multi-terrain blending, TileMapDual is designed to handle that specific complexity.
- **Standard Templates:** If you are already working with 16-tile Dual Grid (Wang) tilesets, TileMapDual provides a direct solution for those templates.

## 🛠️ Addon Layout

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

## 🔌 Current API

`TetraTileMapLayer` extends `TileMapLayer`.

Use the native TileMapLayer API:

- `set_cell()`
- `erase_cell()`
- editor painting tools
- `tile_set`
- inherited TileMapLayer rendering/physics properties where applicable

Additional exported properties:

| Property                      | Purpose                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------ |
| `atlas_source_id`             | Atlas source to read from. `-1` uses the first source in the TileSet.                                  |
| `atlas_layout`                | Supports horizontal 4x1 or vertical 1x4 atlas layouts.                                                 |
| `logic_layer_opacity`         | Opacity for the hidden/editable logic layer. Defaults to `0.0`.                                        |
| `visual_z_index_offset`       | Z index applied to generated internal visual layers.                                                   |
| `generated_collision_enabled` | Enables collisions on generated visual layers when the TileSet tiles have physics polygons.            |
| `logic_collision_enabled`     | Enables collisions on the source logic layer. Defaults to `false` to avoid hidden full-cell colliders. |

Public helper:

| Method      | Purpose                                                               |
| ----------- | --------------------------------------------------------------------- |
| `rebuild()` | Clears and regenerates all visual cells from the current logic cells. |

## 🧪 Demo

Open `res://addons/tetra_tile/demo/tetra_tile_demo.tscn`.

The demo includes:

- a `TetraTileMapLayer`
- a demo TileSet with collision polygons on all four template tiles
- generated visual-layer collisions enabled
- hidden logic-layer collisions disabled
- a `CharacterBody2D` using Godot's `icon.svg`, a capsule collision shape, gravity, arrow-key movement, and jump with Up/Space
- runtime editing: left click places the default logic tile, right click erases a logic tile

## 📝 Implementation Notes

Mask bits use:

| Bit | Quadrant     |
| --- | ------------ |
| `1` | Top-left     |
| `2` | Top-right    |
| `4` | Bottom-left  |
| `8` | Bottom-right |

The diagonal masks are `6` and `9`. They are drawn by placing one outer corner on the primary visual layer and the other on the internal overlay layer.

The logic layer is hidden with `self_modulate.a`, not `visible = false`, because Godot may force cleanup behavior when a `TileMapLayer` is disabled, hidden, removed, or missing a TileSet.

## 🗺️ Roadmap

Future ideas remain intentionally separate from the V1 API:

- **TetraBake:** edit-time utility to procedurally compose a fifth edge/diagonal connector tile when useful.
- **Y-axis variations:** support atlas rows for deterministic/random visual variation.
- **Shader fallback:** single-pass shader option for diagonal compositing.
- **Collision tooling:** research automatic collision generation and better collision presets. V1 supports TileSet-authored collision polygons on generated visual layers.
- **Outer transition tile support:** support transitions between terrain types, such as grass to dirt.
- **Top tiles:** support sets with designated top visuals for platformer-style grass caps.
- **Non-rotating tilesets:** support perspectives where top/bottom/left/right are not interchangeable.
- **MkDocs:** fuller documentation inspired by TileMapDual's docs.
- **Tileset converter:** convert Wang/blob tilesets or single-tile inputs into TetraTile-compatible atlases.

## 🔗 External Resources

- [Godot 4 Autotilling Documentation](https://github.com/dandeliondino/godot-4-tileset-terrains-docs) - A detailed guide and starter project for understanding Godot 4's native terrain system.
- [The Dual Grid Concept](https://www.youtube.com/watch?v=jEWFSv3ivTg) - A brilliant deep dive into how offset grid math solves the 47-tile problem.
- [Drawing Only 5 Tiles](https://www.youtube.com/watch?v=aWcCNGen0cM) - The inspiration for TetraTile's minimalism, showing how to achieve high-end results with a tiny asset footprint.

## 🙏 Attributions

- [Kenney's Pico-8 Platformer](https://kenney.nl/assets/pico-8-platformer) - Asset pack used for the demo ground texture (CC0).

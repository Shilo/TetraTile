# PentaTile MVP Research

## Verdict

PentaTile should proceed, but with one corrected constraint: four source tiles cannot faithfully draw the two disconnected diagonal marching-squares states in a single visual tile. The professional V1 solution is still a single public `PentaTileMapLayer` class, but it must manage a second internal visual `TileMapLayer` for diagonal composition. That keeps the asset template at four tiles and avoids a shader or bake dependency.

The previous handoff also had a mask error. With `TL=1`, `TR=2`, `BL=4`, `BR=8`, the diagonal bridge masks are `6` and `9`. Masks `5` and `10` are adjacent edge pairs.

## TileMapDual Burn-Down

Reference inspected: `C:\Programming_Files\Shilocity\Godot\Tests\TileMapDual-main\addons\TileMapDual`.

TileMapDual is valuable proof that the native `_update_cells` interception path works in a real addon. Its `tile_map_dual.gd` override forwards changed cells from editor drawing and undo/redo into its display update path.

For PentaTile, most of its architecture is deliberate bulk:

- `TileSetWatcher` and `AtlasWatcher` poll and signal TileSet mutations. PentaTile V1 uses a fixed 4-tile atlas and can rebuild from `_update_cells`/manual `rebuild()` instead of maintaining watcher state.
- `TerrainDual`/`TerrainLayer` parse terrain peering bits and build a trie of rules. PentaTile has one binary terrain and 16 masks, so a `match` table is clearer and faster.
- `Display` supports square, isometric, half-offset, and hex layer layouts. PentaTile V1 should be square-grid only until the 4-tile contract is proven.
- `TileCache` persists world-cell dictionaries and emits changed-cell signals. PentaTile can sample the four logic cells directly from the parent layer.
- Editor popups, ghost material warning flow, cursor assets, compatibility refresh timers, and legacy implementation files solve TileMapDual's broader product scope, not this MVP.

What should be preserved:

- The clean user model: edit a logic/world layer and render generated visuals on managed display layers.
- The native hook shape: `_update_cells(coords, forced_cleanup)` is the right interception point.
- Hiding the logic layer should not hide generated visuals. PentaTile uses `self_modulate.a` on the parent rather than `visible=false`, because Godot treats invisible layers as cleanup cases.

## Four Tiles vs Five

The 5-tile claim is real when the goal is a single complete visual cell per marching-squares state. Independent tiling references describe dual-grid/marching-squares ambiguity and quarter-tile systems as requiring extra shapes or precomposition for full fidelity. BorisTheBrave's quarter-tile article says rotatable quarter tiles need five shapes and calls out that smaller tile counts reduce what styles can represent cleanly.

PentaTile's four-tile template works by changing the rendering model:

- Fill, inner corner, border, and outer corner cover the empty/full, single, triple, and adjacent-pair cases.
- The two disconnected diagonal states are not assigned to a fake border tile.
- Instead, each diagonal state is drawn as two transformed outer-corner tiles at the same display coordinate, one on the primary visual layer and one on an overlay visual layer.

This is not a fifth tile. It is composition. The cost is one extra internal layer and an extra draw for only masks `6` and `9`.

## Godot 4.6 Verification

Official Godot 4.6 docs define `TileMapLayer._update_cells(coords: Array[Vector2i], forced_cleanup: bool)` as a virtual method called when cells need internal updates, including individual cell modification and TileSet changes. The docs also state TileMapLayer updates are batched at frame end and can be forced with `update_internals()`.

The same docs warn that implementing `_update_cells` may degrade performance, so the override must stay lean: no persistent coordinate cache, no signal fanout, no terrain trie, and no writes back to the same `PentaTileMapLayer`.

Godot 4.6 also documents `TileSetAtlasSource.TRANSFORM_FLIP_H`, `TRANSFORM_FLIP_V`, and `TRANSFORM_TRANSPOSE` as alternative-tile flags usable directly with `TileMapLayer.set_cell()`. The docs give the exact flag combinations for 90, 180, and 270 degree rotations.

Sources:

- Godot 4.6 `TileMapLayer`: https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html
- Godot 4.6 `TileSetAtlasSource`: https://docs.godotengine.org/en/4.6/classes/class_tilesetatlassource.html
- Quarter-tile critique: https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/

Note: the YouTube timed-text endpoint for `aWcCNGen0cM` returned no transcript in this session, so the 5-tile claim was challenged against the video topic plus independent tiling references rather than quoted transcript text.

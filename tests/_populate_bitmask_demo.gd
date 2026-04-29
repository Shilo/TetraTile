## One-shot scene-population script. Builds a visual-inspection scene with two
## PentaTileMapLayer nodes — one painting all 16 corner-mask patterns against
## the BUNDLED Penta greybox (FIVE-HORIZONTAL, 32×32), the other painting the
## same 16 patterns against the user's `penta_tile_ground.tres` (16×16). Saves
## the scene so the user can open it in the editor and visually compare.
##
## Each layer paints a 4×4 grid of mini-blocks. Block (col, row) tests mask
## value = col + row*4. Within each block, the 2×2 logic-cell region at
## (origin.x, origin.y)..(origin.x+1, origin.y+1) is painted SELECTIVELY per
## the mask bits:
##
##   bit 1 (TL of target display cell): paint (origin.x,     origin.y)
##   bit 2 (TR):                        paint (origin.x + 1, origin.y)
##   bit 4 (BL):                        paint (origin.x,     origin.y + 1)
##   bit 8 (BR):                        paint (origin.x + 1, origin.y + 1)
##
## The target display cell — where the requested mask materializes — is at
## (origin.x + 1, origin.y + 1). Surrounding display cells naturally form
## the perimeter outline you'd see in any painted region (single-bit-mask
## extensions for dual-grid Penta — these render Penta's slot 0 with rotation
## per the locked dispatch table).
##
## Block spacing is 5 cells (2 painted + 3 buffer) so adjacent blocks don't
## share any affected display cells. The 4×4 grid spans 20×20 logic cells.
##
## Run from project root:
##   "C:/Programming_Files/Godot/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" \
##     --headless --path . --script addons/penta_tile/tests/_populate_bitmask_demo.gd
extends SceneTree

const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript     = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DEMO_PATH       := "res://addons/penta_tile/demo/penta_tile_demo.tscn"
const _GROUND_TRES     := "res://addons/penta_tile/demo/penta_tile_ground.tres"
const _BLOCK_SPACING   := 5  # cells per block (2 painted + 3 buffer)


func _initialize() -> void:
	print("=== _populate_bitmask_demo ===")

	var packed := load(_DEMO_PATH) as PackedScene
	if packed == null:
		printerr("FAIL: could not load %s" % _DEMO_PATH)
		quit(1)
		return
	var root: Node2D = packed.instantiate()
	if root == null:
		printerr("FAIL: could not instantiate scene")
		quit(1)
		return

	# Strip any pre-existing PentaTileMapLayer children that the user deleted
	# but might still be lingering. We rebuild from scratch.
	var to_remove: Array = []
	for child in root.get_children():
		if child is _LayerScript or child.get_class() == "PentaTileMapLayer":
			to_remove.append(child)
	for n: Node in to_remove:
		root.remove_child(n)
		n.queue_free()

	# Layer A — bundled greybox (default fallback path). Uses five_horizontal.png
	# (160×32, tile_size=32). Penta FIVE-H so all 5 archetypes are authored.
	var layer_a = _LayerScript.new()
	layer_a.name = "BitmaskDemo_BundledGreybox"
	layer_a.layout = _make_penta_five_h()
	# tile_set stays null → auto-fill via layout.get_fallback_tile_set() picks
	# up the bundled five_horizontal.png automatically.
	layer_a.position = Vector2.ZERO
	root.add_child(layer_a)
	layer_a.owner = root
	_paint_16_patterns(layer_a)
	await process_frame
	await process_frame
	if layer_a.has_method("rebuild"):
		layer_a.rebuild()
	await process_frame

	# Layer B — user's ground.tres (5 authored tiles, 16×16). Position offset
	# DOWN by 800 px so it doesn't overlap layer A in the editor view.
	var layer_b = _LayerScript.new()
	layer_b.name = "BitmaskDemo_GroundTres"
	layer_b.layout = _make_penta_five_h()
	layer_b.tile_set = load(_GROUND_TRES)
	layer_b.position = Vector2(0, 800)
	root.add_child(layer_b)
	layer_b.owner = root
	_paint_16_patterns(layer_b)
	await process_frame
	await process_frame
	if layer_b.has_method("rebuild"):
		layer_b.rebuild()
	await process_frame

	# Pack and save.
	var ps := PackedScene.new()
	var pack_err := ps.pack(root)
	if pack_err != OK:
		printerr("FAIL: pack returned error %d" % pack_err)
		quit(1)
		return
	var save_err := ResourceSaver.save(ps, _DEMO_PATH)
	if save_err != OK:
		printerr("FAIL: ResourceSaver.save returned error %d" % save_err)
		quit(1)
		return

	print("  Layer A (bundled greybox, 32x32): painted=%d display cells" % layer_a.get("_primary_layer").get_used_cells().size())
	print("  Layer B (ground.tres, 16x16):     painted=%d display cells" % layer_b.get("_primary_layer").get_used_cells().size())
	print("  Saved scene: %s" % _DEMO_PATH)
	print("  ALL DONE — open the demo scene in Godot to visually inspect the 16 mask patterns per layer")
	quit(0)


func _make_penta_five_h():
	var l = _PentaScript.new()
	l.set("axis", 0)            # HORIZONTAL
	l.set("tile_count", 5)      # FIVE — all 5 archetypes authored
	return l


# Paints a 4x4 grid of mini-blocks. Block (col, row) targets mask = col + row*4.
# Within each block, paint the subset of the 2x2 logic-cell region whose bits
# are set in the mask. The target display cell (where the requested mask
# materializes) is at (block.x + 1, block.y + 1) per the dual-grid corner rule.
func _paint_16_patterns(layer) -> void:
	for mask in range(16):
		var col: int = mask % 4
		var row: int = mask / 4
		var origin := Vector2i(col * _BLOCK_SPACING, row * _BLOCK_SPACING)
		# bit 1 = TL of the target display cell (at block.x+1, block.y+1)
		if mask & 1:
			layer.set_cell(origin + Vector2i(0, 0), 0, Vector2i.ZERO)
		# bit 2 = TR
		if mask & 2:
			layer.set_cell(origin + Vector2i(1, 0), 0, Vector2i.ZERO)
		# bit 4 = BL
		if mask & 4:
			layer.set_cell(origin + Vector2i(0, 1), 0, Vector2i.ZERO)
		# bit 8 = BR
		if mask & 8:
			layer.set_cell(origin + Vector2i(1, 1), 0, Vector2i.ZERO)

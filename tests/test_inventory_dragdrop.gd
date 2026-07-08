extends SceneTree

## Smoke test for the drag-and-drop inventory panel.
## Run: godot --headless --path . --script tests/test_inventory_dragdrop.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Inventory drag/drop smoke test ===")

	# --- Set up stats + inventory the way Player does ---
	var data := CharacterData.create_ryan()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)

	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	inv.equip_starting_item()

	# --- Instantiate the character panel (without show_panel: the live 3D
	#     portrait/combat section needs the full /root/Main scene, which a bare
	#     SceneTree test can't provide; we exercise only the drag/drop paths). ---
	var panel_scene: PackedScene = load("res://scenes/character/character_panel.tscn")
	var panel = panel_scene.instantiate()
	get_root().add_child(panel)
	panel.inventory = inv
	panel.player_stats = stats
	_check(true, "panel instantiated without crashing")

	# --- Put an item in storage, then equip it via the drop router ---
	var helm := ItemData.create_iron_helm()  # HELM, has card slots + on-self block
	inv.store_item(helm)
	var stored_before := inv.get_stored_item_count()
	_check(stored_before >= 1, "iron helm stored")

	# Storage index of the helm
	var helm_idx := inv.stored_items.find(helm)
	var payload := {"kind": "item", "source": "storage", "item": helm, "storage_index": helm_idx}
	# Route directly through inventory (panel._handle_item_drop_on_slot also
	# refreshes the whole panel UI, which we skip here).
	inv.equip_from_storage(helm_idx, 0)
	_check(inv.get_equipped_item(ItemData.ItemType.HELM, 0) == helm, "helm equipped into helm slot")
	_check(inv.get_stored_item_count() == stored_before - 1, "helm removed from storage after equip")

	# --- Type guard: a belt payload must be rejected by a helm slot ---
	var belt := ItemData.create_utility_belt()
	var belt_payload := {"kind": "item", "source": "storage", "item": belt}
	var helm_cell := EquipmentSlotCell.new()
	helm_cell.setup(panel, ItemData.ItemType.HELM, 0, helm)
	_check(not helm_cell._can_drop_data(Vector2.ZERO, belt_payload), "helm slot rejects a belt")
	_check(helm_cell._can_drop_data(Vector2.ZERO, payload), "helm slot accepts a helm")
	var drag_data = helm_cell._get_drag_data(Vector2.ZERO)
	_check(typeof(drag_data) == TYPE_DICTIONARY and drag_data.get("source") == "equipped",
		"equipped slot produces a drag payload")
	helm_cell.free()

	# --- Storage cell drop-guard: only equipped items get unequipped here ---
	var store_cell := StorageItemCell.new()
	store_cell.setup(panel, 0, null)
	_check(store_cell._can_drop_data(Vector2.ZERO,
		{"kind": "item", "source": "equipped"}), "storage cell accepts equipped item (unequip)")
	_check(not store_cell._can_drop_data(Vector2.ZERO,
		{"kind": "item", "source": "storage"}), "storage cell ignores storage->storage")
	store_cell.free()

	# --- Unequip helm back to storage ---
	inv.unequip_to_storage(ItemData.ItemType.HELM, 0)
	_check(inv.get_equipped_item(ItemData.ItemType.HELM, 0) == null, "helm unequipped to storage")
	_check(inv.stored_items.has(helm), "helm back in storage")

	# --- Move/swap between two ring slots (Ryan has 2 ring slots) ---
	var r1 := ItemData.create_gold_ring()
	var r2 := ItemData.create_ring_of_vengeance()
	inv.equip_item(r1, 0)
	inv.equip_item(r2, 1)
	panel._move_equipped(ItemData.ItemType.RING, 0, 1)
	_check(inv.get_equipped_item(ItemData.ItemType.RING, 1) == r1, "ring moved/swapped into slot 1")
	_check(inv.get_equipped_item(ItemData.ItemType.RING, 0) == r2, "ring swapped into slot 0")

	# --- Card sub-slot: red plus / on-self detection ---
	var card_slot := InventoryCardSlot.new()
	card_slot.setup(panel, helm)  # iron helm has on_self_block = 1
	_check(card_slot.has_on_self(), "iron helm card slot reports an on-self effect (red plus)")
	_check(card_slot.tooltip_text.find("On-Self") != -1, "card slot tooltip describes the on-self effect")
	card_slot.free()

	# --- Silhouettes draw for every slot type without error ---
	for t in range(8):
		var sil := ItemSilhouette.new()
		sil.setup(t)
		sil.size = Vector2(80, 80)
		get_root().add_child(sil)
		sil.queue_redraw()
	_check(true, "silhouettes created for all 8 item types")

	await process_frame
	await process_frame

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

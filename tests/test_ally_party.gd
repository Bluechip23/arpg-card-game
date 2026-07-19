extends SceneTree

## Smoke test for the co-op party features:
##   * character panel pages between party members (arrows + rebind)
##   * the panel's level/XP progress row tracks the viewed character
##   * the trade window moves stored items, equipped items, and gold between
##     two characters' inventories, and respects the storage-full guard
## Run: godot --headless --path . --script tests/test_ally_party.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

## Minimal stand-in for Player: just the accessors the panel/trade UI use.
class FakePlayer extends Node:
	var stats: PlayerStats = null
	var inv: Inventory = null
	func get_stats() -> PlayerStats: return stats
	func get_inventory() -> Inventory: return inv
	func get_buff_manager(): return null
	func get_debuff_manager(): return null

func _make_fake(data: CharacterData) -> FakePlayer:
	var fp := FakePlayer.new()
	fp.stats = PlayerStats.new()
	get_root().add_child(fp.stats)
	fp.stats.initialize(data)
	fp.inv = Inventory.new()
	get_root().add_child(fp.inv)
	fp.inv.initialize(data.character_name)
	fp.inv.connect_player_stats(fp.stats)
	get_root().add_child(fp)
	return fp

func _initialize() -> void:
	print("=== Ally party (paging + trade) smoke test ===")

	var p1 := _make_fake(CharacterData.create_ryan())
	var p2 := _make_fake(CharacterData.create_jeremy())
	var party: Array = [p1, p2]

	# --- Character panel: ally paging ---
	var panel_scene: PackedScene = load("res://scenes/character/character_panel.tscn")
	var panel = panel_scene.instantiate()
	get_root().add_child(panel)
	await process_frame
	panel.set_page_provider(func(): return party)
	panel.connect_stats(p1.stats, p1.inv)
	panel.show_panel()
	_check(panel._ally_nav != null and panel._ally_nav.visible, "nav arrows visible with a partner in play")
	_check(panel._nav_label.text == "Party 1 / 2", "nav label reads Party 1 / 2")
	_check(panel.name_label.text == "Ryan", "panel starts on Ryan")

	panel._page_ally(1)
	_check(panel.player_stats == p2.stats, "paging forward rebinds stats to the ally")
	_check(panel.inventory == p2.inv, "paging forward rebinds the inventory too")
	_check(panel.name_label.text == "Jeremy", "panel now shows Jeremy")
	_check(panel._nav_label.text == "Party 2 / 2", "nav label reads Party 2 / 2")

	panel._page_ally(1)
	_check(panel.player_stats == p1.stats, "paging wraps back to Ryan")

	# Re-paging twice must not stack duplicate signal connections: a single
	# xp_changed should refresh the panel exactly once (no errors) and the
	# level row should track the viewed character.
	panel._page_ally(1)  # -> Jeremy
	p2.stats.gain_xp(4)
	panel.update_display()
	_check(panel._level_label.text == "Lv 1", "level row shows Jeremy's level")
	_check(int(panel._xp_bar.value) == 4, "XP bar tracks Jeremy's 4 XP")
	_check(panel._xp_bar_text.text == "4 / 10 XP", "XP text reads 4 / 10 XP")

	p2.stats.gain_xp(6)  # 10/10 -> level 2
	panel.update_display()
	_check(p2.stats.current_level == 2, "Jeremy leveled up from shared XP")
	_check(panel._level_label.text == "Lv 2", "level row follows the level up")

	# Single-player: only one page -> arrows hidden.
	var solo: Array = [p1]
	panel.set_page_provider(func(): return solo)
	panel.view_player(p1)
	_check(not panel._ally_nav.visible, "nav arrows hidden without a partner")
	panel.hide_panel()

	# --- Trade window ---
	var trade = load("res://scripts/ui/trade_ui.gd").new()
	get_root().add_child(trade)
	await process_frame

	p1.stats.gain_gold(50)
	var helm := ItemData.create_iron_helm()
	p1.inv.store_item(helm)
	var sword := ItemData.new()
	sword.item_name = "Trade Sword"
	sword.item_type = ItemData.ItemType.WEAPON
	sword.weapon_subtype = ItemData.WeaponSubtype.SWORD
	sword.weight = 5
	_check(p1.inv.equip_item(sword, 0), "sword equips on Ryan")

	trade.open_trade(p1, p2)
	_check(trade.visible, "trade window opens")
	_check(trade._title_label.text.contains("Ryan") and trade._title_label.text.contains("Jeremy"),
		"title names both partners")

	# Stored item crosses over.
	var idx := p1.inv.stored_items.find(helm)
	trade._on_give_stored(0, idx)
	_check(not p1.inv.stored_items.has(helm), "helm left Ryan's storage")
	_check(p2.inv.stored_items.has(helm), "helm arrived in Jeremy's storage")

	# Equipped item is unequipped and crosses over.
	trade._on_give_equipped(0, ItemData.ItemType.WEAPON, 0)
	_check(p1.inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == null, "sword left Ryan's hand")
	_check(p2.inv.stored_items.has(sword), "sword arrived in Jeremy's storage")

	# Gold both fixed and all-in.
	trade._on_give_gold(0, 10)
	_check(p1.stats.gold == 40 and p2.stats.gold == 10, "10 gold crossed over")
	trade._on_give_gold(0, -1)
	_check(p1.stats.gold == 0 and p2.stats.gold == 50, "Give All empties Ryan's purse")
	trade._on_give_gold(0, 10)
	_check(p1.stats.gold == 0 and p2.stats.gold == 50, "giving with no gold is refused")

	# Storage-full guard: receiver at capacity keeps the giver's item in place.
	while not p2.inv.is_storage_full():
		p2.inv.store_item(ItemData.create_iron_helm())
	var keeper := ItemData.create_iron_helm()
	p1.inv.store_item(keeper)
	trade._on_give_stored(0, p1.inv.stored_items.find(keeper))
	_check(p1.inv.stored_items.has(keeper), "storage-full guard keeps the item with the giver")

	trade.close()
	_check(not trade.visible, "trade window closes")

	print("=== Done: %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

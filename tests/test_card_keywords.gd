extends SceneTree

## Card keywords (Card.keywords, from the design sheet's Type column) must
## agree with the gameplay fields they describe: type, school, melee/ranged,
## AoE, offensive, and targeting. Catches a card whose keywords say one
## thing while its factory wires another.
## Run: godot --headless --path . --script tests/test_card_keywords.gd

const VOCABULARY := ["attack", "defense", "utility", "power", "reaction", "enchantment", "unplayable",
	"spell", "offensive", "melee", "ranged", "aoe", "self", "ally", "allies", "enemy", "point", "no_target"]
const TYPE_NAMES := ["attack", "defense", "utility", "reaction", "unplayable", "power", "enchantment"]

var failures := 0
var checked := 0

func _fail(msg: String) -> void:
	failures += 1
	printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Card keyword consistency test ===")
	var script: Script = Card
	var seen: Dictionary = {}
	for method in script.get_script_method_list():
		var n: String = method["name"]
		if not n.begins_with("create_"):
			continue
		if method["args"].size() != 0:
			continue  # rank-scaled generated cards are built explicitly below
		if seen.has(n):
			continue
		seen[n] = true
		var card = script.call(n)
		if card is Card and not card.keywords.is_empty():
			_check_card(card)

	# Rank-scaled generated cards take a parameter, so build them by hand.
	for card in [Card.create_basic_attack(5), Card.create_energy_barrier(), Card.create_magic_barrier(),
			Card.create_mana_surge(), Card.create_shepherds_mark()]:
		if not card.keywords.is_empty():
			_check_card(card)

	# has_keyword is the lookup items/passives use.
	var slash := Card.create_slash()
	if not (slash.has_keyword("melee") and slash.has_keyword("attack") and not slash.has_keyword("ranged")):
		_fail("has_keyword: Slash should be attack+melee, not ranged")

	print("  checked %d keyworded cards" % checked)
	if checked < 150:
		_fail("expected the sheet's ~154 cards to carry keywords, found %d" % checked)
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _check_card(card: Card) -> void:
	checked += 1
	var id: String = card.card_id
	var kw: Array = card.keywords
	for k in kw:
		if k not in VOCABULARY:
			_fail("%s: unknown keyword '%s'" % [id, k])
	if kw.size() != _unique(kw).size():
		_fail("%s: duplicate keywords %s" % [id, kw])

	# First type keyword names the card's CardType (secondary roles like
	# Parry's "attack" or Vengeful Shield's "defense" may follow).
	var type_kws: Array = []
	for k in kw:
		if k in TYPE_NAMES:
			type_kws.append(k)
	if not type_kws.is_empty() and type_kws[0] != TYPE_NAMES[card.card_type]:
		_fail("%s: keywords say %s but card_type is %s" % [id, type_kws[0], TYPE_NAMES[card.card_type]])

	if ("spell" in kw) != (card.school == Card.CardSchool.SPELL):
		_fail("%s: 'spell' keyword (%s) disagrees with school (%d)" % [id, "spell" in kw, card.school])
	if "melee" in kw and "ranged" in kw:
		_fail("%s: both melee and ranged" % id)
	if "melee" in kw and card.is_ranged:
		_fail("%s: keyword melee but is_ranged" % id)
	if "ranged" in kw and not card.is_ranged:
		_fail("%s: keyword ranged but melee" % id)
	if "aoe" in kw and not card.is_aoe:
		_fail("%s: keyword aoe but not is_aoe" % id)
	if "offensive" in kw and not card.is_offensive():
		_fail("%s: keyword offensive but is_offensive() is false" % id)
	for t in ["self", "ally", "enemy", "point"]:
		if t in kw and t not in card.target_types:
			_fail("%s: keyword %s missing from target_types %s" % [id, t, card.target_types])
	if "allies" in kw and "ally" not in card.target_types:
		_fail("%s: keyword allies but target_types %s has no ally" % [id, card.target_types])
	if "no_target" in kw:
		for t in card.target_types:
			if t != "self" and t != "all_nearby":
				_fail("%s: keyword no_target but targets %s" % [id, card.target_types])

func _unique(a: Array) -> Array:
	var out := []
	for x in a:
		if x not in out:
			out.append(x)
	return out

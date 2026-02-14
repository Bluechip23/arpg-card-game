class_name ManifestUI
extends PanelContainer

## UI for displaying and activating manifest cards

signal manifest_card_clicked(index: int)

@onready var title_label: Label = $VBox/TitleLabel
@onready var cards_container: HBoxContainer = $VBox/CardsContainer
@onready var count_label: Label = $VBox/CountLabel

const ManifestCardUIScene = preload("res://scenes/manifest_card_ui.tscn")

var overflow_manager: OverflowManager
var _ready_complete: bool = false

func _ready() -> void:
	_ready_complete = true
	_refresh_display()

func connect_overflow_manager(om: OverflowManager) -> void:
	overflow_manager = om
	overflow_manager.overflow_effects_changed.connect(_on_overflow_changed)
	overflow_manager.manifest_card_added.connect(_on_manifest_added)
	
	if _ready_complete:
		_refresh_display()

func _on_overflow_changed() -> void:
	_refresh_display()

func _on_manifest_added(manifest_name: String, card: Card) -> void:
	_refresh_display()

func _refresh_display() -> void:
	if not _ready_complete:
		return
	
	if not cards_container:
		return
	
	# Clear existing cards
	for child in cards_container.get_children():
		child.queue_free()
	
	if not overflow_manager:
		visible = false
		return
	
	var manifest_cards = overflow_manager.get_manifest_zone()
	
	if manifest_cards.size() == 0:
		visible = false
		return
	
	visible = true
	
	if count_label:
		count_label.text = "Manifest: %d" % manifest_cards.size()
	
	# Create card buttons
	for i in range(manifest_cards.size()):
		var entry = manifest_cards[i]
		var card_ui = ManifestCardUIScene.instantiate() as ManifestCardUI
		cards_container.add_child(card_ui)
		card_ui.setup_from_entry(entry, i)
		card_ui.clicked.connect(_on_card_clicked)

func _on_card_clicked(index: int) -> void:
	manifest_card_clicked.emit(index)

func refresh() -> void:
	_refresh_display()

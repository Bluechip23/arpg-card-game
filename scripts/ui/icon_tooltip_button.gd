class_name IconTooltipButton
extends Button

## A button whose hover tooltip shows `tooltip_icon` large beside its
## tooltip_text (IconTooltip): the skill tree's passive nodes.

var tooltip_icon: Texture2D = null
var tooltip_accent: Color = EmeraldTheme.GOLD_DIM

func _make_custom_tooltip(for_text: String) -> Object:
	if tooltip_icon == null:
		return null
	return IconTooltip.make(tooltip_icon, for_text, tooltip_accent)

class_name MenuInterfaceApplier
extends RefCounted

## Applies GameSettings interface scale to menu Control trees.
## Builders stamp `menu_font_tier` meta; apply walks types + meta only (no node identity checks).

const TIER_MENU_TITLE := &"menu_title"
const TIER_MENU_BACK := &"menu_back"
const TIER_PANEL_TITLE := &"panel_title"
const TIER_SECTION := &"section"
const TIER_BODY := &"body"
const TIER_HINT := &"hint"
const TIER_VALUE := &"value"

const REF_MENU_TITLE := 48
const REF_MENU_BACK := 32
const REF_PANEL_TITLE := 22
const REF_SECTION := 16

const ROW_SEPARATION_REF := 10
const SLIDER_HEIGHT_REF := 22
const BUTTON_MIN_HEIGHT_REF := 40
const BUTTON_MIN_WIDTH_REF := 120
const PANEL_MIN_WIDTH_REF := 420

const META_FONT_TIER := &"menu_font_tier"
const META_MARGIN_REF := &"menu_margin_ref"
const META_PANEL_WIDTH_REF := &"menu_panel_width_ref"

const MARGIN_REF_LEFT := 48
const MARGIN_REF_TOP := 120
const MARGIN_REF_RIGHT := 48
const MARGIN_REF_BOTTOM := 48


static func stamp_font_tier(node: Node, tier: StringName) -> void:
	if node != null:
		node.set_meta(META_FONT_TIER, tier)


static func stamp_content_margin(margin: MarginContainer) -> void:
	if margin != null:
		margin.set_meta(META_MARGIN_REF, true)


static func stamp_panel_width(panel: PanelContainer) -> void:
	if panel != null:
		panel.set_meta(META_PANEL_WIDTH_REF, true)


static func apply(root: Node, settings: GameSettings) -> void:
	if root == null or settings == null:
		return
	var body_sz: int = settings.scaled_body_font()
	var hint_sz: int = settings.scaled_hint_font()
	var ui_scale: float = settings.combat_ui_scale
	var text_scale: float = settings.combat_text_scale
	_apply_recursive(root, body_sz, hint_sz, ui_scale, text_scale)


static func _scaled_ref(ref_px: int, text_scale: float) -> int:
	return int(round(float(ref_px) * text_scale))


static func _scaled_layout(ref_px: int, ui_scale: float) -> int:
	return int(round(float(ref_px) * ui_scale))


static func _font_size_for_tier(tier: StringName, body_sz: int, hint_sz: int, text_scale: float) -> int:
	match tier:
		TIER_MENU_TITLE:
			return _scaled_ref(REF_MENU_TITLE, text_scale)
		TIER_MENU_BACK:
			return _scaled_ref(REF_MENU_BACK, text_scale)
		TIER_PANEL_TITLE:
			return _scaled_ref(REF_PANEL_TITLE, text_scale)
		TIER_SECTION:
			return _scaled_ref(REF_SECTION, text_scale)
		TIER_HINT:
			return hint_sz
		TIER_VALUE, TIER_BODY:
			return body_sz
		_:
			return body_sz


static func _apply_recursive(
	node: Node,
	body_sz: int,
	hint_sz: int,
	ui_scale: float,
	text_scale: float,
) -> void:
	if node is MarginContainer and node.get_meta(META_MARGIN_REF, false):
		var margin: MarginContainer = node as MarginContainer
		margin.add_theme_constant_override("margin_left", int(round(float(MARGIN_REF_LEFT) * ui_scale)))
		margin.add_theme_constant_override("margin_top", int(round(float(MARGIN_REF_TOP) * ui_scale)))
		margin.add_theme_constant_override("margin_right", int(round(float(MARGIN_REF_RIGHT) * ui_scale)))
		margin.add_theme_constant_override("margin_bottom", int(round(float(MARGIN_REF_BOTTOM) * ui_scale)))
	elif node is PanelContainer and node.get_meta(META_PANEL_WIDTH_REF, false):
		var panel: PanelContainer = node as PanelContainer
		panel.custom_minimum_size.x = float(_scaled_layout(PANEL_MIN_WIDTH_REF, ui_scale))
	elif node is TabContainer:
		(node as TabContainer).add_theme_font_size_override("font_size", body_sz)
	elif node is Label:
		var lbl: Label = node as Label
		var tier: StringName = lbl.get_meta(META_FONT_TIER, TIER_BODY)
		lbl.add_theme_font_size_override(
			"font_size",
			_font_size_for_tier(tier, body_sz, hint_sz, text_scale),
		)
	elif node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_size_override("normal_font_size", body_sz)
	elif node is Button:
		var btn: Button = node as Button
		btn.add_theme_font_size_override("font_size", body_sz)
		btn.custom_minimum_size = Vector2(
			float(_scaled_layout(BUTTON_MIN_WIDTH_REF, ui_scale)),
			float(_scaled_layout(BUTTON_MIN_HEIGHT_REF, ui_scale)),
		)
	elif node is CheckButton:
		(node as CheckButton).add_theme_font_size_override("font_size", body_sz)
	elif node is OptionButton:
		(node as OptionButton).add_theme_font_size_override("font_size", body_sz)
	elif node is HSlider:
		(node as HSlider).custom_minimum_size.y = float(_scaled_layout(SLIDER_HEIGHT_REF, ui_scale))
	elif node is VBoxContainer or node is HBoxContainer:
		(node as BoxContainer).add_theme_constant_override(
			"separation",
			int(round(float(ROW_SEPARATION_REF) * ui_scale)),
		)

	for child: Node in node.get_children():
		_apply_recursive(child, body_sz, hint_sz, ui_scale, text_scale)

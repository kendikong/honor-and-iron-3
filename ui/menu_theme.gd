class_name MenuTheme
extends RefCounted

## Shared colors + panel style for main menu, pause, and settings overlays.

const BG := Color(0.09, 0.11, 0.14, 1.0)
const BG_DIM := Color(0.06, 0.08, 0.11, 0.88)
const PANEL := Color(0.13, 0.16, 0.21, 0.96)
const PANEL_BORDER := Color(0.30, 0.38, 0.48, 1.0)
const TEXT := Color(0.93, 0.95, 0.98, 1.0)
const TEXT_MUTED := Color(0.62, 0.68, 0.76, 1.0)
const TEXT_SECTION := Color(0.78, 0.84, 0.94, 1.0)
const ACCENT := Color(0.48, 0.66, 0.92, 1.0)
const DANGER := Color(0.88, 0.42, 0.42, 1.0)


static func apply_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _panel_style())


static func apply_popup(popup: PopupPanel) -> void:
	popup.add_theme_stylebox_override("panel", _panel_style())


static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func style_title(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT)
	MenuInterfaceApplier.stamp_font_tier(label, MenuInterfaceApplier.TIER_MENU_TITLE)


static func style_menu_button(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT)
	button.custom_minimum_size.y = 44.0


static func style_muted_label(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_MUTED)
	MenuInterfaceApplier.stamp_font_tier(label, MenuInterfaceApplier.TIER_HINT)


static func style_section_label(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_SECTION)
	MenuInterfaceApplier.stamp_font_tier(label, MenuInterfaceApplier.TIER_SECTION)

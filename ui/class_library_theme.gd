class_name ClassLibraryTheme
extends RefCounted

## Visual design tokens for the Class Library Editor.
## Call `set_user_scale()` for toolbar +/- ; use `font()` / `px()` for all sizes.

enum Column {
	NEUTRAL,
	INGAME,
	DATA,
	IMPL,
	STATS,
	PASSIVE,
	GLOSSARY_GAME,
	GLOSSARY_SYS,
	SIDEBAR,
}

const BG_BASE := Color("181b20")
const BG_SIDEBAR := Color("1f242c")
const BG_CARD := Color("272d38")
const BG_INSET := Color("1a1f27")
const BG_TOOLBAR := Color("222831")

const TEXT_PRIMARY := Color("e8ecf1")
const TEXT_SECONDARY := Color("b8c2ce")
const TEXT_MUTED := Color("8a97a8")
const TEXT_DIM := Color("5f6b7a")

const ACCENT_INGAME := Color("f0b429")
const ACCENT_DATA := Color("5b9cf5")
const ACCENT_IMPL := Color("5ecfaa")
const ACCENT_STATS := Color("b892f5")
const ACCENT_PASSIVE := Color("7dce82")
const ACCENT_NEUTRAL := Color("6b7785")
const ACCENT_DANGER := Color("e86a6a")
const ACCENT_SUCCESS := Color("6bcf8a")
const ACCENT_OVERRIDE_SAVED := Color("e8b84a")
const ACCENT_OVERRIDE_UNSAVED := Color("ff8c5a")

const BORDER_SUBTLE := Color("3a424f")

## Base font tiers (multiply by user scale).
const FONT_HERO := 34
const FONT_TITLE := 26
const FONT_SECTION := 20
const FONT_SUBSECTION := 14
const FONT_BODY := 13
const FONT_SMALL := 11
const FONT_MONO := 11

const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 24

const SIDEBAR_WIDTH_BASE := 260
const LABEL_COL_WIDTH_BASE := 132

const MIN_USER_SCALE := 0.75
const MAX_USER_SCALE := 2.0
const USER_SCALE_STEP := 0.1

static var _user_scale: float = 1.0


static func set_user_scale(value: float) -> void:
	_user_scale = clampf(snappedf(value, USER_SCALE_STEP), MIN_USER_SCALE, MAX_USER_SCALE)


static func user_scale() -> float:
	return _user_scale


static func px(base: int) -> int:
	return maxi(1, int(round(float(base) * _user_scale)))


static func dim(base: float) -> float:
	return maxf(1.0, base * _user_scale)


static func font(base: int) -> int:
	return maxi(8, int(round(float(base) * _user_scale)))


static func sidebar_width() -> int:
	return px(SIDEBAR_WIDTH_BASE)


static func label_col_width() -> int:
	return px(LABEL_COL_WIDTH_BASE)


static func panel_style(
	bg: Color,
	border: Color = BORDER_SUBTLE,
	border_width: int = 1,
	radius: int = 6,
	margin: int = -1,
) -> StyleBoxFlat:
	var m: int = px(margin) if margin >= 0 else px(SPACE_MD)
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(maxi(1, int(round(float(border_width) * _user_scale))))
	s.set_corner_radius_all(px(radius))
	s.content_margin_left = m
	s.content_margin_right = m
	s.content_margin_top = m
	s.content_margin_bottom = m
	return s


static func column_style(col: Column) -> StyleBoxFlat:
	match col:
		Column.INGAME:
			return panel_style(BG_INSET, ACCENT_INGAME, 2)
		Column.DATA:
			return panel_style(BG_CARD, ACCENT_DATA, 2)
		Column.IMPL:
			return panel_style(BG_INSET, ACCENT_IMPL, 2)
		Column.STATS:
			return panel_style(BG_CARD, ACCENT_STATS, 2)
		Column.PASSIVE:
			return panel_style(BG_CARD, ACCENT_PASSIVE, 2)
		Column.GLOSSARY_GAME:
			return panel_style(BG_INSET, ACCENT_INGAME, 1, 4, SPACE_SM)
		Column.GLOSSARY_SYS:
			return panel_style(BG_INSET, ACCENT_IMPL, 1, 4, SPACE_SM)
		_:
			return panel_style(BG_CARD, BORDER_SUBTLE, 1)


static func accent_for_column(col: Column) -> Color:
	match col:
		Column.INGAME, Column.GLOSSARY_GAME:
			return ACCENT_INGAME
		Column.DATA:
			return ACCENT_DATA
		Column.IMPL, Column.GLOSSARY_SYS:
			return ACCENT_IMPL
		Column.STATS:
			return ACCENT_STATS
		Column.PASSIVE:
			return ACCENT_PASSIVE
		_:
			return ACCENT_NEUTRAL


static func sidebar_button_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.content_margin_left = px(SPACE_MD)
	s.content_margin_right = px(SPACE_SM)
	s.content_margin_top = px(SPACE_SM)
	s.content_margin_bottom = px(SPACE_SM)
	return s


static func sidebar_button_active(accent: Color) -> StyleBoxFlat:
	var s := sidebar_button_normal()
	s.bg_color = BG_INSET
	s.border_color = accent
	s.border_width_left = maxi(2, px(3))
	return s


static func section_header_bar(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_INSET
	s.border_color = accent
	s.border_width_left = maxi(2, px(4))
	s.set_corner_radius_all(px(4))
	s.content_margin_left = px(SPACE_MD)
	s.content_margin_right = px(SPACE_SM)
	s.content_margin_top = px(SPACE_SM)
	s.content_margin_bottom = px(SPACE_SM)
	return s


static func toolbar_button_style() -> StyleBoxFlat:
	return panel_style(BG_CARD, BORDER_SUBTLE, 1, 4, SPACE_SM)


static func category_chip_style(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = accent.darkened(0.65)
	s.border_color = accent
	s.set_border_width_all(maxi(1, px(1)))
	s.set_corner_radius_all(px(10))
	s.content_margin_left = px(8)
	s.content_margin_right = px(8)
	s.content_margin_top = px(2)
	s.content_margin_bottom = px(2)
	return s

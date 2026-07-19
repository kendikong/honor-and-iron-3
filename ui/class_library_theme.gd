class_name ClassLibraryTheme
extends RefCounted

## Visual design tokens for the Class Library Editor.

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

const BORDER_SUBTLE := Color("3a424f")

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

const SIDEBAR_WIDTH := 260
const LABEL_COL_WIDTH := 148


static func panel_style(
	bg: Color,
	border: Color = BORDER_SUBTLE,
	border_width: int = 1,
	radius: int = 6,
	margin: int = SPACE_MD,
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
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
	s.content_margin_left = SPACE_MD
	s.content_margin_right = SPACE_SM
	s.content_margin_top = SPACE_SM
	s.content_margin_bottom = SPACE_SM
	return s


static func sidebar_button_active(accent: Color) -> StyleBoxFlat:
	var s := sidebar_button_normal()
	s.bg_color = BG_INSET
	s.border_color = accent
	s.border_width_left = 3
	return s


static func section_header_bar(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_INSET
	s.border_color = accent
	s.border_width_left = 4
	s.set_corner_radius_all(4)
	s.content_margin_left = SPACE_MD
	s.content_margin_right = SPACE_SM
	s.content_margin_top = SPACE_SM
	s.content_margin_bottom = SPACE_SM
	return s


static func toolbar_button_style() -> StyleBoxFlat:
	return panel_style(BG_CARD, BORDER_SUBTLE, 1, 4, SPACE_SM)


static func category_chip_style(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = accent.darkened(0.65)
	s.border_color = accent
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s

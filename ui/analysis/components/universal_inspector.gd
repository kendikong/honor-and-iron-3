class_name UniversalInspectorPanel
extends PanelContainer

var title_label: Label
var details_rich_text: RichTextLabel
var _meta: Dictionary = {}


func _init() -> void:
	MassSimTheme.apply_panel(self)
	custom_minimum_size = Vector2(320, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	title_label = Label.new()
	title_label.text = "Universal Inspector"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MassSimTheme.style_section(title_label)
	vbox.add_child(title_label)
	details_rich_text = RichTextLabel.new()
	details_rich_text.bbcode_enabled = true
	details_rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_rich_text.text = (
		"[color=#8fa3b8]Click any KPI, tier row, triage warning, or palette entry "
		+ "to inspect contextual stats here.[/color]\n\n"
		+ "[b]Three-Click Rule[/b]\n"
		+ "Warning → Inspector → Curated Replay ID (L5 tab)."
	)
	vbox.add_child(details_rich_text)


func update_context(title: String, bbcode_details: String, meta: Dictionary = {}) -> void:
	title_label.text = title
	details_rich_text.text = bbcode_details
	_meta = meta.duplicate(true)


func get_meta() -> Dictionary:
	return _meta

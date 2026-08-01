class_name LpcConstants
extends RefCounted

## LPC universal sheet layout (64×64 frames). Matches chargen.js row order.
## Sprites load from _lpc_sparse/ via Image.load — never under res:// (no Godot import).

const SPARSE_DIR: String = "_lpc_sparse"
const SPRITESHEETS_DIR: String = "spritesheets"
const CATALOG_PATH: String = "res://resources/character/lpc_catalog.json"

const LPC_CLASS_OVERRIDE_SLOTS: Array[String] = [
	"weapon", "shield", "armour", "clothes", "legs", "shoes", "hat", "cape", "quiver",
	"belt", "sash", "shoulders", "gloves", "wings", "tail", "horns", "backpack",
]

const LPC_PLAYER_CLASS_IDS: Array[String] = [
	"knight", "paladin", "bruiser", "cavalier", "archer", "mage", "cleric",
	"assassin", "mercenary", "gryphon", "monk", "engineer", "shaman",
]

const FRAME_SIZE: int = 64
const FRAMES_PER_ROW: int = 13

const BODY_TYPES: Array[String] = [
	"male", "female", "teen", "child", "muscular", "pregnant",
	"skeleton", "zombie",
]

const ANIM_ROW: Dictionary = {
	&"spellcast": 0,
	&"thrust": 4,
	&"walk": 8,
	&"slash": 12,
	&"shoot": 16,
	&"hurt": 20,
	&"idle": 22,
}

## Action configuration: [cycle_frames: Array[int], fps: float, directions: Array[StringName]]
const DIRS: Array[StringName] = [&"up", &"left", &"down", &"right"]

const ACTIONS: Dictionary = {
	"walk": [[1, 2, 3, 4, 5, 6, 7, 8], 8.0, DIRS],
	"idle": [[0, 0, 1], 4.0, DIRS],
	"run": [[0, 1, 2, 3, 4, 5, 6, 7], 10.0, DIRS],
	"slash": [[0, 1, 2, 3, 4, 5], 12.0, DIRS],
	"thrust": [[0, 1, 2, 3, 4, 5, 6, 7], 10.0, DIRS],
	"spellcast": [[0, 1, 2, 3, 4, 5, 6], 8.0, DIRS],
	"shoot": [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 12.0, DIRS],
	"hurt": [[0, 1, 2, 3, 4, 5], 6.0, [&"down"]],
	"climb": [[0, 1, 2, 3, 4, 5], 6.0, [&"up"]],
	"jump": [[0, 1, 2, 3, 4], 6.0, DIRS],
	"sit": [[0, 1, 2], 4.0, DIRS],
	"emote": [[0, 1, 2], 4.0, DIRS],
	"combat_idle": [[0, 1], 4.0, DIRS],
	"backslash": [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 12.0, DIRS],
	"halfslash": [[0, 1, 2, 3, 4, 5], 12.0, DIRS],
}

## Spellcast timing (frames [0..6] @ 8 fps — see ACTIONS["spellcast"]).
## Frame 3 = arms extended / release pose (SFX + target flash sync here).
## Frames 4–6 = arms down @ SPELLCAST_TAIL_SPEED_SCALE (half duration vs base fps).
const SPELLCAST_FPS: float = 8.0
const SPELLCAST_FRAME_COUNT: int = 7
const SPELLCAST_RELEASE_FRAME: int = 3
const SPELLCAST_RELEASE_SEC: float = float(SPELLCAST_RELEASE_FRAME) / SPELLCAST_FPS
const SPELLCAST_TAIL_FRAME_COUNT: int = SPELLCAST_FRAME_COUNT - SPELLCAST_RELEASE_FRAME - 1
const SPELLCAST_TAIL_SPEED_SCALE: float = 2.0
const SPELLCAST_TAIL_START_SEC: float = float(SPELLCAST_RELEASE_FRAME + 1) / SPELLCAST_FPS
const SPELLCAST_TAIL_SEC: float = (
	float(SPELLCAST_TAIL_FRAME_COUNT) / (SPELLCAST_FPS * SPELLCAST_TAIL_SPEED_SCALE)
)
const SPELLCAST_ANIM_SEC: float = SPELLCAST_TAIL_START_SEC + SPELLCAST_TAIL_SEC
const SPELLCAST_HOLD_SEC: float = 0.0
## Target white flash: bright hold from release until caster spellcast anim ends.

static func spellcast_release_delay_sec(_cast_anim: StringName = &"") -> float:
	return SPELLCAST_RELEASE_SEC


static func spellcast_tail_start_sec() -> float:
	return SPELLCAST_TAIL_START_SEC


static func spellcast_flash_hold_sec() -> float:
	return maxf(0.0, SPELLCAST_ANIM_SEC - SPELLCAST_RELEASE_SEC)


static func spellcast_playback_delay_sec() -> float:
	return SPELLCAST_ANIM_SEC + SPELLCAST_HOLD_SEC

static func get_base_action(anim_name: StringName) -> StringName:
	var s = str(anim_name)
	if s.begins_with("combat_idle_"):
		return &"combat_idle"
	return StringName(s.split("_")[0])

## Above Z_SKY (7) so cloud/mist overlays do not cover the preview actor.
const Z_CHARACTER: int = 8

static var _spritesheet_root: String = ""


static func spritesheet_root() -> String:
	if _spritesheet_root.is_empty():
		var base: String = ProjectSettings.globalize_path("res://")
		_spritesheet_root = base.path_join(SPARSE_DIR).path_join(SPRITESHEETS_DIR)
		if not _spritesheet_root.ends_with("/"):
			_spritesheet_root += "/"
	return _spritesheet_root


static func sheet_path(path_prefix: String, anim: String, _recolor: String, variant: String) -> String:
	var rel: String = path_prefix.trim_prefix("/")
	var base: String = spritesheet_root().path_join(rel).path_join(anim)
	
	# Variant items (tunic, hat, …) ship walk/{color}.png on disk.
	if variant != "":
		var variant_path: String = base.path_join(variant) + ".png"
		if FileAccess.file_exists(variant_path):
			return variant_path
			
		# Fallback for weapons: slash -> attack_slash
		var attack_base: String = spritesheet_root().path_join(rel).path_join("attack_" + anim)
		var attack_variant_path: String = attack_base.path_join(variant) + ".png"
		if FileAccess.file_exists(attack_variant_path):
			return attack_variant_path
			
	# Check non-variant base path
	var base_path: String = base + ".png"
	if FileAccess.file_exists(base_path):
		return base_path
		
	# Fallback non-variant for weapons
	var attack_base_path: String = spritesheet_root().path_join(rel).path_join("attack_" + anim) + ".png"
	if FileAccess.file_exists(attack_base_path):
		return attack_base_path
		
	# ULPC palette layers use a single walk.png; recolor is GPU-side (lpc_palette_recolor.gdshader).
	# Never probe walk/{skin|hair|cloth}.png — missing files spam Image.load errors.
	return base_path


static func spritesheets_available() -> bool:
	var probe: String = sheet_path("body/bodies/male/", "walk", "", "")
	return FileAccess.file_exists(probe)

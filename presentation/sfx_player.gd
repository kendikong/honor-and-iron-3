class_name SfxPlayer
extends Node

## Purpose: Audible feedback for actions so the player can tell inputs registered.
## Synthesises short placeholder tones at startup (no audio assets needed).
## Responsibilities: own a small pool of AudioStreamPlayers; auto-react to combat
##   SimEvents; expose play(key) for UI/interaction sounds.
## Dependencies: EventBus (sim_event), GameEnums. Presentation-only; never touches
##   simulation state.

const SAMPLE_RATE: int = 44100
const VOICES: int = 8

## kind: chime | tick | thud | impact | crunch | faint | whoosh | buzz | fanfare
const DEFS := {
	"select":  {"kind": &"chime",    "freq": 784.0,  "freq2": 988.0,  "dur": 0.07, "vol": 0.16},
	"move":    {"kind": &"tick",     "freq": 320.0,  "freq2": 0.0,    "dur": 0.05, "vol": 0.12},
	"ability": {"kind": &"chime",    "freq": 523.0,  "freq2": 740.0,  "dur": 0.10, "vol": 0.18},
	"invalid": {"kind": &"buzz",     "freq": 180.0,  "freq2": 140.0,  "dur": 0.12, "vol": 0.14},
	"cancel":  {"kind": &"tick",     "freq": 280.0,  "freq2": 220.0,  "dur": 0.08, "vol": 0.11},
	"execute": {"kind": &"chime",    "freq": 392.0,  "freq2": 587.0,  "dur": 0.16, "vol": 0.20},
	"step":    {"kind": &"tick",     "freq": 260.0,  "freq2": 0.0,    "dur": 0.04, "vol": 0.09},
	"hit":     {"kind": &"crunch",   "freq": 145.0,  "freq2": 52.0,   "dur": 0.17, "vol": 0.44},
	"push":    {"kind": &"whoosh",   "freq": 360.0,  "freq2": 220.0,  "dur": 0.09, "vol": 0.14},
	"thud":    {"kind": &"thud",     "freq": 95.0,   "freq2": 70.0,   "dur": 0.12, "vol": 0.24},
	"die":     {"kind": &"faint",    "freq": 420.0,  "freq2": 88.0,   "dur": 0.58, "vol": 0.30},
	"turn":    {"kind": &"tick",     "freq": 350.0,  "freq2": 0.0,    "dur": 0.08, "vol": 0.10},
	"win":     {"kind": &"fanfare",  "freq": 523.0,  "freq2": 784.0,  "dur": 0.38, "vol": 0.22},
	"lose":    {"kind": &"chime",    "freq": 330.0,  "freq2": 147.0,  "dur": 0.35, "vol": 0.16},
}

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()

var _director: CombatDirector


func bind_director(director: CombatDirector) -> void:
	_director = director


func _ready() -> void:
	_rng.randomize()
	for key in DEFS.keys():
		_streams[key] = _bake(DEFS[key])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)
	EventBus.sim_event.connect(_on_sim_event)

func play(key: String) -> void:
	if not _streams.has(key):
		return
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = _streams[key]
	voice.volume_db = _rng.randf_range(-1.5, 0.5)
	voice.pitch_scale = _rng.randf_range(0.97, 1.03)
	voice.play()

func _on_sim_event(event: SimEvent) -> void:
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED:
			var actor_id = event.data.get("actor", -1)
			var is_player = false
			if _director != null and _director.board != null:
				var unit = _director.board.get_unit_by_id(actor_id)
				if unit != null and not unit.is_enemy():
					is_player = true
			var is_enemy_turn = (_director != null and _director.phase == CombatDirector.Phase.ENEMY_TURN)
			if is_enemy_turn or not is_player:
				play("step")
		GameEnums.SimEventType.UNIT_PUSHED:
			play("push")
		GameEnums.SimEventType.ABILITY_USED:
			play("ability")
		GameEnums.SimEventType.COUNTER_ATTACK:
			play("ability")
		GameEnums.SimEventType.UNIT_FACED:
			play("move")
		GameEnums.SimEventType.UNIT_DAMAGED:
			var damage_taken: int = (
				int(event.data.get("hp_damaged", 0))
				+ int(event.data.get("armor_damaged", 0))
			)
			if damage_taken > 0:
				play("hit")
		GameEnums.SimEventType.COLLISION:
			play("thud")
		GameEnums.SimEventType.UNIT_DIED:
			play("die")
		GameEnums.SimEventType.TURN_ENDED:
			play("turn")
		_:
			pass

func _bake(def: Dictionary) -> AudioStreamWAV:
	var kind: StringName = def.get("kind", &"tick")
	var freq: float = def.get("freq", 440.0)
	var freq2: float = def.get("freq2", 0.0)
	if freq2 <= 0.0:
		freq2 = freq
	var dur: float = def.get("dur", 0.1)
	var vol: float = def.get("vol", 0.2)
	var count := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var phase2 := 0.0
	var noise_seed := _rng.randi()
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var env := _envelope(kind, t)
		var f: float = lerpf(freq, freq2, smoothstep(0.0, 1.0, t))
		phase += TAU * f / float(SAMPLE_RATE)
		phase2 += TAU * (f * 1.498) / float(SAMPLE_RATE)
		var sample := 0.0
		match kind:
			&"chime":
				sample = sin(phase) * 0.72 + sin(phase2) * 0.28 * (1.0 - t)
			&"tick":
				sample = sin(phase) * 0.85 + sin(phase * 2.0) * 0.08
			&"thud":
				var low := sin(phase * 0.5) * 0.65
				var click := _noise(noise_seed + i) * 0.35 * (1.0 - smoothstep(0.0, 0.12, t))
				sample = low + click
			&"impact":
				var body := sin(phase * 0.5) * 0.62
				var snap := _noise(noise_seed + i * 5) * 0.58 * (1.0 - smoothstep(0.0, 0.09, t))
				var crack := sin(phase * 3.2) * 0.24 * (1.0 - smoothstep(0.0, 0.18, t))
				sample = body + snap + crack
			&"crunch":
				var thump := sin(phase * 0.42) * 0.72
				var snap2 := _noise(noise_seed + i * 7) * 0.62 * (1.0 - smoothstep(0.0, 0.14, t))
				var bite := sin(phase * 2.6) * 0.18 * (1.0 - smoothstep(0.2, 0.55, t))
				sample = thump + snap2 + bite
			&"faint":
				var tone := sin(phase) * 0.42 * (1.0 - t * 0.35)
				var low := sin(phase * 0.35) * 0.55
				var wobble := sin(phase * 1.7 + t * 8.0) * 0.12 * (1.0 - t)
				sample = tone + low + wobble
			&"whoosh":
				var n := _noise(noise_seed + i * 3)
				sample = n * 0.55 + sin(phase) * 0.25
			&"buzz":
				sample = sin(phase) * 0.55 + sin(phase * 1.5) * 0.25
			&"fanfare":
				var third := phase + phase * 0.5
				sample = sin(phase) * 0.5 + sin(phase2) * 0.35 + sin(third) * 0.2
			_:
				sample = sin(phase)
		sample *= env * vol
		sample = tanh(sample * 1.4)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _envelope(kind: StringName, t: float) -> float:
	match kind:
		&"chime", &"fanfare":
			return exp(-4.5 * t) * (1.0 - smoothstep(0.0, 0.08, t) * 0.15 + 0.15)
		&"tick", &"whoosh":
			return exp(-7.0 * t)
		&"thud":
			return exp(-5.5 * t) * smoothstep(0.0, 0.02, t)
		&"impact":
			return exp(-8.5 * t)
		&"crunch":
			return exp(-5.0 * t) * smoothstep(0.0, 0.015, t)
		&"faint":
			return (1.0 - smoothstep(0.55, 1.0, t)) * exp(-2.2 * t)
		&"buzz":
			return (1.0 - smoothstep(0.35, 1.0, t)) * exp(-3.0 * t)
	return exp(-5.0 * t)

func _noise(seed: int) -> float:
	var n := sin(float(seed) * 12.9898) * 43758.5453
	return fmod(n, 1.0) * 2.0 - 1.0

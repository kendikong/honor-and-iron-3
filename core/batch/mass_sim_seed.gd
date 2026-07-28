class_name MassSimSeed
extends RefCounted

## Deterministic per-battle seeds for mass sim (thread-safe — no ticks in workers).


static func batch_seed(fingerprint: String = "") -> int:
	return int(hash(Vector3i(Time.get_ticks_msec(), randi(), fingerprint.hash())))


static func battle_seed(batch_seed: int, run_id: int) -> int:
	return int(hash(Vector4i(batch_seed, run_id, 0x4D534243, 119)))


static func unit_roll_seed(battle_seed: int, run_id: int, slot: int, class_id: StringName, team: int, salt: int) -> int:
	var mix: int = int(hash(Vector2i(battle_seed, run_id)))
	return int(hash(Vector4i(mix, slot, int(class_id.hash()), team + salt)))

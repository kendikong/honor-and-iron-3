class_name MassSimTelemetryAccumulator
extends RefCounted

const MAX_CELLS := 64


static func apply_events(telemetry: SimulationTelemetry, events: Array) -> void:
	for e: Variant in events:
		if not e is SimEvent:
			continue
		var event: SimEvent = e as SimEvent
		match event.type:
			GameEnums.SimEventType.COLLISION:
				telemetry.wall_collisions += 1
				_push_cell(telemetry.collision_cells, event.data.get("at", event.data.get("coord", Vector2i.ZERO)))
			GameEnums.SimEventType.UNIT_PUSHED:
				telemetry.chain_collisions += 1
				_push_cell(telemetry.collision_cells, event.data.get("to", Vector2i.ZERO))
			GameEnums.SimEventType.UNIT_DAMAGED:
				var amt: int = int(event.data.get("amount", 0))
				telemetry.assisted_damage += amt
				var over: int = int(event.data.get("overkill", 0))
				if over > 0:
					telemetry.overkill_damage += over
			GameEnums.SimEventType.UNIT_DIED:
				_push_cell(telemetry.death_cells, event.data.get("at", event.data.get("position", Vector2i.ZERO)))
			GameEnums.SimEventType.ACTION_FAILED:
				var reason: String = String(event.data.get("reason", ""))
				if reason.find("displaced") >= 0 or reason.find("whiff") >= 0:
					telemetry.execution_whiffs += 1
			GameEnums.SimEventType.MATH_TELEMETRY:
				var kind: String = String(event.data.get("kind", ""))
				if kind == "shield_prevented":
					telemetry.assisted_shields += int(event.data.get("amount", 0))
			GameEnums.SimEventType.TERRAIN_CHANGED:
				telemetry.hazard_landings += 1
			GameEnums.SimEventType.TRAMPLE_HIT:
				telemetry.chain_collisions += 1
			GameEnums.SimEventType.UNIT_MOVED:
				pass


static func _push_cell(store: Array, raw: Variant) -> void:
	if raw is Vector2i:
		var key: String = "%d,%d" % [raw.x, raw.y]
		if not store.has(key) and store.size() < MAX_CELLS:
			store.append(key)

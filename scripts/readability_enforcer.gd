class_name ReadabilityEnforcer
extends RefCounted

## High-attention cap — bible §4D (max 5 per screen).

const MAX_HIGH_ATTENTION: int = 5

var _active: int = 0


func try_acquire() -> bool:
	if _active >= MAX_HIGH_ATTENTION:
		return false
	_active += 1
	return true


func release() -> void:
	_active = maxi(0, _active - 1)


func active_count() -> int:
	return _active


func reset() -> void:
	_active = 0


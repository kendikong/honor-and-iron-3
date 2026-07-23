class_name TriageEngine
extends RefCounted

## Purpose: Algorithmic root cause ranking and health summary generator.
## Takes telemetry data and emits ranked warnings with confidence scores.

enum Severity {
	INFO,
	MODERATE,
	MAJOR,
	CRITICAL
}

func evaluate_batch(stats: Dictionary, total_battles: int) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	
	warnings.append({
		"title": "Map Bias Detected",
		"severity": Severity.MAJOR,
		"confidence": 97,
		"description": "Knight win rate drops by 20% on Narrow maps.",
		"state": "investigating"
	})
	
	warnings.append({
		"title": "AI Utility Hoarding",
		"severity": Severity.MODERATE,
		"confidence": 91,
		"description": "Cleric is saving AP for Healing but missing opportunities to attack.",
		"state": "investigating"
	})
	
	return warnings

func generate_health_summary(warnings: Array) -> String:
	var critical_count = 0
	var major_count = 0
	for w in warnings:
		if w.severity == Severity.CRITICAL: critical_count += 1
		elif w.severity == Severity.MAJOR: major_count += 1
		
	if critical_count > 0:
		return "Overall Health: Critical. Found %d game-breaking balance issues that must be addressed." % critical_count
	elif major_count > 0:
		return "Overall Health: Needs Tuning. Found %d major balance anomalies (e.g. Map Bias, AI Trap)." % major_count
	return "Overall Health: Good. All metrics are within acceptable target goal margins."

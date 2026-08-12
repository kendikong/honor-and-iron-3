class_name BeastFactory
extends RefCounted

## Compatibility entry point for class QA tooling. Authoritative data remains in
## BeastRiderFactory so there is one factory source of truth.


static func build(basic_lance: WeaponData) -> UnitData:
	return BeastRiderFactory.build(basic_lance)

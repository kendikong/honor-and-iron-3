class_name FactoryTestHelpers
extends RefCounted


static func build_unit(class_id: StringName) -> UnitData:
	var weapon := WeaponData.new()
	weapon.id = &"factory_test_weapon"
	weapon.display_name = "Factory Test Weapon"
	weapon.might = 4
	var unit: UnitData = null
	match class_id:
		&"knight":
			unit = KnightFactory.build(weapon)
		&"bruiser":
			unit = BruiserFactory.build(weapon)
		&"archer":
			unit = ArcherFactory.build(weapon)
		&"lancer":
			unit = LancerFactory.build(weapon)
		&"mage":
			unit = MageFactory.build(weapon)
		&"cleric":
			unit = ClericFactory.build(weapon)
		&"mercenary":
			unit = MercenaryFactory.build(weapon)
		&"monk":
			unit = MonkFactory.build(weapon)
		&"shaman":
			unit = ShamanFactory.build(weapon)
	if unit == null:
		return null
	var basic := DataLibrary._make_class_basic_attack(class_id)
	basic.finalize_modular()
	unit.abilities.append(basic)
	return unit

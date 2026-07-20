extends RefCounted

# Roguelite meta-progression: Embers are earned every run (score/10 + boss
# bounties) and spent in The Roost on permanent perks. Persisted in save.cfg [meta].

const SAVE_PATH := "user://save.cfg"

const PERKS := {
	"head_start": {"name": "Head Start", "desc": "Begin each run with 10 units already flocked (per level)", "per": 10, "max": 3, "base_cost": 40},
	"sharp_flock": {"name": "Sharp Flock", "desc": "+10% contact damage, forever (per level)", "per": 10, "max": 3, "base_cost": 50},
	"swift_blood": {"name": "Swift Blood", "desc": "+5% unit speed, forever (per level)", "per": 5, "max": 3, "base_cost": 40},
	"rich_air": {"name": "Rich Air", "desc": "+25 strays fill the field (per level)", "per": 25, "max": 3, "base_cost": 30},
}


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg


static func embers() -> int:
	return _load().get_value("meta", "embers", 0)


static func add_embers(n: int) -> void:
	var cfg := _load()
	cfg.set_value("meta", "embers", int(cfg.get_value("meta", "embers", 0)) + n)
	cfg.save(SAVE_PATH)


static func perk(id: String) -> int:
	return _load().get_value("meta", "perk_" + id, 0)


static func cost(id: String) -> int:
	return int(PERKS[id]["base_cost"]) * (perk(id) + 1)


static func can_buy(id: String) -> bool:
	return perk(id) < int(PERKS[id]["max"]) and embers() >= cost(id)


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var cfg := _load()
	var price: int = cost(id)
	cfg.set_value("meta", "embers", int(cfg.get_value("meta", "embers", 0)) - price)
	cfg.set_value("meta", "perk_" + id, perk(id) + 1)
	cfg.save(SAVE_PATH)
	return true

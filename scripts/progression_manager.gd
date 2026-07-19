class_name ProgressionManager
extends RefCounted

static var total_bullets_fired := 0
static var total_coins_collected := 0
static var total_items_collected := 0
static var total_kills := 0
static var peak_combo := 0
static var run_survival_time := 0.0

static var announced_milestones := []

static var weapon_kills := {
	"pistol": 0,
	"shotgun": 0,
	"smg": 0,
	"minigun": 0,
	"sniper": 0,
	"missile": 0
}

static var weapon_unlocks := {
	"pistol": true,
	"shotgun": false,
	"smg": false,
	"minigun": false,
	"sniper": false,
	"missile": false
}

static var passive_unlocks := {
	"shield": false,
	"speed_loader": false,
	"golden_touch": false,
	"magnet_ring": false,
	"toughness": false,
	"damage_boost": false
}

static func reset_run_stats() -> void:
	run_survival_time = 0.0

static func record_kill(weapon_name: String) -> void:
	if not weapon_kills.has(weapon_name):
		weapon_kills[weapon_name] = 0
	weapon_kills[weapon_name] += 1
	total_kills += 1

static func check_milestone_status(id: String) -> float:
	match id:
		"shotgun":
			return float(weapon_kills.get("pistol", 0))
		"smg":
			return float(weapon_kills.get("shotgun", 0))
		"minigun":
			return float(weapon_kills.get("smg", 0))
		"sniper":
			return float(run_survival_time)
		"missile":
			return float(weapon_kills.get("sniper", 0))
		"shield":
			return float(run_survival_time)
		"speed_loader":
			return float(total_bullets_fired)
		"golden_touch":
			return float(total_coins_collected)
		"magnet_ring":
			return float(total_items_collected)
		"toughness":
			# Handled by custom tracking incremented directly
			return 0.0
		"damage_boost":
			return float(total_kills)
	return 0.0

class_name WeaponDB
extends RefCounted

const WEAPON_DATA := {
	"pistol": { "fire_rate": 0.03, "spread": 0.0, "bullets": 1, "penetrate": false, "explosive": false, "ammo_max": -1, "damage": 4, "bullet_type": "pistol", "reload_time": 0.8, "recoil": 0.0, "clip_max": 8 },
	"smg": { "fire_rate": 0.12, "spread": 0.015, "bullets": 1, "penetrate": false, "explosive": false, "ammo_max": 120, "damage": 2, "bullet_type": "smg", "reload_time": 1.2, "recoil": 20.0, "clip_max": 30 },
	"shotgun": { "fire_rate": 0.8, "spread": 0.14, "bullets": 8, "penetrate": false, "explosive": false, "ammo_max": 30, "damage": 1, "bullet_type": "shotgun", "reload_time": 1.5, "recoil": 80.0, "clip_max": 6 },
	"minigun": { "fire_rate": 0.05, "spread": 0.03, "bullets": 1, "penetrate": false, "explosive": false, "ammo_max": 200, "damage": 1, "bullet_type": "minigun", "reload_time": 2.2, "recoil": 15.0, "clip_max": 50 },
	"sniper": { "fire_rate": 1.2, "spread": 0.0, "bullets": 1, "penetrate": true, "explosive": false, "ammo_max": 5, "damage": 30, "bullet_type": "sniper", "reload_time": 1.0, "recoil": 45.0, "clip_max": 1 },
	"missile": { "fire_rate": 1.2, "spread": 0.0, "bullets": 1, "penetrate": false, "explosive": true, "ammo_max": 8, "damage": 5, "bullet_type": "missile", "reload_time": 1.8, "recoil": 60.0, "clip_max": 1 },
}

const WEAPON_SHAKES := {
	"pistol": 0.6,
	"smg": 0.4,
	"shotgun": 2.5,
	"minigun": 0.5,
	"sniper": 3.5,
	"missile": 4.5,
}

const WEAPON_SCALES := {
	"pistol": Vector2(1.6, 1.6),
	"smg": Vector2(2.0, 2.0),
	"shotgun": Vector2(2.2, 2.2),
	"minigun": Vector2(2.5, 2.5),
	"sniper": Vector2(2.5, 2.2),
	"missile": Vector2(2.6, 2.6),
}

const MILESTONES := {
	"shotgun": {
		"name": "Shotgun",
		"desc": "Master basic arms. Get 100 kills with the starting Pistol.",
		"source": "pistol",
		"target": 100,
		"type": "kills",
		"cost": 250,
		"category": "weapon"
	},
	"smg": {
		"name": "SMG",
		"desc": "Prove close-quarters mastery. Get 100 kills with the Shotgun.",
		"source": "shotgun",
		"target": 100,
		"type": "kills",
		"cost": 500,
		"category": "weapon"
	},
	"minigun": {
		"name": "Minigun",
		"desc": "Unleash rapid fire. Get 150 kills with the SMG.",
		"source": "smg",
		"target": 150,
		"type": "kills",
		"cost": 1000,
		"category": "weapon"
	},
	"sniper": {
		"name": "Sniper Rifle",
		"desc": "Achieve flawless survival. Survive 5 minutes without taking damage.",
		"source": "survival",
		"target": 300,
		"type": "time",
		"cost": 1500,
		"category": "weapon"
	},
	"missile": {
		"name": "Missile Launcher",
		"desc": "Master precision destruction. Get 50 kills with the Sniper Rifle.",
		"source": "sniper",
		"target": 50,
		"type": "kills",
		"cost": 2500,
		"category": "weapon"
	},
	"shield": {
		"name": "Shield Upgrade",
		"desc": "Absorbs damage and recharges. Survive 2 minutes in a single run.",
		"source": "run",
		"target": 120,
		"type": "time",
		"cost": 400,
		"category": "passive"
	},
	"speed_loader": {
		"name": "Speed Loader",
		"desc": "Reload weapons 30% faster. Fire 1,000 total bullets.",
		"source": "bullets",
		"target": 1000,
		"type": "bullets",
		"cost": 600,
		"category": "passive"
	},
	"golden_touch": {
		"name": "Golden Touch",
		"desc": "20% chance to drop double coins. Collect 500 total coins.",
		"source": "coins",
		"target": 500,
		"type": "coins",
		"cost": 800,
		"category": "passive"
	},
	"magnet_ring": {
		"name": "Magnet Ring",
		"desc": "+120% collection radius. Collect 100 pickup items.",
		"source": "items",
		"target": 100,
		"type": "items",
		"cost": 500,
		"category": "passive"
	},
	"toughness": {
		"name": "Toughness",
		"desc": "35% chance to ignore any damage. Defeat 250 total enemies.",
		"source": "total",
		"target": 250,
		"type": "kills",
		"cost": 750,
		"category": "passive"
	},
	"damage_boost": {
		"name": "Damage Boost",
		"desc": "Permanent +35% bullet damage. Achieve a 10x combo multiplier.",
		"source": "combo",
		"target": 10,
		"type": "combo",
		"cost": 1200,
		"category": "passive"
	}
}

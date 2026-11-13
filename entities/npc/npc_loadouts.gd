class_name NpcLoadouts
extends RefCounted
## Equipo de cada tipo de enemigo: modelo, arma (con mira o silenciador), casco,
## chaleco, cargadores de repuesto y lo que puede llevar encima.
##
## Los "Caranchos" son bandidos del Delta: andan con lo que le sacaron a la policía,
## al ejército y a los que se metieron en la Zona antes que ellos.

const MODELS := "res://assets/models/npc/%s/%s.glb"

## model, weapons (una al azar), helmet, vest (ids; "" = nada), mags (repuestos mín/máx),
## grenades (mín/máx), loot: [id, mín, máx, probabilidad], hp.
const LOADOUTS := {
	"bandit_rifle": {"model": "fsb", "weapons": ["akm", "ak74", "sks"], "weapon_condition": [0.2, 0.7], "helmet": "", "vest": "vest_light",
		"mags": [2, 3], "grenades": [0, 1], "hp": 100.0,
		"loot": [["bandage", 1, 2, 0.6], ["cash", 30, 180, 0.7], ["canned_meat", 1, 1, 0.25], ["water", 1, 1, 0.25]]},
	"bandit_smg": {"model": "swat", "weapons": ["pp19", "mp5", "vityaz"], "weapon_condition": [0.2, 0.7], "helmet": "helmet_steel", "vest": "",
		"mags": [2, 3], "grenades": [0, 1], "hp": 100.0,
		"loot": [["bandage", 1, 2, 0.6], ["cash", 20, 150, 0.7], ["energy_drink", 1, 1, 0.25], ["bread", 1, 1, 0.25]]},
	"bandit_shotgun": {"model": "swat_special", "weapons": ["shotgun", "sawedoff"], "weapon_condition": [0.25, 0.7], "helmet": "", "vest": "vest_light",
		"mags": [0, 0], "ammo": [8, 16], "grenades": [0, 0], "hp": 100.0,
		"loot": [["bandage", 1, 1, 0.5], ["cash", 20, 120, 0.6], ["canned_meat", 1, 1, 0.3]]},
	"bandit_marksman": {"model": "fsb", "weapons": ["svd", "sks"], "helmet": "helmet_steel", "vest": "",
		"mags": [2, 3], "grenades": [0, 0], "hp": 100.0,
		"loot": [["bandage", 1, 2, 0.5], ["cash", 60, 250, 0.7], ["medkit", 1, 1, 0.3]]},
	"bandit_pistol": {"model": "swat", "weapons": ["bersa9", "pistol", "m1911"], "weapon_condition": [0.15, 0.6], "helmet": "", "vest": "",
		"mags": [1, 2], "grenades": [0, 0], "hp": 100.0,
		"loot": [["bandage", 1, 1, 0.5], ["cash", 10, 90, 0.8], ["water", 1, 1, 0.3]]},
	"bandit_boss": {"model": "swat_remaster", "weapons": ["ak74", "hk416", "g3"], "helmet": "helmet_kevlar", "vest": "vest_plate",
		"mags": [3, 4], "grenades": [1, 2], "hp": 110.0, "medkit": true,
		"loot": [["medkit", 1, 2, 0.8], ["cash", 300, 900, 1.0], ["energy_drink", 1, 1, 0.5], ["optic_elcan", 1, 1, 0.25],
			["supp_545", 1, 1, 0.2]]},
}


## Militares: escuadras con táctica (se cubren, avanzan, flanquean, hablan y se hacen
## señas). Buen equipo, pero lo usan hasta romperlo: al saquearlos está gastado.
const MILITARY := {
	"mil_leader": {"model": "swat_remaster", "weapons": ["hk416", "ar15"], "sights": ["optic_holo_a", "optic_reddot", "optic_acog"],
		"helmet": "helmet_kevlar", "vest": "vest_plate", "mags": [4, 5], "grenades": [1, 2], "smokes": [2, 2], "hp": 100.0,
		"medkit": true, "tactics": "military", "voice": true, "leader": true, "suppressor": 0.3,
		"weapon_condition": [0.6, 0.85], "loot_condition": [0.2, 0.45], "armor_loot_condition": [0.25, 0.5],
		"loot": [["medkit", 1, 1, 0.6], ["bandage", 1, 3, 0.8], ["cash", 150, 500, 0.8], ["energy_drink", 1, 1, 0.4]]},
	"mil_rifle": {"model": "swat_remaster", "weapons": ["hk416", "ar15", "ak74", "scarl"],
		"sights": ["optic_holo_a", "optic_holo_b", "optic_reddot", "optic_acog", ""], "helmet": "helmet_kevlar",
		"vest": "vest_medium", "mags": [3, 5], "grenades": [1, 2], "smokes": [0, 1], "hp": 100.0, "tactics": "military",
		"voice": true, "suppressor": 0.2, "weapon_condition": [0.55, 0.85], "loot_condition": [0.15, 0.45],
		"armor_loot_condition": [0.2, 0.5],
		"loot": [["bandage", 1, 2, 0.8], ["cash", 80, 300, 0.7], ["water", 1, 1, 0.4], ["canned_meat", 1, 1, 0.3]]},
	"mil_marksman": {"model": "swat", "weapons": ["svd", "sr22"], "sights": [], "helmet": "helmet_kevlar",
		"vest": "vest_medium", "mags": [3, 4], "grenades": [0, 1], "smokes": [1, 1], "hp": 100.0, "tactics": "military",
		"voice": true, "weapon_condition": [0.6, 0.85], "loot_condition": [0.2, 0.45], "armor_loot_condition": [0.2, 0.5],
		"loot": [["bandage", 1, 2, 0.7], ["cash", 100, 350, 0.7], ["medkit", 1, 1, 0.3]]},
}


static func get_loadout(id: String) -> Dictionary:
	if MILITARY.has(id):
		return MILITARY[id]
	return LOADOUTS.get(id, LOADOUTS["bandit_rifle"])


static func model_path(model: String) -> String:
	return MODELS % [model, model]

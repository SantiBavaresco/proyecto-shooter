class_name ItemDB
extends RefCounted
## Catálogo de ítems. Se arma una vez:
##  - armas: una por cada entrada de data/weapons/catalog.json (id "w_<arma>");
##  - munición: una por calibre (id "ammo_<calibre>"), peso y precio por cartucho;
##  - el resto: data/items/items.json.

const ITEMS_FILE := "res://data/items/items.json"
const WEAPON_CATALOG := "res://data/weapons/catalog.json"

## Munición por calibre: [id, kg por cartucho, cartuchos por pila, USD por cartucho].
const AMMO := {
	"9×19": ["9x19", 0.012, 60, 1],
	"9×18": ["9x18", 0.011, 60, 1],
	".45 ACP": ["45acp", 0.021, 50, 2],
	".22 LR": ["22lr", 0.0035, 100, 1],
	"5.45×39": ["545x39", 0.0105, 60, 2],
	"5.56×45": ["556x45", 0.012, 60, 2],
	"7.62×39": ["762x39", 0.0163, 60, 2],
	"7.62×51": ["762x51", 0.025, 40, 3],
	"7.62×54R": ["762x54r", 0.022, 40, 3],
	"7.65×53": ["765x53", 0.024, 40, 3],
	"12/70": ["12g", 0.04, 25, 2],
}
## Calibres que comparten munición (el .308 Win y el 7.62×51 son intercambiables acá).
const AMMO_ALIAS := {".308": "7.62×51"}

## Por familia de modelo: [ancho, alto] en la grilla, kg, USD.
const WEAPON_FAMILY := {
	"pistol": [2, 2, 0.95, 450],
	"smg": [4, 2, 2.8, 1400],
	"rifle_ak": [5, 2, 3.5, 2200],
	"rifle_ar": [5, 2, 3.4, 2600],
	"rifle_battle": [6, 2, 4.5, 3200],
	"bolt": [6, 2, 4.1, 2400],
	"shotgun_sxs": [5, 2, 3.2, 900],
	"shotgun_ou": [5, 2, 3.4, 1500],
	"imported": [4, 2, 2.9, 1900],
}
## Excepciones por arma: [ancho, alto, kg].
const WEAPON_OVERRIDE := {
	"sawedoff": [3, 2, 2.1], "svd": [6, 2, 4.3], "pp19": [4, 2, 2.7], "ak74u": [4, 2, 2.7],
	"revolver45": [2, 2, 1.1], "p22": [2, 2, 0.9], "sr22": [4, 2, 2.4], "bolt22": [5, 2, 2.6],
}

static var _items: Dictionary = {}
static var _weapon_ids: Array[String] = []


static func _ensure() -> void:
	if not _items.is_empty():
		return
	# Munición
	for cal: String in AMMO:
		var a: Array = AMMO[cal]
		var it := ItemData.new()
		it.id = "ammo_" + String(a[0])
		it.name_key = "item.ammo"
		it.desc_key = "item.ammo.desc"
		it.kind = "ammo"
		it.caliber = cal
		it.weight = float(a[1])
		it.stack_max = int(a[2])
		it.price = int(a[3])
		_items[it.id] = it
	# Armas del catálogo
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(WEAPON_CATALOG))
	for wid: String in catalog:
		var path := "res://data/weapons/%s.tres" % wid
		var wd := load(path) as WeaponData
		if wd == null:
			continue
		var fam: Array = WEAPON_FAMILY.get(wd.model, WEAPON_FAMILY["rifle_ak"])
		var ov: Array = WEAPON_OVERRIDE.get(wid, [])
		var it := ItemData.new()
		it.id = "w_" + wid
		it.name_key = wd.name_key
		it.desc_key = "item.weapon.desc"
		it.kind = "weapon"
		it.caliber = wd.caliber
		it.weapon_path = path
		it.size = Vector2i(int(ov[0]), int(ov[1])) if not ov.is_empty() else Vector2i(int(fam[0]), int(fam[1]))
		it.weight = float(ov[2]) if not ov.is_empty() else float(fam[2])
		it.price = int(fam[3])
		it.stack_max = 1
		_items[it.id] = it
		_weapon_ids.append(it.id)
	# Resto
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_FILE))
	for e: Dictionary in j["items"]:
		var it := ItemData.new()
		it.id = e["id"]
		it.name_key = "item." + it.id
		it.desc_key = "item." + it.id + ".desc"
		it.kind = e.get("kind", "misc")
		var sz: Array = e.get("size", [1, 1])
		it.size = Vector2i(int(sz[0]), int(sz[1]))
		it.weight = float(e.get("weight", 0.1))
		it.stack_max = int(e.get("stack", 1))
		it.price = int(e.get("price", 0))
		it.use_time = float(e.get("use_time", 0.0))
		it.effects = e.get("effects", {})
		it.protection = float(e.get("protection", 0.0))
		it.carry_bonus = float(e.get("carry_bonus", 0.0))
		_items[it.id] = it


static func get_item(id: String) -> ItemData:
	_ensure()
	return _items.get(id)


static func has(id: String) -> bool:
	_ensure()
	return _items.has(id)


static func all_ids() -> Array:
	_ensure()
	return _items.keys()


static func weapon_item_ids() -> Array[String]:
	_ensure()
	return _weapon_ids


## Calibre con el que se cuenta la munición (resuelve los alias).
static func ammo_caliber(caliber: String) -> String:
	return AMMO_ALIAS.get(caliber, caliber)


## Ítem de munición de un calibre ("" si no hay).
static func ammo_id(caliber: String) -> String:
	var c := ammo_caliber(caliber)
	return "ammo_" + String(AMMO[c][0]) if AMMO.has(c) else ""


static func weapon_item_id(weapon_id: String) -> String:
	return "w_" + weapon_id


## Nombre para mostrar (la munición lleva el calibre).
static func display_name(item: ItemData) -> String:
	if item.kind == "ammo":
		return TranslationServer.translate(item.name_key) % item.caliber
	return TranslationServer.translate(item.name_key)

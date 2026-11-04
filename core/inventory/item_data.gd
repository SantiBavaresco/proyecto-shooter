class_name ItemData
extends RefCounted
## Definición de un ítem (datos, no estado). Las armas y la munición se generan
## del catálogo de armas y de los calibres; el resto sale de data/items/items.json.
## Ver ItemDB.

## Orden de los tipos al ordenar el inventario.
const KIND_ORDER := ["weapon", "melee", "armor", "helmet", "rig", "backpack", "sight", "muzzle", "mag", "ammo", "medical", "drink",
	"food", "misc", "money"]

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
## "weapon", "melee", "ammo", "mag", "sight", "muzzle", "medical", "food", "drink", "armor", "helmet",
## "rig", "backpack", "misc", "money".
var kind: String = "misc"
## Celdas que ocupa (ancho, alto) sin rotar.
var size: Vector2i = Vector2i.ONE
## kg por unidad.
var weight: float = 0.1
var stack_max: int = 1
## USD por unidad.
var price: int = 0
## Munición: calibre que carga. Armas: calibre que usan.
var caliber: String = ""
## Armas: archivo WeaponData.
var weapon_path: String = ""
## Consumibles: segundos que lleva usarlo y efectos (heal, bleed, stamina, regen,
## stamina_regen, duration).
var use_time: float = 0.0
var effects: Dictionary = {}
## Equipo: protección (para F3) y kg extra que deja cargar.
var protection: float = 0.0
var carry_bonus: float = 0.0
## Modelo .glb propio (si no, se arma por código) y su escala.
var model_path: String = ""
var model_scale: float = 1.0
## Chalecos tácticos y mochilas: grillas que tiene adentro, [x, y, ancho, alto] (x, y:
## dónde se dibujan, en celdas).
var grids: Array = []
## Cargadores: familia (qué armas lo aceptan) y capacidad.
var mag_family: String = ""
var capacity: int = 0
## Miras y silenciadores: su definición (data/items/attachments.json).
var attach: Dictionary = {}

var _weapon: WeaponData


func weapon() -> WeaponData:
	if _weapon == null and weapon_path != "":
		_weapon = load(weapon_path) as WeaponData
	return _weapon


func is_consumable() -> bool:
	return kind in ["medical", "food", "drink"]


func is_equipment() -> bool:
	return kind in ["weapon", "melee", "armor", "helmet", "rig", "backpack"]


## Lleva cosas adentro (chaleco táctico, mochila).
func is_container() -> bool:
	return not grids.is_empty()


func is_attachment() -> bool:
	return kind in ["sight", "muzzle"]


func stackable() -> bool:
	return stack_max > 1


## Ranura de equipo donde va (para armas: la primera que le corresponde).
func equip_slots() -> PackedStringArray:
	match kind:
		"weapon":
			var w := weapon()
			if w != null and w.slot == 3:
				return PackedStringArray(["pistol"])
			return PackedStringArray(["weapon1", "weapon2"])
		"armor":
			return PackedStringArray(["armor"])
		"helmet":
			return PackedStringArray(["helmet"])
		"backpack":
			return PackedStringArray(["backpack"])
		"rig":
			return PackedStringArray(["rig"])
		"melee":
			return PackedStringArray(["melee"])
	return PackedStringArray()


func kind_rank() -> int:
	var i := KIND_ORDER.find(kind)
	return i if i >= 0 else KIND_ORDER.size()

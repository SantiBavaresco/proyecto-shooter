class_name ItemData
extends RefCounted
## Definición de un ítem (datos, no estado). Las armas y la munición se generan
## del catálogo de armas y de los calibres; el resto sale de data/items/items.json.
## Ver ItemDB.

## Orden de los tipos al ordenar el inventario.
const KIND_ORDER := ["weapon", "armor", "helmet", "backpack", "ammo", "medical", "drink", "food", "misc", "money"]

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
## "weapon", "ammo", "medical", "food", "drink", "armor", "helmet", "backpack", "misc", "money".
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

var _weapon: WeaponData


func weapon() -> WeaponData:
	if _weapon == null and weapon_path != "":
		_weapon = load(weapon_path) as WeaponData
	return _weapon


func is_consumable() -> bool:
	return kind in ["medical", "food", "drink"]


func is_equipment() -> bool:
	return kind in ["weapon", "armor", "helmet", "backpack"]


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
	return PackedStringArray()


func kind_rank() -> int:
	var i := KIND_ORDER.find(kind)
	return i if i >= 0 else KIND_ORDER.size()

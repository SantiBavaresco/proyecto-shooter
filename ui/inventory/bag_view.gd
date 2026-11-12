class_name BagView
extends RefCounted
## "Contenedor" para revisar una mochila o un chaleco táctico sin agarrarlo (tirado en
## el piso o adentro de otro contenedor). Muestra sus grillas tal cual: lo que se
## saca o se pone, cambia de verdad adentro de la mochila.

var stack: ItemStack
var inventory: Inventory
## Todas sus grillas (los chalecos tienen varias) y dónde va cada una.
var inventories: Array[Inventory] = []
var layout: Array = []
var title_key := ""
## Lo que se estaba revisando antes (el piso, una caja): "Volver" lo reabre.
var back: Object = null


func _init(s: ItemStack, from: Object = null) -> void:
	stack = s
	inventories = s.contents
	inventory = s.contents[0] if not s.contents.is_empty() else Inventory.new(1, 1)
	layout = s.item.grids
	title_key = s.item.name_key
	back = from

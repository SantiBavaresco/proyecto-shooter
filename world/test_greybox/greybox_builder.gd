extends Node3D
## Pista de pruebas de movimiento ("greybox").
## La geometría se arma por código para poder ajustarla rápido y testearla.
##
## Estaciones (el jugador aparece en el origen mirando hacia −Z):
##  - Carril de carrera con marcas cada 10 m (adelante)
##  - Cajas de 0,5 / 1 / 1,5 / 2 m para probar saltos (derecha)
##  - Túnel bajo de 1,3 m: solo se pasa agachado (izquierda)
##  - Rampas de 20°, 40° y 55° (la última no se puede subir)
##  - Escalera (colisión de rampa invisible; subir escalones real llega más adelante)
##  - Plataformas con huecos de 2, 3 y 4 m
##  - Esquina para practicar inclinarse, con postes detrás
##  - Pila de contenedores marítimos (medidas reales de 20 pies)
##  - Polígono de tiro detrás del spawn (+Z): dianas a 25/50/100/200 m,
##    maniquíes, placa de acero para rebotes y caja de munición
##  - Penetración: paneles de madera y chapa (finos y gruesos) con dianas detrás
##  - Zonas de prueba junto a la línea de tiro: estrés medio, estrés alto y
##    armas gastadas (fallas frecuentes)
##  - Inventario y saqueo (atrás a la izquierda del spawn): cajón, caja metálica,
##    alijo pesado, ítems sueltos en el piso y alambre de púas (daño y sangrado)
##  - Zona de combate (al fondo a la izquierda): un grupo de 5 enemigos con IA entre
##    coberturas, con una consola para cambiar la dificultad y otra para reiniciar

const GridShader := preload("res://world/test_greybox/grid.gdshader")
const Mannequin := preload("res://world/props/mannequin.gd")
const PaperTarget := preload("res://world/props/paper_target.gd")
const AmmoCrate := preload("res://world/props/ammo_crate.gd")
const WeaponTable := preload("res://world/props/weapon_table.gd")
const LootContainerScript := preload("res://world/props/loot_container.gd")
const WorldItemScript := preload("res://world/props/world_item.gd")

## Polígono: línea de tiro y franja que ocupa (x de 18 a 42).
const RANGE_LINE_Z := 30.0
## Armas recién agregadas: mesas aparte, separadas de la armería.
const NEW_WEAPONS := ["chukavin", "mark23"]
const RANGE_X_MIN := 18.0
const RANGE_X_MAX := 42.0
const RANGE_END_Z := 260.0

## Colores de los contenedores (óxido, azul, verde gastados).
const CONTAINER_COLORS: Array[Color] = [Color("7a3b28"), Color("2f4a63"), Color("3f5a36"), Color("8a6b2a")]
const CONTAINER_SIZE := Vector3(6.06, 2.59, 2.44)

var _mat_floor: ShaderMaterial
var _mat_block: ShaderMaterial
var _mat_accent: ShaderMaterial


func _ready() -> void:
	_mat_floor = _grid_material(Color(0.40, 0.41, 0.38))
	_mat_block = _grid_material(Color(0.55, 0.55, 0.52))
	_mat_accent = _grid_material(Color(0.62, 0.52, 0.30))
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		# Sol de tarde, bajo y cálido, adelante a la derecha del spawn
		# (la sombra del cuerpo cae hacia atrás y no tapa la vista).
		sun.rotation_degrees = Vector3(-28.0, 150.0, 0.0)
		sun.add_to_group("sun")
	_build()


func _build() -> void:
	var geo := Node3D.new()
	geo.name = "Geometry"
	add_child(geo)

	# Piso y perímetro
	_box(geo, Vector3(0, -0.5, -30), Vector3(140, 1, 140), _mat_floor)
	for side: Vector3 in [Vector3(70, 1.5, -30), Vector3(-70, 1.5, -30)]:
		_box(geo, side, Vector3(1, 3, 140), _mat_block)
	_box(geo, Vector3(0, 1.5, -100), Vector3(140, 3, 1), _mat_block)
	# Muro sur con abertura hacia el polígono
	_box(geo, Vector3((-70.0 + RANGE_X_MIN) * 0.5, 1.5, 40), Vector3(RANGE_X_MIN + 70.0, 3, 1), _mat_block)
	_box(geo, Vector3((RANGE_X_MAX + 70.0) * 0.5, 1.5, 40), Vector3(70.0 - RANGE_X_MAX, 3, 1), _mat_block)

	# Carril de carrera con marcas cada 10 m
	for i in range(1, 7):
		var z := -10.0 * i
		_box(geo, Vector3(-2.5, 0.01, z), Vector3(5, 0.02, 0.15), _mat_accent, false)
		_label(geo, Vector3(-2.5, 0.4, z), "%d m" % (i * 10), 0.6)
	_sign(geo, Vector3(-2.5, 3.4, -3), tr("greybox.sprint_lane"))

	# Cajas de salto
	var heights: Array[float] = [0.5, 1.0, 1.5, 2.0]
	for i in heights.size():
		var h := heights[i]
		var pos := Vector3(8 + i * 3.0, h * 0.5, -8)
		_box(geo, pos, Vector3(2, h, 2), _mat_accent if h <= 1.0 else _mat_block, true, "wood" if h <= 1.0 else "concrete")
		_label(geo, Vector3(pos.x, h + 0.35, pos.z + 1.05), "%.1f m" % h, 0.5)
	_sign(geo, Vector3(12.5, 3.3, -8), tr("greybox.jump_boxes"))

	# Túnel bajo (solo agachado)
	var tunnel_x := -10.0
	var tunnel_len := 8.0
	var tunnel_h := 1.3
	_box(geo, Vector3(tunnel_x - 1.1, tunnel_h * 0.5, -8), Vector3(0.4, tunnel_h, tunnel_len), _mat_block)
	_box(geo, Vector3(tunnel_x + 1.1, tunnel_h * 0.5, -8), Vector3(0.4, tunnel_h, tunnel_len), _mat_block)
	_box(geo, Vector3(tunnel_x, tunnel_h + 0.25, -8), Vector3(2.6, 0.5, tunnel_len), _mat_accent)
	_sign(geo, Vector3(tunnel_x, 2.1, -3.6), tr("greybox.crouch_tunnel"))

	# Rampas
	var angles: Array[float] = [20.0, 40.0, 55.0]
	for i in angles.size():
		_ramp(geo, Vector3(14 + i * 6.0, 0, -22), angles[i], 8.0, 4.0)
		_label(geo, Vector3(14 + i * 6.0, 0.4, -17.5), "%d°" % int(angles[i]), 0.6)
	_sign(geo, Vector3(20, 3.0, -17), tr("greybox.ramps"))

	# Escalera: escalones visuales + rampa invisible para colisión
	var steps := 10
	var step_h := 0.2
	var step_d := 0.3
	var stair_origin := Vector3(34, 0, -18)
	for s in steps:
		var top := step_h * (s + 1)
		_box(geo, stair_origin + Vector3(0, top * 0.5, -step_d * s - step_d * 0.5),
			Vector3(3, top, step_d), _mat_block, false)
	var stair_len := steps * step_d
	var stair_h := steps * step_h
	var slope_len := sqrt(stair_len * stair_len + stair_h * stair_h)
	var slope_ang := atan2(stair_h, stair_len)
	var col := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3, 0.1, slope_len)
	shape.shape = bs
	col.add_child(shape)
	col.position = stair_origin + Vector3(0, stair_h * 0.5, -stair_len * 0.5)
	col.rotation = Vector3(slope_ang, 0, 0)
	geo.add_child(col)
	_box(geo, stair_origin + Vector3(0, stair_h * 0.5, -stair_len - 2.0), Vector3(3, stair_h, 4), _mat_block)
	_sign(geo, stair_origin + Vector3(0, 2.6, 1.0), tr("greybox.stairs"))

	# Plataformas con huecos
	var px := -24.0
	var pz := -14.0
	var gaps: Array[float] = [2.0, 3.0, 4.0]
	var plat_len := 3.0
	_box(geo, Vector3(px, 0.25, pz), Vector3(3, 0.5, plat_len), _mat_block)
	for g in gaps:
		pz -= plat_len + g
		_box(geo, Vector3(px, 0.25, pz), Vector3(3, 0.5, plat_len), _mat_accent)
		_label(geo, Vector3(px + 1.6, 0.9, pz + plat_len * 0.5 + g * 0.5), "%d m" % int(g), 0.5)
	_sign(geo, Vector3(px, 2.6, -11), tr("greybox.gaps"))

	# Esquina para inclinarse, con postes detrás
	_box(geo, Vector3(4, 1.5, -40), Vector3(0.5, 3, 8), _mat_block)
	_box(geo, Vector3(1.0, 1.5, -36.25), Vector3(6.5, 3, 0.5), _mat_block)
	for i in 4:
		_box(geo, Vector3(8 + i * 2.0, 1.0, -44 - i * 1.5), Vector3(0.3, 2, 0.3), _mat_accent)
	_sign(geo, Vector3(1.0, 3.6, -36), tr("greybox.lean_corner"))

	# Contenedores apilados
	var cbase := Vector3(-22, 0, -42)
	var layout: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(0, 0, 2.5), Vector3(0, 1, 0), Vector3(7, 0, 0),
		Vector3(7, 0, 2.5), Vector3(7, 1, 2.5), Vector3(3.5, 0, 6.5),
	]
	for i in layout.size():
		var l := layout[i]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CONTAINER_COLORS[i % CONTAINER_COLORS.size()]
		mat.roughness = 0.75
		_box(geo, cbase + Vector3(l.x, CONTAINER_SIZE.y * (l.y + 0.5), l.z), CONTAINER_SIZE, mat, true, "metal")
	_sign(geo, cbase + Vector3(3.5, 7.0, 1.2), tr("greybox.containers"))

	_build_range(geo)
	_build_armory(geo)
	_build_loot_area(geo)
	_build_floor_samples(geo)
	geo.add_to_group(NavUtil.GROUP)
	_build_arena(geo)


## Zona de combate: x de −68 a −30, z de −98 a −52. Se entra por el sur (cerca del
## inicio); los enemigos esperan al fondo entre coberturas.
const ARENA_MIN := Vector2(-68, -98)
const ARENA_MAX := Vector2(-30, -52)
const ARENA_SQUAD := [["bandit_rifle", Vector3(-58, 0, -90), "akm"], ["bandit_rifle", Vector3(-40, 0, -88), "ak74"],
	["bandit_smg", Vector3(-49, 0, -84), "mp5"], ["bandit_shotgun", Vector3(-62, 0, -78), "shotgun"],
	["bandit_marksman", Vector3(-36, 0, -95), "svd"]]
## Escuadra militar de la zona de combate: 8 (líder, tirador y 6 fusileros).
const ARENA_MILITARY := [["mil_leader", Vector3(-49, 0, -94), ""], ["mil_rifle", Vector3(-55, 0, -92), ""],
	["mil_rifle", Vector3(-43, 0, -92), ""], ["mil_rifle", Vector3(-60, 0, -88), ""], ["mil_rifle", Vector3(-38, 0, -88), ""],
	["mil_rifle", Vector3(-52, 0, -86), ""], ["mil_rifle", Vector3(-46, 0, -86), ""], ["mil_marksman", Vector3(-35, 0, -96), ""]]

## Pistolas de calibre chico y escopetas (prueba de combate corto): 7.
const ARENA_LOWCAL := [["bandit_pistol", Vector3(-58, 0, -90), "p22"], ["bandit_pistol", Vector3(-40, 0, -88), "p22"],
	["bandit_pistol", Vector3(-49, 0, -92), "bersa9"], ["bandit_pistol", Vector3(-36, 0, -94), "pistol"],
	["bandit_shotgun", Vector3(-62, 0, -78), "shotgun"], ["bandit_shotgun", Vector3(-46, 0, -84), "sawedoff"],
	["bandit_shotgun", Vector3(-54, 0, -86), "ou_hunt"]]

var _arena_npcs: Array[HumanNpc] = []
var _arena_packs: Array[AnimalPack] = []


func _build_arena(geo: Node3D) -> void:
	var c := Vector3((ARENA_MIN.x + ARENA_MAX.x) * 0.5, 0, (ARENA_MIN.y + ARENA_MAX.y) * 0.5)
	_sign(geo, Vector3(c.x, 3.4, ARENA_MAX.y + 1.5), tr("greybox.arena"))
	# Muros que cierran la zona (para que no te vean ni oigan desde el resto de la
	# pista); se entra por un hueco en el muro sur
	_box(geo, Vector3(ARENA_MAX.x, 1.5, c.z), Vector3(0.5, 3, ARENA_MAX.y - ARENA_MIN.y), _mat_block)
	var gap := 5.0
	var wl := (ARENA_MAX.x - ARENA_MIN.x - gap) * 0.5
	_box(geo, Vector3(ARENA_MIN.x + wl * 0.5, 1.5, ARENA_MAX.y), Vector3(wl, 3, 0.5), _mat_block)
	_box(geo, Vector3(ARENA_MAX.x - wl * 0.5, 1.5, ARENA_MAX.y), Vector3(wl, 3, 0.5), _mat_block)
	# Coberturas: muros bajos, contenedores, cajones, bloques, un auto
	Structures.container(geo, Vector3(-55, 0, -70), 0.3, CONTAINER_COLORS[0])
	Structures.container(geo, Vector3(-38, 0, -76), -0.2, CONTAINER_COLORS[1], true)
	Structures.container(geo, Vector3(-60, 0, -92), PI * 0.5, CONTAINER_COLORS[2])
	for p: Array in [[Vector3(-49, 0, -62), 0.0], [Vector3(-62, 0, -64), 0.4], [Vector3(-36, 0, -64), -0.3], [Vector3(-46, 0, -92), 0.1]]:
		Structures.jersey(geo, p[0], p[1])
	for p: Array in [[Vector3(-44, 0, -80), 0.0], [Vector3(-56, 0, -82), 0.5], [Vector3(-33, 0, -86), 0.2]]:
		Structures.sandbags(geo, p[0], p[1], 4.0, 1.1, true)
	Structures.crates(geo, Vector3(-50, 0, -74), 0.3, 3)
	Structures.crates(geo, Vector3(-41, 0, -68), -0.4, 2)
	Structures.car_wreck(geo, Vector3(-64, 0, -72), 1.2, "car_red")
	Structures.building(geo, Vector3(-48, 0, -95), Vector3(7, 3.0, 5), 0.0, {"s": [[0.0, 1.0, 2.1, 0.0], [-2.3, 1.2, 2.0, 1.0],
		[2.3, 1.2, 2.0, 1.0]]}, Structures.mat("plaster"), "flat")
	var crate := LootContainerScript.new() as LootContainer
	crate.name = "ArenaCrate"
	crate.kind = "crate"
	crate.contents = [["grenade_rg5", 3], ["grenade_f1", 2], ["medkit", 2], ["bandage", 4], ["vest_medium", 1], ["helmet_kevlar", 1]]
	crate.position = Vector3(c.x + 5.0, 0, ARENA_MAX.y + 1.5)
	crate.rotation = Vector3(0, PI, 0)
	geo.add_child(crate)
	for a: Array in [["difficulty", Vector3(c.x - 6.5, 0, ARENA_MAX.y + 1.5)], ["reset", Vector3(c.x - 4.5, 0, ARENA_MAX.y + 1.5)],
			["faction", Vector3(c.x - 8.5, 0, ARENA_MAX.y + 1.5)]]:
		var con := ArenaConsole.new()
		con.name = "ArenaConsole_" + a[0]
		con.action = a[0]
		con.position = a[1]
		con.rotation = Vector3(0, PI, 0)
		geo.add_child(con)
		con.used.connect(_on_console)
	NavUtil.bake(self, AABB(Vector3(ARENA_MIN.x - 2, -2, ARENA_MIN.y - 2), Vector3(ARENA_MAX.x - ARENA_MIN.x + 4, 12,
		ARENA_MAX.y - ARENA_MIN.y + 8)), true)
	_spawn_arena.call_deferred()


func _on_console(action: String) -> void:
	if action == "reset" or action == "faction":
		_spawn_arena()


## Pone (o vuelve a poner) el grupo de 5 de la zona de combate.
func _spawn_arena() -> void:
	for n in _arena_npcs:
		if is_instance_valid(n):
			n.queue_free()
	_arena_npcs.clear()
	for sq in get_tree().get_nodes_in_group("squad_coordinator"):
		if (sq as Squad).id == "arena":
			sq.queue_free()
	for pk in _arena_packs:
		if is_instance_valid(pk):
			pk.queue_free()
	_arena_packs.clear()
	if ArenaConsole.faction == "animals":
		# Una jauría y una piara (en lados distintos de la zona)
		for spec: Array in [["dog", Vector3(-58, 0.1, -88), 11], ["boar", Vector3(-38, 0.1, -92), 12]]:
			var pk := AnimalPack.new()
			pk.species = spec[0]
			pk.roam = 12.0
			pk.seed_value = spec[2] + randi() % 1000
			pk.position = spec[1]
			add_child(pk)
			_arena_packs.append(pk)
		return
	var list: Array = {"military": ARENA_MILITARY, "lowcal": ARENA_LOWCAL}.get(ArenaConsole.faction, ARENA_SQUAD)
	for i in list.size():
		var e: Array = list[i]
		var n := HumanNpc.new()
		n.name = "ArenaNpc_%d" % i
		n.loadout_id = e[0]
		n.weapon_id = e[2]
		n.squad = "arena"
		n.leash = 26.0
		n.hearing_mult = 0.5
		n.position = e[1] + Vector3(0, 0.05, 0)
		n.rotation = Vector3(0, PI, 0)
		add_child(n)
		_arena_npcs.append(n)


## Muerte del jugador: el cuerpo queda con todo y vuelve a aparecer en el inicio con
## el equipo de pruebas completo.
func on_player_died(p: Player) -> void:
	PlayerCorpse.leave(p)
	p.inventory.give_start_kit()
	p.respawn_at(Vector3(0, 0.05, 0), 0.0)
	EventBus.player_respawned.emit(p)


## Pisos para probar los pasos: hormigón, tierra, madera y metal (losas de 3,5 m).
func _build_floor_samples(geo: Node3D) -> void:
	var pads := [["concrete", Color(0.55, 0.55, 0.53), "greybox.floor_concrete"],
		["dirt", Color(0.4, 0.31, 0.2), "greybox.floor_dirt"],
		["wood", Color(0.5, 0.36, 0.22), "greybox.floor_wood"],
		["metal", Color(0.36, 0.39, 0.42), "greybox.floor_metal"]]
	for i in pads.size():
		var m := StandardMaterial3D.new()
		m.albedo_color = pads[i][1]
		m.roughness = 0.9 if pads[i][0] != "metal" else 0.45
		m.metallic = 0.6 if pads[i][0] == "metal" else 0.0
		var x := -1.0 + i * 4.0
		_box(geo, Vector3(x, 0.02, 24.0), Vector3(3.5, 0.04, 3.5), m, true, pads[i][0])
		if pads[i][0] == "wood":
			# Tablas
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color(0.32, 0.22, 0.13)
			for k in 6:
				_box(geo, Vector3(x - 1.75 + 0.58 * (k + 0.5), 0.041, 24.0), Vector3(0.02, 0.003, 3.5), dark, false)
		_label(geo, Vector3(x, 0.6, 22.0), tr(pads[i][2]), 0.9)
	_sign(geo, Vector3(5.0, 3.0, 24.0), tr("greybox.floors"))


## Inventario y saqueo: contenedores, ítems sueltos y alambre de púas.
func _build_loot_area(geo: Node3D) -> void:
	_sign(geo, Vector3(9.5, 3.4, 9.0), tr("greybox.loot"))
	var boxes: Array = [
		["LootCrate", "crate", Vector3(6.5, 0, 11.0), [], 7],
		["LootMetal", "metal", Vector3(9.5, 0, 11.0), [["helmet_steel", 1], ["vest_light", 1], ["ammo_545x39", 60],
			["ammo_9x19", 60], ["medkit_army", 1]], 0],
		["LootStash", "stash", Vector3(12.5, 0, 11.0), [["backpack_large", 1], ["vest_plate", 1], ["tools_basic", 4],
			["w_svd", 1], ["ammo_762x54r", 40], ["scrap_electronics", 4]], 0],
		["LootWeapons", "weapons", Vector3(15.5, 0, 11.0), [], 0],
		["LootGear", "stash", Vector3(18.5, 0, 11.0), [["rig_light", 1], ["rig_assault", 1], ["backpack_small", 1],
			["backpack_expedition", 1], ["optic_holo_a", 1], ["optic_reddot", 1], ["optic_acog", 1], ["optic_elcan", 1], ["supp_545", 1],
			["supp_pistol", 1], ["supp_762", 1]], 0],
	]
	for b: Array in boxes:
		var c := LootContainerScript.new() as LootContainer
		c.name = b[0]
		c.kind = b[1]
		c.contents = b[3]
		c.loot_seed = b[4]
		c.position = b[2]
		c.rotation = Vector3(0, PI, 0)
		geo.add_child(c)
	# Ítems sueltos en el piso
	var loose: Array = [["backpack_small", 1, Vector3(6.0, 0.1, 14.5)], ["w_sks", 1, Vector3(8.0, 0.1, 14.5)],
		["medkit", 1, Vector3(10.0, 0.1, 14.2)], ["bread", 1, Vector3(10.6, 0.1, 14.8)], ["cash", 500, Vector3(11.5, 0.1, 14.4)],
		["bandage", 2, Vector3(12.4, 0.1, 14.6)], ["ammo_12g", 20, Vector3(13.3, 0.1, 14.3)]]
	for e: Array in loose:
		var w := WorldItemScript.make(e[0], e[1]) as WorldItem
		w.position = e[2]
		geo.add_child(w)
	# Alambre de púas: lastima y hace sangrar (para probar vendas y botiquines)
	var z := TestZone.new()
	z.name = "Zone_hurt"
	z.kind = "hurt"
	z.size = Vector2(3.0, 2.4)
	z.color = Color(0.75, 0.3, 0.15)
	z.title = tr("greybox.zone_hurt")
	z.position = Vector3(9.5, 0, 19.0)
	geo.add_child(z)
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.35, 0.33, 0.3)
	wire.metallic = 0.8
	wire.roughness = 0.5
	for i in 4:
		var coil := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.27
		tm.outer_radius = 0.3
		coil.mesh = tm
		coil.material_override = wire
		coil.position = Vector3(8.4 + i * 0.75, 0.3, 19.0)
		coil.rotation = Vector3(0, 0, PI * 0.5)
		geo.add_child(coil)


## Armería: una mesa por arma del catálogo, en filas detrás de la línea de tiro.
func _build_armory(geo: Node3D) -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/catalog.json"))
	# Las recién llegadas van en una fila aparte, para probarlas por separado
	var fresh: Array = []
	for id: String in NEW_WEAPONS:
		if catalog.has(id):
			catalog.erase(id)
			fresh.append(id)
	var cols := 6
	var x0 := RANGE_X_MIN + 2.6
	var dx := (RANGE_X_MAX - RANGE_X_MIN - 5.2) / float(cols - 1)
	var z0 := RANGE_LINE_Z - 4.5
	for i in catalog.size():
		var t := WeaponTable.new()
		t.name = "Table_%s" % catalog[i]
		t.weapon_path = "res://data/weapons/%s.tres" % catalog[i]
		t.position = Vector3(x0 + (i % cols) * dx, 0, z0 - (i / cols) * 2.8)
		t.rotation = Vector3(0, PI, 0)
		geo.add_child(t)
	var rows := ceili(catalog.size() / float(cols))
	_sign(geo, Vector3((RANGE_X_MIN + RANGE_X_MAX) * 0.5, 3.6, z0 - (rows - 1) * 2.8 - 2.5), tr("greybox.armory"))
	# Fila aparte con las armas nuevas (y el dron en el piso)
	var zf := z0 - rows * 2.8 - 3.2
	for i in fresh.size():
		var t := WeaponTable.new()
		t.name = "Table_%s" % fresh[i]
		t.weapon_path = "res://data/weapons/%s.tres" % fresh[i]
		t.position = Vector3(x0 + i * dx, 0, zf)
		t.rotation = Vector3(0, PI, 0)
		geo.add_child(t)
	var drone := WorldItemScript.make("drone", 1) as WorldItem
	drone.name = "Item_drone"
	drone.position = Vector3(x0 + fresh.size() * dx, 0.3, zf)
	geo.add_child(drone)
	_sign(geo, Vector3(x0 + fresh.size() * dx * 0.5, 3.2, zf - 1.6), tr("greybox.new_weapons"))
	# Cajas de armas (miras, silenciadores, cargadores) a los costados de la armería
	for k in 2:
		var wc := LootContainerScript.new() as LootContainer
		wc.name = "WeaponsCrate%d" % k
		wc.kind = "weapons"
		wc.position = Vector3(RANGE_X_MIN + 0.9 if k == 0 else RANGE_X_MAX - 0.9, 0, z0 - 1.0)
		wc.rotation = Vector3(0, PI * 0.5, 0)
		geo.add_child(wc)


## Polígono de tiro, detrás del punto de aparición.
func _build_range(geo: Node3D) -> void:
	var cx := (RANGE_X_MIN + RANGE_X_MAX) * 0.5
	var width := RANGE_X_MAX - RANGE_X_MIN
	var length := RANGE_END_Z - 40.0
	# Piso de tierra apisonada y muros laterales
	var dirt := _grid_material(Color(0.42, 0.36, 0.28))
	_box(geo, Vector3(cx, -0.5, 40.0 + length * 0.5), Vector3(width, 1, length), dirt, true, "dirt")
	for x: float in [RANGE_X_MIN - 0.5, RANGE_X_MAX + 0.5]:
		_box(geo, Vector3(x, 1.5, 40.0 + length * 0.5), Vector3(1, 3, length), _mat_block)
	# Talud de tierra al fondo
	_box(geo, Vector3(cx, 3.0, RANGE_END_Z - 2.0), Vector3(width, 6, 4), dirt, true, "dirt")

	# Línea de tiro, cartel y caja de munición
	_box(geo, Vector3(cx, 0.012, RANGE_LINE_Z), Vector3(width, 0.02, 0.2), _mat_accent, false)
	_sign(geo, Vector3(cx, 4.2, RANGE_LINE_Z - 1.0), tr("greybox.range"))
	_label(geo, Vector3(cx, 0.35, RANGE_LINE_Z - 0.4), tr("greybox.firing_line"), 0.5)
	# Zonas de prueba entre la armería y la línea de tiro (se dispara desde ahí)
	var zones: Array = [["stress_medium", 21.75, Color(0.95, 0.72, 0.15), "greybox.zone_stress_medium"],
		["stress_high", 25.75, Color(0.92, 0.28, 0.18), "greybox.zone_stress_high"],
		["stress_extreme", 29.75, Color(0.7, 0.15, 0.55), "greybox.zone_stress_extreme"],
		["worn", 38.0, Color(0.55, 0.62, 0.7), "greybox.zone_worn"]]
	for zd: Array in zones:
		var z := TestZone.new()
		z.name = "Zone_" + String(zd[0])
		z.kind = zd[0]
		z.size = Vector2(3.5, 3.2)
		z.color = zd[2]
		z.title = tr(zd[3])
		z.position = Vector3(zd[1], 0, RANGE_LINE_Z - 2.2)
		geo.add_child(z)
	var crate := AmmoCrate.new()
	crate.name = "AmmoCrate"
	crate.position = Vector3(cx + 3.5, 0, RANGE_LINE_Z - 1.6)
	geo.add_child(crate)

	# Dianas: distancia (m) → tamaño de la cara (m), cada una en su carril
	var targets: Array = [[25.0, 0.6, RANGE_X_MIN + 3.0], [50.0, 0.8, RANGE_X_MIN + 8.0],
		[100.0, 1.2, RANGE_X_MIN + 15.0], [200.0, 1.8, RANGE_X_MIN + 21.0]]
	for t: Array in targets:
		var pt := PaperTarget.new()
		pt.name = "Target%dm" % int(t[0])
		pt.face_size = t[1]
		pt.position = Vector3(t[2], 0, RANGE_LINE_Z + float(t[0]))
		pt.rotation = Vector3(0, PI, 0)
		geo.add_child(pt)
		_label(geo, Vector3(t[2], 0.4, RANGE_LINE_Z + float(t[0]) - 1.0), "%d m" % int(t[0]), 0.8)

	# Maniquíes a 10 y 15 m, y uno a 30 m detrás de un murete
	var dummies: Array = [[Vector3(cx - 5.0, 0, RANGE_LINE_Z + 10.0), "Dummy10m"],
		[Vector3(cx + 5.0, 0, RANGE_LINE_Z + 15.0), "Dummy15m"],
		[Vector3(cx, 0, RANGE_LINE_Z + 30.0), "Dummy30m"]]
	for d: Array in dummies:
		var m := Mannequin.new()
		m.name = d[1]
		m.position = d[0]
		m.rotation = Vector3(0, PI, 0)
		geo.add_child(m)
	_box(geo, Vector3(cx, 0.5, RANGE_LINE_Z + 28.8), Vector3(2.0, 1.0, 0.3), _mat_block)
	# Cajas y barriles (modelo .glb) con colisión exacta, para cubrirse cerca de la línea
	_glb_prop(geo, "res://assets/models/props/crates_barrels/crates_barrels.glb", Vector3(20.6, 0, RANGE_LINE_Z + 6.5), 0.0, "wood")
	# Personajes de prueba (modelos .glb) en fila a 18 m: caen tiesos al morir
	var npcs: Array = [["fsb", 0.0], ["swat", 0.0], ["swat_remaster", 0.0], ["swat_special", 0.0]]
	var npc_x: Array = [20.5, 25.5, 30.5, 35.8]
	for i in npcs.size():
		var nd := NpcDummy.new()
		nd.name = "Npc_%s" % npcs[i][0]
		nd.scene_path = "res://assets/models/npc/%s/%s.glb" % [npcs[i][0], npcs[i][0]]
		nd.yaw_deg = npcs[i][1]
		nd.position = Vector3(npc_x[i], 0, RANGE_LINE_Z + 18.0)
		nd.rotation = Vector3(0, PI, 0)
		geo.add_child(nd)

	_build_penetration(geo)

	# Placa de acero inclinada: los tiros rasantes rebotan
	var plate := StaticBody3D.new()
	plate.name = "SteelPlate"
	plate.set_meta("surface", "metal")
	var pcs := CollisionShape3D.new()
	var psh := BoxShape3D.new()
	psh.size = Vector3(1.4, 1.4, 0.03)
	pcs.shape = psh
	plate.add_child(pcs)
	var pmi := MeshInstance3D.new()
	var pbm := BoxMesh.new()
	pbm.size = psh.size
	pmi.mesh = pbm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.32, 0.33, 0.35)
	pm.metallic = 0.8
	pm.roughness = 0.35
	pmi.material_override = pm
	plate.add_child(pmi)
	plate.position = Vector3(RANGE_X_MAX - 3.0, 1.0, RANGE_LINE_Z + 12.0)
	plate.rotation = Vector3(0, deg_to_rad(70), 0)
	geo.add_child(plate)
	_sign(geo, Vector3(RANGE_X_MAX - 3.0, 2.6, RANGE_LINE_Z + 12.0), tr("greybox.steel"))


## Estación de penetración: paneles de distinto material y espesor con una diana
## de papel detrás de cada uno para ver qué los atraviesa.
func _build_penetration(geo: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.45, 0.26)
	wood.roughness = 0.9
	var beam := StandardMaterial3D.new()
	beam.albedo_color = Color(0.45, 0.3, 0.17)
	beam.roughness = 0.9
	var sheet := StandardMaterial3D.new()
	sheet.albedo_color = Color(0.55, 0.57, 0.58)
	sheet.metallic = 0.7
	sheet.roughness = 0.45
	var z := RANGE_LINE_Z + 4.0
	# [x, espesor, material, superficie, texto]
	# A la izquierda del polígono, afuera del muro: no tapa ningún carril
	var panels: Array = [[9.0, 0.02, wood, "wood", "MADERA 2 cm"],
		[10.4, 0.001, sheet, "metal", "CHAPA 1 mm"],
		[11.8, 0.004, sheet, "metal", "CHAPA 4 mm"],
		[13.2, 0.2, beam, "wood", "VIGA 20 cm"]]
	for pd: Array in panels:
		var x: float = pd[0]
		var th: float = pd[1]
		var panel := _box(geo, Vector3(x, 1.35, z), Vector3(1.0, 1.3, th), pd[2], true, pd[3])
		panel.name = "Pen_" + String(pd[4]).replace(" ", "_")
		# Patas para que se lea como un panel parado
		for sx: float in [-0.45, 0.45]:
			_box(geo, Vector3(x + sx, 0.35, z + th * 0.5 + 0.03), Vector3(0.05, 0.7, 0.05), _mat_block, false)
		_label(geo, Vector3(x, 2.25, z), pd[4], 0.32)
		var pt := PaperTarget.new()
		pt.name = "PenTarget_%d" % int(x * 10.0)
		pt.face_size = 0.6
		pt.label_scale = 0.3
		pt.position = Vector3(x, 0.0, z + 2.5)
		pt.rotation = Vector3(0, PI, 0)
		geo.add_child(pt)
	_sign(geo, Vector3(11.1, 3.0, z), tr("greybox.penetration"))
	_box(geo, Vector3(11.1, 0.012, RANGE_LINE_Z), Vector3(6.0, 0.02, 0.2), _mat_accent, false)


# --- Helpers ----------------------------------------------------------------

func _grid_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GridShader
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("line_color", color.darkened(0.35))
	m.set_shader_parameter("major_color", color.darkened(0.55))
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, with_collision := true,
		surface := "concrete") -> Node3D:
	var root: Node3D
	if with_collision:
		var body := StaticBody3D.new()
		body.set_meta("surface", surface)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)
	root.position = pos
	parent.add_child(root)
	return root


## Rampa: caja inclinada cuyo borde bajo apoya en el piso.
func _ramp(parent: Node3D, base: Vector3, angle_deg: float, length: float, width: float) -> void:
	var a := deg_to_rad(angle_deg)
	var thick := 0.4
	var body := _box(parent, Vector3.ZERO, Vector3(width, thick, length), _mat_block)
	# Centro de la losa para que el borde inferior quede en base y suba hacia −Z.
	var half := length * 0.5
	body.position = base + Vector3(0, sin(a) * half - cos(a) * thick * 0.5, -cos(a) * half)
	body.rotation = Vector3(a, 0, 0)


func _label(parent: Node3D, pos: Vector3, text: String, px_size: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = px_size * 0.01
	l.font_size = 48
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.95, 0.93, 0.85)
	parent.add_child(l)


func _sign(parent: Node3D, pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = 0.009
	l.font_size = 64
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.modulate = Color(0.79, 0.64, 0.15)
	parent.add_child(l)


## Prop de un .glb con una colisión por malla (la forma exacta de cada pieza).
func _glb_prop(geo: Node3D, path: String, pos: Vector3, yaw: float, surface: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var body := StaticBody3D.new()
	body.name = path.get_file().get_basename().capitalize().replace(" ", "")
	body.set_meta("surface", surface)
	body.position = pos
	body.rotation = Vector3(0, yaw, 0)
	geo.add_child(body)
	var inst := GlbWeapon.scene(path).instantiate() as Node3D
	body.add_child(inst)
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != body:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		cs.transform = xf
		body.add_child(cs)

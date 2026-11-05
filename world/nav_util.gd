class_name NavUtil
extends RefCounted
## Malla de navegación de un nivel, armada en el momento a partir de la geometría con
## colisión (cuerpos estáticos de las capas 1 y 10 que cuelgan de los nodos del grupo
## "nav_source"). Los enemigos caminan por ella.

const GROUP := "nav_source"
const CELL := 0.25
const CELL_H := 0.25


## Crea la región y la arma. `area`: solo esa caja (vacía = todo). Con async = true no
## frena el juego (los enemigos se quedan quietos hasta que termina).
static func bake(parent: Node, area := AABB(), async := true, cell := CELL) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	var nm := NavigationMesh.new()
	# Una celda de radio (con más, las puertas de 1 m quedan cerradas en la malla)
	nm.agent_radius = cell
	nm.agent_height = 1.75
	nm.agent_max_climb = CELL_H * 2.0
	nm.agent_max_slope = 46.0
	nm.cell_size = cell
	nm.cell_height = CELL_H
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.5
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Mundo y alambrados (capa 10)
	nm.geometry_collision_mask = 1 | (1 << 9)
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = GROUP
	if area.size != Vector3.ZERO:
		nm.filter_baking_aabb = area
	region.navigation_mesh = nm
	parent.add_child(region)
	var map := region.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, cell)
	NavigationServer3D.map_set_cell_height(map, CELL_H)
	region.bake_navigation_mesh(async)
	return region


## La malla ya está lista para buscar caminos.
static func ready(node: Node) -> bool:
	return NavigationServer3D.map_get_iteration_id(node.get_viewport().find_world_3d().navigation_map) > 0

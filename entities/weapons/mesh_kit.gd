class_name MeshKit
extends RefCounted
## Generador de mallas para los modelos de armas hechos por código.
##
## Tres formas básicas, que se pueden acumular en una sola malla:
##  - prism(): perfil lateral (z, y) extruido a lo ancho (eje X). Sirve para
##    culatas, empuñaduras, receptores, guardamanos, cargadores…
##  - section(): sección transversal (x, y) extruida a lo largo (eje Z). Sirve
##    para tapas, correderas, rieles, guardamanos tubulares…
##  - lathe(): torno alrededor del eje Z. Caños, visores, bocachas, anillas…
##
## Los perfiles de prism/section son listas planas de tríos [a, b, r, a, b, r, …]:
## r es el radio de redondeo de esa esquina (0 = viva). Los bordes de la extrusión
## se redondean con "bevel". El torno recibe pares [z, r, z, r, …] recorriendo el
## contorno con el sólido a la derecha (de adelante hacia atrás por afuera).

const SMOOTH_COS := 0.78  # ~38°: por debajo, la arista se ve viva
const BEVEL_STEPS := 2

var _st := SurfaceTool.new()
var _empty := true


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func is_empty() -> bool:
	return _empty


func commit() -> ArrayMesh:
	return _st.commit()


# --- API ---------------------------------------------------------------------

## Perfil lateral (z, y, r) extruido en X, centrado en x = 0 con ancho "width".
func prism(points: Array, width: float, bevel := 0.002, xf := Transform3D.IDENTITY) -> MeshKit:
	_extrude(_fillet(points), -width * 0.5, width * 0.5, bevel, 0, xf)
	return self


## Sección (x, y, r) extruida a lo largo de Z, de z0 a z1.
func section(points: Array, z0: float, z1: float, bevel := 0.002, xf := Transform3D.IDENTITY) -> MeshKit:
	_extrude(_fillet(points), minf(z0, z1), maxf(z0, z1), bevel, 1, xf)
	return self


## Caja con todas las aristas redondeadas.
func box(center: Vector3, size: Vector3, round_r := 0.0015, xf := Transform3D.IDENTITY) -> MeshKit:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var r := minf(round_r, minf(hx, hy) * 0.9)
	var pts := [-hx, -hy, r, hx, -hy, r, hx, hy, r, -hx, hy, r]
	var t := xf * Transform3D(Basis.IDENTITY, center)
	return section(pts, -size.z * 0.5, size.z * 0.5, minf(r, size.z * 0.4), t)


## Torno alrededor del eje Z. "points": [z, r, …] con el sólido a la derecha del
## recorrido (por afuera de adelante hacia atrás). Se cierra solo contra el eje.
func lathe(points: Array, segments := 16, xf := Transform3D.IDENTITY, phase := 0.0) -> MeshKit:
	var p := PackedVector2Array()
	for i in range(0, points.size(), 2):
		p.append(Vector2(points[i], points[i + 1]))
	var n := p.size()
	if n < 2:
		return self
	# Normal de cada tramo: el tramo (dz, dr) gira a (−dr, dz)
	var seg_n: Array[Vector2] = []
	for i in n - 1:
		var e := p[i + 1] - p[i]
		seg_n.append(Vector2(-e.y, e.x).normalized() if e.length() > 1e-7 else Vector2(0, 1))
	for i in n - 1:
		var a := p[i]
		var b := p[i + 1]
		if a.y < 1e-6 and b.y < 1e-6:
			continue
		var na := _lathe_vertex_normal(seg_n, i, true)
		var nb := _lathe_vertex_normal(seg_n, i, false)
		for k in segments:
			var f0 := phase + TAU * k / segments
			var f1 := phase + TAU * (k + 1) / segments
			var v00 := Vector3(a.y * cos(f0), a.y * sin(f0), a.x)
			var v10 := Vector3(b.y * cos(f0), b.y * sin(f0), b.x)
			var v11 := Vector3(b.y * cos(f1), b.y * sin(f1), b.x)
			var v01 := Vector3(a.y * cos(f1), a.y * sin(f1), a.x)
			var n00 := Vector3(na.y * cos(f0), na.y * sin(f0), na.x)
			var n10 := Vector3(nb.y * cos(f0), nb.y * sin(f0), nb.x)
			var n11 := Vector3(nb.y * cos(f1), nb.y * sin(f1), nb.x)
			var n01 := Vector3(na.y * cos(f1), na.y * sin(f1), na.x)
			# Los triángulos degenerados (puntas sobre el eje) se descartan solos
			_tri(xf, v00, v10, v11, n00, n10, n11)
			_tri(xf, v00, v11, v01, n00, n11, n01)
	return self


# --- Interno -------------------------------------------------------------------

func _lathe_vertex_normal(seg_n: Array[Vector2], i: int, start: bool) -> Vector2:
	var own := seg_n[i]
	var j := i - 1 if start else i + 1
	if j < 0 or j >= seg_n.size():
		return own
	if own.dot(seg_n[j]) > SMOOTH_COS:
		return (own + seg_n[j]).normalized()
	return own


## Redondea las esquinas con radio > 0 (curva cuadrática entre los puntos de tangencia).
static func _fillet(points: Array) -> PackedVector2Array:
	var src: Array[Vector3] = []
	for i in range(0, points.size(), 3):
		src.append(Vector3(points[i], points[i + 1], points[i + 2]))
	var n := src.size()
	var out := PackedVector2Array()
	for i in n:
		var p := Vector2(src[i].x, src[i].y)
		var r := src[i].z
		if r <= 0.0:
			out.append(p)
			continue
		var a := Vector2(src[(i - 1 + n) % n].x, src[(i - 1 + n) % n].y)
		var c := Vector2(src[(i + 1) % n].x, src[(i + 1) % n].y)
		var d1 := a - p
		var d2 := c - p
		var l1 := d1.length()
		var l2 := d2.length()
		if l1 < 1e-6 or l2 < 1e-6:
			out.append(p)
			continue
		d1 /= l1
		d2 /= l2
		var ang := acos(clampf(d1.dot(d2), -1.0, 1.0))
		if ang > PI - 0.02:
			out.append(p)
			continue
		var t := minf(r / tan(ang * 0.5), minf(l1, l2) * 0.48)
		var p1 := p + d1 * t
		var p2 := p + d2 * t
		var steps := 4 if r > 0.006 else 3
		for k in steps + 1:
			var s := float(k) / steps
			out.append(p1.lerp(p, s).lerp(p.lerp(p2, s), s))
	return out


## Extrusión con bisel redondeado. mode 0: perfil (z, y) a lo ancho (X);
## mode 1: sección (x, y) a lo largo (Z).
func _extrude(poly: PackedVector2Array, d0: float, d1: float, bevel: float, mode: int, xf: Transform3D) -> void:
	poly = _clean(poly)
	var n := poly.size()
	if n < 3:
		return
	if _area(poly) < 0.0:
		poly.reverse()
	# Normales hacia afuera de cada arista (polígono antihorario)
	var en: Array[Vector2] = []
	for i in n:
		var e := poly[(i + 1) % n] - poly[i]
		en.append(Vector2(e.y, -e.x).normalized())
	var vn: Array[Vector2] = []  # normal promediada por vértice
	var smooth: Array[bool] = []
	var miter: Array[Vector2] = []
	for i in n:
		var a := en[(i - 1 + n) % n]
		var b := en[i]
		smooth.append(a.dot(b) > SMOOTH_COS)
		var m := (a + b).normalized()
		vn.append(m)
		miter.append(m / maxf(m.dot(b), 0.3))
	var b := clampf(bevel, 0.0, (d1 - d0) * 0.45)
	var cap := poly
	if b > 0.0:
		cap = PackedVector2Array()
		for i in n:
			cap.append(poly[i] - miter[i] * b)
		if Geometry2D.triangulate_polygon(cap).is_empty() or _area(cap) <= 0.0:
			b = 0.0
			cap = poly
	var steps := BEVEL_STEPS if b > 0.0 else 0
	# Anillos de cada lado: (inset, w, lateral, axial)
	for side: int in [1, -1]:
		var rings: Array = []
		for j in steps + 1:
			var th := (PI * 0.5) * (float(j) / steps) if steps > 0 else PI * 0.5
			var s := b * (1.0 - sin(th))
			var w := (d1 - b + b * cos(th)) if side > 0 else (d0 + b - b * cos(th))
			rings.append([s, w, sin(th), cos(th) * side])
		for j in steps:
			_strip(poly, en, vn, smooth, miter, rings[j], rings[j + 1], mode, xf)
		# Tapa
		var w_cap: float = rings[0][1]
		var idx := Geometry2D.triangulate_polygon(cap)
		var nrm := _map(Vector3(0, 0, side), mode)
		for t in range(0, idx.size(), 3):
			var va := _map(Vector3(cap[idx[t]].x, cap[idx[t]].y, w_cap), mode)
			var vb := _map(Vector3(cap[idx[t + 1]].x, cap[idx[t + 1]].y, w_cap), mode)
			var vc := _map(Vector3(cap[idx[t + 2]].x, cap[idx[t + 2]].y, w_cap), mode)
			_tri(xf, va, vb, vc, nrm, nrm, nrm)
	# Paredes
	var wall_a := [0.0, d1 - b, 1.0, 0.0]
	var wall_b := [0.0, d0 + b, 1.0, 0.0]
	_strip(poly, en, vn, smooth, miter, wall_a, wall_b, mode, xf)


## Banda entre dos anillos (inset, w, lateral, axial).
func _strip(poly: PackedVector2Array, en: Array[Vector2], vn: Array[Vector2], smooth: Array[bool],
		miter: Array[Vector2], ra: Array, rb: Array, mode: int, xf: Transform3D) -> void:
	var n := poly.size()
	for i in n:
		var i2 := (i + 1) % n
		var na := vn[i] if smooth[i] else en[i]
		var nb := vn[i2] if smooth[i2] else en[i]
		var pa0 := poly[i] - miter[i] * float(ra[0])
		var pb0 := poly[i2] - miter[i2] * float(ra[0])
		var pa1 := poly[i] - miter[i] * float(rb[0])
		var pb1 := poly[i2] - miter[i2] * float(rb[0])
		var v0 := _map(Vector3(pa0.x, pa0.y, ra[1]), mode)
		var v1 := _map(Vector3(pb0.x, pb0.y, ra[1]), mode)
		var v2 := _map(Vector3(pb1.x, pb1.y, rb[1]), mode)
		var v3 := _map(Vector3(pa1.x, pa1.y, rb[1]), mode)
		var n0 := _map(Vector3(na.x * ra[2], na.y * ra[2], ra[3]), mode).normalized()
		var n1 := _map(Vector3(nb.x * ra[2], nb.y * ra[2], ra[3]), mode).normalized()
		var n2 := _map(Vector3(nb.x * rb[2], nb.y * rb[2], rb[3]), mode).normalized()
		var n3 := _map(Vector3(na.x * rb[2], na.y * rb[2], rb[3]), mode).normalized()
		_tri(xf, v0, v1, v2, n0, n1, n2)
		_tri(xf, v0, v2, v3, n0, n2, n3)


## (u, v, w) del espacio del perfil → (x, y, z) del modelo.
static func _map(v: Vector3, mode: int) -> Vector3:
	return Vector3(v.z, v.y, v.x) if mode == 0 else v


## Triángulo con normales explícitas; corrige el orden para que la cara
## visible sea la que mira hacia la normal (Godot: horario = frente).
func _tri(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	var nbasis := xf.basis.inverse().transposed()
	na = (nbasis * na).normalized()
	nb = (nbasis * nb).normalized()
	nc = (nbasis * nc).normalized()
	var g := (b - a).cross(c - a)
	if g.length_squared() < 1e-16:
		return
	if g.dot(na + nb + nc) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	_st.set_normal(na)
	_st.add_vertex(a)
	_st.set_normal(nb)
	_st.add_vertex(b)
	_st.set_normal(nc)
	_st.add_vertex(c)
	_empty = false


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## Quita puntos repetidos consecutivos.
static func _clean(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in p.size():
		if out.is_empty() or out[out.size() - 1].distance_to(p[i]) > 1e-6:
			out.append(p[i])
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) < 1e-6:
		out.remove_at(out.size() - 1)
	return out

extends Control

## Square icon for a combat action, drawn with vector shapes so every skill has its own
## picture without needing art files. If `res://assets/skills/<id>.png` exists it is
## drawn instead (drop-in for painted art later).
##
## Background colour = kind (attack red, heal green, buff blue, guard steel, pass grey);
## the glyph says what the skill is (machete, boot, drone, candle…).

const GLYPHS := {
	"machetazo": "machete",
	"cucharonazo": "ladle",
	"corrientazo": "bolt",
	"mecatazo": "lasso",
	"trabajo_duro": "fist",
	"sopa_milagrosa": "pot",
	"dron_casero": "drone",
	"entrada_brava": "horns",
	"golpe_de_faena": "hammer",
	"aguante_de_campo": "heart",
	"regano_santo": "speech",
	"cataplasma_casero": "leaf",
	"exploit_zero_day": "bug",
	"firewall_humano": "wall",
	"patada_de_corral": "boot",
	"no_me_tumban": "shout",
	"silbatazo": "whistle",
	"reten": "baton",
	"ronda_nocturna": "flashlight",
	"escudo_de_barrio": "shield_ally",
	"bisturi": "scalpel",
	"triage_urbano": "medcross",
	"antibiotico_de_guardia": "pill",
	"desfibrilar": "bolt",
	"deuda_espiritual": "skull",
	"rezo_de_nicoya": "candle",
	"humo_de_hierbas": "smoke",
	"limpia_de_mal_de_ojo": "eye",
	"expulsion": "cross",
	"liturgia_de_hierro": "rosary",
	"sal_de_proteccion": "salt",
	"circulo_de_tiza": "chalk",
	"_guard": "shield",
	"_move": "move",
	"_pass": "hourglass",
	"_items": "bag",
}

const BG := {
	"attack": Color(0.42, 0.1, 0.09),
	"heal": Color(0.12, 0.32, 0.15),
	"buff": Color(0.12, 0.22, 0.4),
	"guard": Color(0.26, 0.29, 0.33),
	"pass": Color(0.22, 0.21, 0.2),
	"item": Color(0.36, 0.24, 0.1),
}

const INK := Color(0.96, 0.9, 0.76)
const DARK := Color(0.1, 0.07, 0.06)

var skill_id: String = ""
var kind: String = "attack"
var label: String = ""
var _art: Texture2D = null


func setup(p_skill_id: String, p_kind: String, p_label: String = "") -> void:
	skill_id = p_skill_id
	kind = p_kind
	label = p_label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/skills/%s.png" % p_skill_id
	_art = load(path) as Texture2D if ResourceLoader.exists(path) else null
	queue_redraw()


func _p(x: float, y: float) -> Vector2:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	return o + Vector2(x, y) * s


func _w(t: float) -> float:
	return t * minf(size.x, size.y)


func _poly(pts: Array, c: Color = INK) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(q[0], q[1]))
	draw_colored_polygon(out, c)


func _line(a: Array, b: Array, w: float, c: Color = INK) -> void:
	draw_line(_p(a[0], a[1]), _p(b[0], b[1]), c, _w(w), true)


func _circle(x: float, y: float, r: float, c: Color = INK) -> void:
	draw_circle(_p(x, y), _w(r), c)


func _ring(x: float, y: float, r: float, w: float, c: Color = INK, from: float = 0.0, to: float = TAU) -> void:
	draw_arc(_p(x, y), _w(r), from, to, 32, c, _w(w), true)


func _rect(x0: float, y0: float, x1: float, y1: float, c: Color = INK) -> void:
	draw_rect(Rect2(_p(x0, y0), _p(x1, y1) - _p(x0, y0)), c)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG.get(kind, BG["attack"])
	sb.set_corner_radius_all(int(_w(0.12)))
	sb.border_color = sb.bg_color.lightened(0.35)
	sb.set_border_width_all(1)
	draw_style_box(sb, r)
	if _art != null:
		draw_texture_rect(_art, r.grow(-2), false)
		return
	var g: String = str(GLYPHS.get(skill_id, ""))
	if g == "" or not has_method("_g_" + g):
		_letter()
		return
	call("_g_" + g)


func _letter() -> void:
	var f: Font = get_theme_default_font()
	var txt: String = (label if label != "" else skill_id).substr(0, 1).to_upper()
	var fs: int = int(_w(0.55))
	var ts: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(f, Vector2((size.x - ts.x) * 0.5, (size.y + ts.y * 0.6) * 0.5), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, INK)


# --- Glyphs (unit square, y down) -----------------------------------------------------

func _g_bag() -> void:
	# Leather saddlebag: body, flap, buckle and strap.
	_poly([[0.20, 0.38], [0.80, 0.38], [0.84, 0.82], [0.16, 0.82]], Color(0.62, 0.4, 0.2))
	_poly([[0.18, 0.36], [0.82, 0.36], [0.76, 0.58], [0.24, 0.58]], Color(0.75, 0.5, 0.26))
	_line([0.34, 0.36], [0.40, 0.18], 0.06, INK)
	_line([0.40, 0.18], [0.60, 0.18], 0.06, INK)
	_line([0.60, 0.18], [0.66, 0.36], 0.06, INK)
	_poly([[0.45, 0.52], [0.55, 0.52], [0.55, 0.64], [0.45, 0.64]], INK)


func _g_machete() -> void:
	_poly([[0.30, 0.62], [0.74, 0.16], [0.88, 0.14], [0.86, 0.28], [0.40, 0.72]])
	_line([0.36, 0.66], [0.16, 0.86], 0.11, Color(0.55, 0.36, 0.2))
	_line([0.27, 0.60], [0.42, 0.75], 0.05)


func _g_fist() -> void:
	_rect(0.27, 0.26, 0.73, 0.6)
	for x in [0.385, 0.5, 0.615]:
		_line([x, 0.27], [x, 0.44], 0.03, DARK)
	_line([0.27, 0.44], [0.6, 0.44], 0.03, DARK)
	_rect(0.35, 0.6, 0.65, 0.86)


func _g_pot() -> void:
	_poly([[0.2, 0.48], [0.8, 0.48], [0.74, 0.82], [0.26, 0.82]])
	_rect(0.14, 0.42, 0.86, 0.5)
	for x in [0.36, 0.5, 0.64]:
		_line([x, 0.34], [x + 0.04, 0.24], 0.03)
		_line([x + 0.04, 0.24], [x, 0.14], 0.03)


func _g_drone() -> void:
	_line([0.24, 0.34], [0.42, 0.5], 0.05)
	_line([0.76, 0.34], [0.58, 0.5], 0.05)
	_rect(0.38, 0.44, 0.62, 0.62)
	_ring(0.24, 0.32, 0.13, 0.04)
	_ring(0.76, 0.32, 0.13, 0.04)
	_circle(0.5, 0.72, 0.06)
	_circle(0.5, 0.72, 0.03, DARK)


func _g_horns() -> void:
	_circle(0.5, 0.64, 0.2)
	_poly([[0.36, 0.52], [0.12, 0.4], [0.1, 0.14], [0.22, 0.34], [0.42, 0.44]])
	_poly([[0.64, 0.52], [0.88, 0.4], [0.9, 0.14], [0.78, 0.34], [0.58, 0.44]])
	_circle(0.42, 0.62, 0.035, DARK)
	_circle(0.58, 0.62, 0.035, DARK)


func _g_hammer() -> void:
	_rect(0.18, 0.14, 0.82, 0.38)
	_rect(0.44, 0.38, 0.56, 0.9)


func _g_heart() -> void:
	_circle(0.36, 0.4, 0.17)
	_circle(0.64, 0.4, 0.17)
	_poly([[0.2, 0.46], [0.8, 0.46], [0.5, 0.84]])


func _g_speech() -> void:
	_rect(0.14, 0.18, 0.86, 0.64)
	_poly([[0.3, 0.62], [0.46, 0.62], [0.24, 0.84]])
	_rect(0.46, 0.25, 0.54, 0.47, DARK)
	_rect(0.46, 0.52, 0.54, 0.58, DARK)


func _g_leaf() -> void:
	_poly([[0.18, 0.82], [0.2, 0.5], [0.34, 0.28], [0.58, 0.16], [0.86, 0.14], [0.82, 0.42], [0.66, 0.66], [0.44, 0.78]])
	_line([0.16, 0.86], [0.7, 0.3], 0.03, DARK)


func _g_bug() -> void:
	for y in [0.46, 0.6, 0.74]:
		_line([0.32, y], [0.14, y - 0.08], 0.04)
		_line([0.68, y], [0.86, y - 0.08], 0.04)
	_circle(0.5, 0.6, 0.2)
	_circle(0.5, 0.33, 0.1)
	_line([0.46, 0.25], [0.36, 0.12], 0.03)
	_line([0.54, 0.25], [0.64, 0.12], 0.03)
	_line([0.5, 0.44], [0.5, 0.78], 0.03, DARK)


func _g_wall() -> void:
	var y0 := 0.2
	for row in 4:
		var y: float = y0 + row * 0.16
		var off: float = 0.0 if row % 2 == 0 else 0.12
		var x: float = 0.12 - off
		while x < 0.88:
			_rect(maxf(x, 0.12) + 0.01, y + 0.01, minf(x + 0.24, 0.88) - 0.01, y + 0.15)
			x += 0.25


func _g_boot() -> void:
	_poly([[0.34, 0.12], [0.58, 0.12], [0.58, 0.56], [0.84, 0.64], [0.88, 0.82], [0.3, 0.82]])
	_rect(0.3, 0.78, 0.88, 0.86, Color(0.55, 0.36, 0.2))


func _g_shout() -> void:
	_poly([[0.12, 0.4], [0.36, 0.4], [0.62, 0.2], [0.62, 0.8], [0.36, 0.6], [0.12, 0.6]])
	_ring(0.62, 0.5, 0.14, 0.035, INK, -0.9, 0.9)
	_ring(0.62, 0.5, 0.26, 0.035, INK, -0.9, 0.9)


func _g_whistle() -> void:
	_circle(0.38, 0.6, 0.2)
	_rect(0.42, 0.42, 0.88, 0.56)
	_circle(0.38, 0.6, 0.07, DARK)
	_line([0.74, 0.3], [0.86, 0.18], 0.03)
	_line([0.62, 0.3], [0.64, 0.14], 0.03)


func _g_baton() -> void:
	# Police tonfa: long shaft with a short side grip.
	_line([0.22, 0.82], [0.82, 0.22], 0.11)
	_line([0.34, 0.7], [0.46, 0.84], 0.08)
	_circle(0.47, 0.85, 0.045)


func _g_flashlight() -> void:
	_poly([[0.6, 0.36], [0.94, 0.16], [0.94, 0.84], [0.6, 0.64]], Color(1, 0.92, 0.55, 0.45))
	_rect(0.1, 0.42, 0.48, 0.58)
	_poly([[0.48, 0.38], [0.62, 0.32], [0.62, 0.68], [0.48, 0.62]])


func _g_shield() -> void:
	_poly([[0.5, 0.1], [0.85, 0.22], [0.8, 0.6], [0.5, 0.9], [0.2, 0.6], [0.15, 0.22]])
	_line([0.5, 0.18], [0.5, 0.8], 0.06, DARK)


func _g_shield_ally() -> void:
	_poly([[0.5, 0.1], [0.85, 0.22], [0.8, 0.6], [0.5, 0.9], [0.2, 0.6], [0.15, 0.22]])
	_rect(0.45, 0.28, 0.55, 0.66, DARK)
	_rect(0.31, 0.42, 0.69, 0.52, DARK)


func _g_scalpel() -> void:
	_line([0.14, 0.86], [0.5, 0.5], 0.08)
	_poly([[0.48, 0.46], [0.86, 0.12], [0.62, 0.56]], Color(0.85, 0.88, 0.92))


func _g_medcross() -> void:
	_rect(0.39, 0.14, 0.61, 0.86)
	_rect(0.14, 0.39, 0.86, 0.61)


func _g_pill() -> void:
	_line([0.3, 0.7], [0.5, 0.5], 0.24)
	_line([0.5, 0.5], [0.7, 0.3], 0.24, Color(0.9, 0.45, 0.4))
	_circle(0.3, 0.7, 0.12)
	_circle(0.7, 0.3, 0.12, Color(0.9, 0.45, 0.4))


func _g_move() -> void:
	# Two arrows passing each other: swap places with a neighbour.
	_line([0.16, 0.36], [0.74, 0.36], 0.07)
	_poly([[0.70, 0.22], [0.88, 0.36], [0.70, 0.50]])
	_line([0.84, 0.66], [0.26, 0.66], 0.07)
	_poly([[0.30, 0.52], [0.12, 0.66], [0.30, 0.80]])


func _g_ladle() -> void:
	# Wooden cooking ladle (cucharón): long handle, deep round bowl, motion lines.
	var wood := Color(0.72, 0.5, 0.28)
	_line([0.78, 0.12], [0.44, 0.52], 0.08, wood)
	_circle(0.34, 0.64, 0.19, wood)
	_circle(0.34, 0.62, 0.12, Color(0.42, 0.27, 0.14))
	_ring(0.34, 0.64, 0.19, 0.025, INK)
	_line([0.66, 0.6], [0.82, 0.56], 0.03)
	_line([0.62, 0.72], [0.8, 0.74], 0.03)


func _g_lasso() -> void:
	# Ranch rope (mecate): a big loop with the running end lashing out.
	_ring(0.42, 0.42, 0.24, 0.055)
	_ring(0.42, 0.42, 0.24, 0.02, DARK, 0.6, 1.4)
	_line([0.58, 0.6], [0.72, 0.76], 0.055)
	_line([0.72, 0.76], [0.88, 0.7], 0.05)
	_line([0.86, 0.56], [0.94, 0.5], 0.025)
	_line([0.9, 0.66], [0.97, 0.66], 0.025)


func _g_bolt() -> void:
	_poly([[0.58, 0.08], [0.24, 0.56], [0.46, 0.56], [0.38, 0.92], [0.76, 0.4], [0.54, 0.4], [0.66, 0.08]], Color(1, 0.88, 0.4))


func _g_skull() -> void:
	_circle(0.5, 0.42, 0.27)
	_rect(0.37, 0.58, 0.63, 0.8)
	_circle(0.4, 0.42, 0.075, DARK)
	_circle(0.6, 0.42, 0.075, DARK)
	_poly([[0.5, 0.52], [0.46, 0.6], [0.54, 0.6]], DARK)
	for x in [0.44, 0.5, 0.56]:
		_line([x, 0.68], [x, 0.8], 0.02, DARK)


func _g_candle() -> void:
	_rect(0.39, 0.42, 0.61, 0.86)
	_rect(0.3, 0.84, 0.7, 0.9)
	_poly([[0.5, 0.12], [0.6, 0.3], [0.5, 0.38], [0.4, 0.3]], Color(1, 0.78, 0.3))
	_line([0.5, 0.36], [0.5, 0.42], 0.02, DARK)


func _g_smoke() -> void:
	for k in 3:
		var x: float = 0.3 + k * 0.2
		var pts := PackedVector2Array()
		for i in 13:
			var t: float = i / 12.0
			pts.append(_p(x + 0.06 * sin(t * TAU * 1.2 + k), 0.86 - t * 0.7))
		draw_polyline(pts, INK, _w(0.05), true)


func _g_eye() -> void:
	var pts: Array = []
	for i in 17:
		var t: float = i / 16.0
		pts.append([0.1 + 0.8 * t, 0.5 - 0.26 * sin(t * PI)])
	for i in range(15, 0, -1):
		var t: float = i / 16.0
		pts.append([0.1 + 0.8 * t, 0.5 + 0.26 * sin(t * PI)])
	_poly(pts)
	_circle(0.5, 0.5, 0.16, Color(0.25, 0.45, 0.6))
	_circle(0.5, 0.5, 0.07, DARK)


func _g_cross() -> void:
	_rect(0.43, 0.1, 0.57, 0.9)
	_rect(0.22, 0.28, 0.78, 0.42)


func _g_rosary() -> void:
	for i in 14:
		var a: float = PI * 0.5 + 0.35 + i * (TAU - 0.7) / 13.0
		_circle(0.5 + 0.3 * cos(a), 0.4 + 0.26 * sin(a), 0.04)
	_rect(0.47, 0.64, 0.53, 0.92)
	_rect(0.39, 0.72, 0.61, 0.77)


func _g_salt() -> void:
	for i in 14:
		var a: float = i * TAU / 14.0
		_circle(0.5 + 0.34 * cos(a), 0.5 + 0.34 * sin(a), 0.035)
	_circle(0.5, 0.36, 0.08)
	_poly([[0.38, 0.66], [0.5, 0.44], [0.62, 0.66]])


func _g_chalk() -> void:
	for i in 8:
		var a: float = i * TAU / 8.0
		_ring(0.5, 0.5, 0.34, 0.04, INK, a, a + TAU / 16.0)
	var star: Array = []
	for i in 10:
		var a: float = -PI * 0.5 + i * PI / 5.0
		var rr: float = 0.2 if i % 2 == 0 else 0.08
		star.append([0.5 + rr * cos(a), 0.5 + rr * sin(a)])
	_poly(star)


func _g_hourglass() -> void:
	_rect(0.24, 0.12, 0.76, 0.18)
	_rect(0.24, 0.82, 0.76, 0.88)
	_poly([[0.3, 0.18], [0.7, 0.18], [0.5, 0.5]])
	_poly([[0.5, 0.5], [0.7, 0.82], [0.3, 0.82]])

extends RefCounted
# EMENDAR ANIMAÇÕES (1.14.5): algumas animações em ciclo (convertidas de captura de movimento) não emendam o fim no
# começo: a cada volta o corpo dava um pulo. O pior era "mirar_fuzil" (mirando com fuzil parado): a cada 1,6 s a
# cabeça pulava 5,8 cm (o começo da captura estava noutra postura) e a respiração subia/descia o peito 3,4 cm: a mira
# e o personagem TREMIAM. Aqui, uma vez quando o jogo carrega a biblioteca (jogador/modelo_sobrevivente.gd):
#   cortar    · tira os primeiros segundos ruins (a animação começa depois deles);
#   fundir    · nos últimos segundos a pose vai indo para a do começo (a volta fica sem pulo);
#   amortecer · 0..1: quanto do movimento fica (1 = todo; 0,35 = a respiração fica com 35%, a mira firme).
# Os arquivos de animação não mudam (o conserto é feito na memória). Mexa AQUI para: quais animações e quanto.
# (medido com o diagnóstico de ciclos: pulo da cabeça na volta, em metros)

const CONSERTOS := {
	"mirar_fuzil": {"cortar": 0.3, "fundir": 0.35, "amortecer": 0.35},   # 5,8 cm + respiração forte
	"andar_espreita": {"fundir": 0.25},                                   # 3,9 cm
	"mancar": {"fundir": 0.25},                                           # 3,1 cm
	"correr_fuzil": {"fundir": 0.15},                                     # 1,1 cm
	"trote": {"fundir": 0.12},                                            # 0,9 cm
}
const FPS := 30.0

static func consertar(lib: AnimationLibrary) -> void:
	if lib == null or lib.has_meta("emendada"):
		return
	lib.set_meta("emendada", true)
	for nome in CONSERTOS:
		if lib.has_animation(nome):
			_emendar(lib.get_animation(nome), CONSERTOS[nome])

static func _emendar(an: Animation, c: Dictionary) -> void:
	var cortar: float = c.get("cortar", 0.0)
	var fundir: float = c.get("fundir", 0.2)
	var amortecer: float = c.get("amortecer", 1.0)
	var L := an.length - cortar
	if L <= fundir + 0.1:
		return
	var n := int(round(L * FPS))
	for i in an.get_track_count():
		var tipo := an.track_get_type(i)
		if tipo != Animation.TYPE_ROTATION_3D and tipo != Animation.TYPE_POSITION_3D:
			continue
		if an.track_is_compressed(i) or an.track_get_key_count(i) < 2:
			continue
		var rot := tipo == Animation.TYPE_ROTATION_3D
		# amostras novas (do trecho depois do corte), com a respiração reduzida em volta da pose do meio
		var ref = an.rotation_track_interpolate(i, cortar + L * 0.5) if rot else an.position_track_interpolate(i, cortar + L * 0.5)
		var vals: Array = []
		for k in n + 1:
			var t := minf(k / FPS, L)
			var v = an.rotation_track_interpolate(i, cortar + t) if rot else an.position_track_interpolate(i, cortar + t)
			if amortecer < 1.0:
				v = (ref as Quaternion).slerp(v, amortecer) if rot else (ref as Vector3).lerp(v, amortecer)
			vals.append(v)
		# os últimos "fundir" segundos vão indo para a pose do começo: a volta emenda sem pulo
		var v0 = vals[0]
		for k in n + 1:
			var t := minf(k / FPS, L)
			if t > L - fundir:
				var w := smoothstep(0.0, 1.0, (t - (L - fundir)) / fundir)
				vals[k] = (vals[k] as Quaternion).slerp(v0, w) if rot else (vals[k] as Vector3).lerp(v0, w)
		for k in range(an.track_get_key_count(i) - 1, -1, -1):
			an.track_remove_key(i, k)
		for k in n + 1:
			var t := minf(k / FPS, L)
			if rot:
				an.rotation_track_insert_key(i, t, (vals[k] as Quaternion).normalized())
			else:
				an.position_track_insert_key(i, t, vals[k])
	an.length = L

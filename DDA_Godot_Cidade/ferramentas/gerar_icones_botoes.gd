extends SceneTree
# GERA A FOLHA DE ÍCONES DOS BOTÕES DE TOQUE (0.67): hud/icones/botoes.png, 8 colunas de 128 px.
# Os ícones vêm do pacote game-icons.net (CC BY 3.0; autores em hud/icones/LICENCA.txt), baixado em SVG branco com
# fundo transparente: https://game-icons.net/archives/svg/zip/ffffff/transparent/game-icons.net.svg.zip
# Tudo numa imagem só: os botões são desenhados com a MESMA textura (um lote só no celular).
# A ORDEM tem que ser a mesma de ICONES em jogador/controles.gd.
# Rodar, dentro da pasta DDA_Godot_Cidade (a pasta é a ".../icons/ffffff/transparent/1x1" do zip extraído):
#   godot --headless -s ferramentas/gerar_icones_botoes.gd -- <pasta_dos_svgs>
#   godot --headless --import
# Esta pasta (ferramentas/) não vai para o APK.

# [nome no jogo, ícone (autor/nome), girar 180°]
const LISTA := [
	["PAUSA", "guard13007/pause-button", false],
	["INV", "delapouite/backpack", false],
	["VOO", "delapouite/delivery-drone", false],
	["CAM", "delapouite/video-camera", false],
	["MIRAR", "delapouite/crosshair", false],
	["ATIRAR", "lorc/bullets", false],
	["PULAR", "delapouite/jump-across", false],
	["CORRER", "lorc/run", false],
	["AGACHAR", "delapouite/kneeling", false],
	["RECARREGAR", "delapouite/reload-gun-barrel", false],
	["PEGAR", "skoll/open-palm", false],
	["SOBE", "delapouite/plain-arrow", true],
	["DESCE", "delapouite/plain-arrow", false],
	["VEL", "delapouite/speedometer", false],
	["pistola", "john-colburn/pistol-gun", false],
	["m4", "skoll/ak47", false],
	["mp5", "delapouite/uzi", false],
	["ak", "skoll/ak47", false],
	["espingarda", "delapouite/sawed-off-shotgun", false],
	["rifle_caca", "skoll/winchester-rifle", false],
	["faca", "lorc/bowie-knife", false],
	["taco", "delapouite/baseball-bat", false],
	["machado", "delapouite/sharp-axe", false],
	["cano", "delapouite/lead-pipe", false],
	["lanca", "lorc/stone-spear", false],
	["facao", "lorc/machete", false],
	["pe_de_cabra", "delapouite/crowbar", false],
	["punhos", "lorc/fist", false],
	["MSG", "delapouite/chat-bubble", false],      # 0.71: mensagens rápidas (multijogador)
	["EMPURRAR", "delapouite/push", false],        # 0.90: empurrão / pisão
	["CONSTRUIR", "lorc/hammer-nails", false],     # 0.90: construir base
	["GIRAR", "delapouite/anticlockwise-rotation", false],
	["OK", "delapouite/check-mark", false],
	["CANCELAR", "sbed/cancel", false],
]
const CEL := 128
const ICONE := 112                     # sobra uma borda vazia: as mipmaps não "vazam" para o vizinho
const COLUNAS := 8

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		push_error("passe a pasta dos SVGs do game-icons.net")
		quit(1)
		return
	var linhas := int(ceil(LISTA.size() / float(COLUNAS)))
	var folha := Image.create(CEL * COLUNAS, CEL * linhas, false, Image.FORMAT_RGBA8)
	folha.fill(Color(1, 1, 1, 0))
	for i in LISTA.size():
		var e: Array = LISTA[i]
		var im := Image.new()
		if im.load_svg_from_string(FileAccess.get_file_as_string(a[0] + "/" + e[1] + ".svg"), ICONE / 512.0) != OK:
			push_error("não achei " + e[1])
			quit(1)
			return
		im.convert(Image.FORMAT_RGBA8)
		if e[2]:
			im.rotate_180()
		var m := (CEL - ICONE) / 2
		folha.blit_rect(im, Rect2i(0, 0, ICONE, ICONE), Vector2i((i % COLUNAS) * CEL + m, (i / COLUNAS) * CEL + m))
	folha.save_png("res://hud/icones/botoes.png")
	print("hud/icones/botoes.png: %d ícones" % LISTA.size())
	quit()

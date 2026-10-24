extends CanvasLayer
# CRÉDITOS (botão "Créditos" do menu principal): quem fez a história, o jogo e TUDO o que foi baixado de fora
# (modelos, fontes, sons...) com autor, licença e endereço. Rola com o dedo/mouse. "Licença da Godot" mostra o
# texto completo da licença MIT do motor (a licença pede que ele vá junto com o jogo).
# REGRA DO PROJETO: qualquer coisa baixada da internet que pedir (ou merecer) crédito entra na lista
# RECURSOS abaixo. Mexa AQUI para: textos dos créditos.

signal fechar

const UI := preload("res://menu/ui.gd")

# [título da seção, [[linha principal, detalhe], ...]]
const EQUIPE := [
	["HISTÓRIA E UNIVERSO", [
		["Willian Ulguim e Gabriel Solla", "Dias de um Apocalipse · Livro 1 e Bíblia da Lore"]]],
	["JOGO", [
		["Dias de um Apocalipse · Nova York", "Porte para a Godot do jogo original em HTML"],
		["Cidade, prédios, interiores, carros, clima e música", "Feitos por código para o jogo (mais os modelos de terceiros listados abaixo)"]]],
]
# [o quê, autor, licença, endereço]
const RECURSOS := [
	["Cartão de acesso dos bunkers (modelo 3D; textura repintada)", "codeinfernogames (Code Inferno Games) · \"3D Keycard\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/3d-keycard"],
	["Personagem do jogador (corpo, pele, olhos, sobrancelhas, cabelos e barba)", "Quaternius · \"Universal Base Characters\"",
		"CC0 1.0 (domínio público)", "quaternius.itch.io/universal-base-characters"],
	["Modelos 3D (manequins) dos infectados e animações", "Quaternius · \"Universal Animation Library\" 1 e 2",
		"CC0 1.0 (domínio público)", "quaternius.com · opengameart.org/content/universal-animation-library-2"],
	["Animações de andar de lado e de costas, fuzil (mirar, atirar, recarregar), golpes com arma, pegar do chão, levar golpe, mortes e sentar",
		"Kay Lousberg · \"KayKit Character Animations\" (convertidas para o esqueleto do jogo)",
		"CC0 1.0 (domínio público)", "kaylousberg.itch.io/kaykit-character-animations · kaylousberg.com"],
	["Submetralhadora MP5 (modelo 3D e texturas)", "Gintoki1234 · \"MP5 A2\" (reduzido para o jogo)",
		"CC BY 4.0 (Creative Commons Atribuição 4.0)", "gintoki1234.itch.io/mp5-a2"],
	["Caminhadas (devagar, normal, apressada, trote, de lado, de costas, agachado, mancando), jeitos de andar dos infectados, comer, beber, tomar remédio e nadar (nado de peito) · captura de movimento real",
		"Carnegie Mellon University · \"CMU Graphics Lab Motion Capture Database\" (mocap.cs.cmu.edu; BVH de Bruce Hahne/cgspeed; convertidas para o esqueleto do jogo)",
		"Uso livre, inclusive comercial · dados obtidos de mocap.cs.cmu.edu, criados com recursos da NSF EIA-0196217", "mocap.cs.cmu.edu · github.com/una-dinosauria/cmu-mocap"],
	["Conexão pela internet no multijogador (WebRTC)", "Godot Engine contributors · \"webrtc-native\" (com libdatachannel, libjuice, usrsctp, libsrtp, Mbed TLS e plog)",
		"MIT (libdatachannel e libjuice: MPL 2.0 · usrsctp e libsrtp: BSD · Mbed TLS: Apache 2.0)", "github.com/godotengine/webrtc-native (licenças em addons/webrtc_native/)"],
	["Texturas do chão: concreto, terra, grama, areia e lama",
		"Poly Haven · Rob Tuytel, Rico Cilliers, Charlotte Baglioni",
		"CC0 1.0 (domínio público)", "polyhaven.com (lista completa em mundo/texturas/LICENCA.txt)"],
	["Pistola, rifle de caça, faca, facão, taco, machado e pé de cabra (modelos realistas)",
		"Poly Haven · Mateusz Sadek, Ulan Cabanilla, Enrique Martín, James Ray Cock, Alexander Otterbeck",
		"CC0 1.0 (domínio público)", "polyhaven.com (lista completa em armas/modelos/LICENCA.txt)"],
	["Fuzil M4A1", "nisu · \"M4A1 Assault Rifle\"", "CC0 1.0 (domínio público)", "opengameart.org/content/m4a1-assault-rifle"],
	["Fuzil AKM", "LonesomeDucky · \"AKM\"", "CC0 1.0 (domínio público)", "opengameart.org/content/akm"],
	["Espingarda (Remington 870)", "MikeMoon · \"Shotgun\"", "CC0 1.0 (domínio público)", "opengameart.org/content/shotgun-1"],
	["Comida, remédios, ferramentas, munição, rádio, lanterna e caixa de suprimento (modelos realistas)",
		"Poly Haven · Ulan Cabanilla, Miroslav Turura, Mia Pecina Zorko, Kosan Aziz, Oliver Harries, PierreB3D, Abiyyu Panggalih, Slinc, Thomas Paul Mouilleron, DanKit, Mateusz Sadek, Rico Cilliers, Jack Mava",
		"CC0 1.0 (domínio público)", "polyhaven.com (lista completa em inventario/modelos/LICENCA.txt)"],
	["Silenciador, mira e luneta", "Quaternius · \"Ultimate Gun Pack\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/low-poly-guns-pack"],
	["Mochilas de trilha e de combate", "Quaternius · \"Survival Pack\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/lowpoly-survival-pack"],
	["Lança improvisada", "Hernandack · \"Low Poly Survival Toolkit (weapon)\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/low-poly-survival-toolkit-weapon"],
	["Capacete tático", "hc · \"Combat helmet\" (cores e tamanho ajustados para o jogo)",
		"CC-BY 3.0 (creativecommons.org/licenses/by/3.0)", "opengameart.org/content/combat-helmet"],
	["Boné", "Teh_Bucket · \"Hats & clothing props\" (snapback)",
		"CC0 1.0 (domínio público)", "opengameart.org/content/hats-clothing-props"],
	["Mochila escolar", "Saraskau · \"Low poly camping assets\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/low-poly-camping-assets"],
	["Tiros gravados de verdade (1911, Walther PPQ, AR-15, AK-47, Benelli Nova, Mossberg, Tikka, Savage, Ruger .22)",
		"Ben Jaszczak, Brian Nelson, Kevin Heras e Matthew Nanney (Still North Media) · \"The Free Firearm Sound Library\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/the-free-firearm-sound-library"],
	["Recarga da pistola e da espingarda", "zer0_sol · \"Handgun Reload Sound Effect\" e \"Shotgun Reload Sound Effects\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/handgun-reload-sound-effect · opengameart.org/content/shotgun-reload-sound-effects"],
	["Recarga do fuzil e bombear da espingarda", "SpringySpringo · \"Gun Reload Sounds\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/gun-reload-sounds"],
	["Bala entrando no pente", "BMacZero · \"Gun Reload Sound Effects\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/gun-reload-sound-effects"],
	["Ferrolho do rifle e gatilho em seco", "LFA · \"Equipment Clicks III\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/equipment-clicks-iii"],
	["Sons do menu e das telas", "Kenney · \"Interface Sounds\" e \"UI Audio\"",
		"CC0 1.0 (domínio público)", "kenney.nl/assets/interface-sounds · kenney.nl/assets/ui-audio"],
	["Mochila, roupas, pegar/largar, sacar arma, portas e assoalho", "Kenney · \"RPG Audio\"",
		"CC0 1.0 (domínio público)", "kenney.nl/assets/rpg-audio"],
	["Comer", "StarNinjas · \"7 Eating Crunches\"", "CC0 1.0 (domínio público)", "opengameart.org/content/7-eating-crunches"],
	["Coração batendo", "bart · \"Heartbeat sounds\"", "CC0 1.0 (domínio público)", "opengameart.org/content/heartbeat-sounds"],
	["Fogo da fogueira", "AntumDeluge · \"Fire Crackling\"", "CC0 1.0 (domínio público)", "opengameart.org/content/fire-crackling"],
	["Vento na tempestade", "SketchMan3 · \"Wind Whoosh Loop\"", "CC0 1.0 (domínio público)", "opengameart.org/content/wind-whoosh-loop"],
	["Pássaros de dia", "Spring Spring · \"Birds and Wind - Ambient\"", "CC0 1.0 (domínio público)",
		"opengameart.org/content/birds-and-wind-ambient-birds-wind-and-synth"],
	["Grilos à noite", "Wolfgang_ · \"Crickets Ambient Noise - loopable\"", "CC0 1.0 (domínio público)",
		"opengameart.org/content/crickets-ambient-noise-loopable"],
	["Gemidos e gritos dos infectados", "artisticdude · \"Zombies Sound Pack\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/zombies-sound-pack"],
	["Ataque e morte dos infectados, dor e morte do jogador", "ArcadeParty · \"Zombie / Skeleton / Monster Voice Effects\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/zombie-skeleton-monster-voice-effects"],
	["Passos do jogador", "GboxMikeFozzy · \"Footsteps\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/footsteps-0"],
	["Passos (concreto, grama, madeira), impactos dos golpes e das balas, cápsulas", "Kenney · \"Impact Sounds\"",
		"CC0 1.0 (domínio público)", "kenney.nl/assets/impact-sounds"],
	["Sirene ao longe", "aquinn · \"Sirens and Alarm Noise\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/sirens-and-alarm-noise"],
	["Ícones da HUD (vida, sangue, fome, sede, temperatura, pulmões, doenças, pente...)", "Lorc e Delapouite · game-icons.net",
		"CC BY 3.0", "game-icons.net"],
	["Postes, semáforo e placas de trânsito", "Quaternius · \"LowPoly Modular Street Pack\"",
		"CC0 1.0 (domínio público)", "opengameart.org/content/lowpoly-modular-street-pack"],
	["Árvores, arbustos, samambaias, flores, capim e pedras", "Quaternius · \"Stylized Nature MegaKit\" (Standard)",
		"CC0 1.0 (domínio público)", "opengameart.org/content/stylized-nature-megakit · quaternius.com"],
	["Hidrante, barreira de concreto, lixeira, caixa de energia, bueiro, saco de lixo, barril, pneu, caixote, carro coberto e caixa de papelão",
		"Poly Haven · Gonçalo Felício, Amal Kumar, GurJas Studios, James Ray Cock, Raunox, Benny Weimer, Jorge Camacho, MP, Jurita Burger, Rahul Chaudhary",
		"CC0 1.0 (domínio público)", "polyhaven.com (lista completa em mundo/cenario/LICENCA.txt)"],
	["Ícones dos botões de toque (atirar, mirar, correr, pular, agachar, recarregar, mochila, pausa, armas...)",
		"Lorc, Delapouite, Skoll, John Colburn e Guard13007 · game-icons.net", "CC BY 3.0", "game-icons.net"],
	["Fonte Roboto Condensed", "Christian Robertson · Google Fonts (Copyright 2011 Google Inc.)",
		"SIL Open Font License 1.1", "fonts.google.com/specimen/Roboto+Condensed"],
	["Motor do jogo: Godot Engine 4.3", "Juan Linietsky, Ariel Manzur e colaboradores da Godot",
		"Licença MIT (texto completo no botão abaixo)", "godotengine.org"],
]

var _raiz: Control
var _licenca: Label

func _ready() -> void:
	layer = 30
	get_viewport().size_changed.connect(_montar)
	_montar()

func _montar() -> void:
	if _raiz != null:
		_raiz.queue_free()
	var v := UI.vh(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.06, 0.025, 0.01, 0.94)
	_raiz.add_child(fundo)
	var tit := UI.titulo_degrade("CRÉDITOS", 9.0 * v, 0.1 * 9.0 * v)
	tit.position = Vector2(6.0 * v, 3.0 * v)
	_raiz.add_child(tit)
	var voltar := UI.BotaoMenu.new("Voltar", "", true, 3.4, 20.0)
	voltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	voltar.offset_left = -26.0 * v
	voltar.offset_right = -4.0 * v
	voltar.offset_top = 4.0 * v
	voltar.apertado.connect(_sair)
	_raiz.add_child(voltar)
	var rolar := ScrollContainer.new()
	rolar.set_anchors_preset(Control.PRESET_FULL_RECT)
	rolar.offset_left = 6.0 * v
	rolar.offset_right = -4.0 * v
	rolar.offset_top = 16.0 * v
	rolar.offset_bottom = -3.0 * v
	rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_raiz.add_child(rolar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(1.0 * v))
	rolar.add_child(col)
	for secao in EQUIPE:
		_secao(col, secao[0], v)
		for item in secao[1]:
			_linha(col, item[0], item[1], v)
	_secao(col, "RECURSOS DE TERCEIROS", v)
	for r in RECURSOS:
		_linha(col, r[0], "%s\n%s · %s" % [r[1], r[2], r[3]], v)
	var esp := Control.new()
	esp.custom_minimum_size.y = 2.0 * v
	col.add_child(esp)
	var bl := UI.BotaoMenu.new("Licença da Godot", "texto completo (MIT)", false, 3.0, 30.0)
	bl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(bl)
	_licenca = UI.rotulo(Engine.get_license_text(), 2.0 * v, Color(1, 1, 1, 0.7), 400)
	_licenca.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_licenca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_licenca.visible = false
	col.add_child(_licenca)
	bl.apertado.connect(func(): _licenca.visible = not _licenca.visible)

func _secao(col: VBoxContainer, txt: String, v: float) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(2.4 * v))
	m.add_child(UI.rotulo(txt, 3.2 * v, UI.TITULO_SECAO, 900, 0.15 * 3.2 * v, true))
	col.add_child(m)

func _linha(col: VBoxContainer, titulo: String, detalhe: String, v: float) -> void:
	var t := UI.rotulo(titulo, 3.0 * v, UI.TEXTO, 800)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(t)
	var d := UI.rotulo(detalhe, 2.3 * v, Color(1, 0.91, 0.82, 0.68), 400)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(d)

func _sair() -> void:
	fechar.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_sair()

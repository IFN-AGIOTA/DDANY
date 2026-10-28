@tool
extends Node3D
# MAIN · só LIGA as partes do jogo (cada sistema mora no seu arquivo; veja o MAPA no LEIA-ME.txt).
# Fluxo: MENU PRINCIPAL (cena 3D do pôr do sol) -> Jogar -> cidade + jogo na BASE MILITAR do aeroporto.
# No jogo: II / P / Esc = PAUSA (Continuar · Opções · Voltar ao início · Menu principal).
# Mexa AQUI para: onde o jogador nasce (SPAWN) e a ordem em que as telas/sistemas são criados.

const MILBASE := Vector2(6230.0, 690.0)     # centro da base militar (aeroporto), como no jogo em HTML
const SPAWN := Vector2(6230.0, 590.0)       # onde o jogador nasce (virado para o sul)

const Sons := preload("res://audio/sons.gd")
const ServidorCls := preload("res://rede/servidor.gd")
const RodaArmasCls := preload("res://hud/roda_armas.gd")
const CidadeCls := preload("res://mundo/cidade.gd")
const ColisaoMundoCls := preload("res://mundo/colisao_mundo.gd")
const ChunksCls := preload("res://mundo/chunks.gd")
const EstandeCls := preload("res://mundo/estande_tiro.gd")
const LootCls := preload("res://mundo/loot.gd")
const LootMundoCls := preload("res://mundo/loot_mundo.gd")
const InterioresCls := preload("res://mundo/interiores.gd")
const LocaisCls := preload("res://mundo/locais.gd")
const PortaCls := preload("res://mundo/porta.gd")
const VeiculosCls := preload("res://mundo/veiculos.gd")
const MatoCls := preload("res://mundo/mato.gd")
const FumacaCls := preload("res://mundo/fumaca.gd")
const HudStatusCls := preload("res://hud/hud_status.gd")
const MapaCls := preload("res://hud/mapa.gd")
const ClimaCls := preload("res://mundo/clima.gd")
const Salvamento := preload("res://menu/salvamento.gd")
const MissoesCls := preload("res://mundo/missoes.gd")
const ConstrucaoCls := preload("res://mundo/construcao.gd")
const HospitaisCls := preload("res://npc/hospitais.gd")
const EventosCls := preload("res://mundo/eventos.gd")
const AmbienteCls := preload("res://audio/ambiente.gd")
const VagosCls := preload("res://inimigos/vagos.gd")
const AUTOSALVAR := 120.0                   # segundos entre salvamentos automáticos
const TelaMorteCls := preload("res://menu/tela_morte.gd")
const ItemMundoCls := preload("res://inventario/item_mundo.gd")
const ControlesCls := preload("res://jogador/controles.gd")
const CameraVooCls := preload("res://jogador/camera_voo.gd")
const HudCls := preload("res://armas/hud_combate.gd")
const TelaInventarioCls := preload("res://inventario/tela_inventario.gd")
const CenaMenuCls := preload("res://menu/cena_menu.gd")
const MenuPrincipalCls := preload("res://menu/menu_principal.gd")
const OpcoesCls := preload("res://menu/opcoes.gd")
const PausaCls := preload("res://menu/pausa.gd")
const EditorHudCls := preload("res://menu/editor_hud.gd")
const AplicarOpcoesCls := preload("res://menu/aplicar_opcoes.gd")
const LogoProdutoraCls := preload("res://menu/logo_produtora.gd")
const Mutacao := preload("res://jogador/mutacao.gd")
const SentidosCls := preload("res://jogador/sentidos.gd")
const JOGADOR_CENA := preload("res://jogador/jogador.tscn")
const SessaoRedeCls := preload("res://rede/sessao_rede.gd")
const TelaMultiCls := preload("res://menu/tela_multijogador.gd")
const TelaLoginCls := preload("res://menu/tela_login.gd")
const TelaPerfilCls := preload("res://menu/tela_perfil.gd")
const AvisoChamadoCls := preload("res://menu/aviso_chamado.gd")
const TelaCarregamentoCls := preload("res://menu/tela_carregamento.gd")
# 0.99: as partes de _criar_jogo() na TELA DE CARREGAMENTO: chave -> [texto, peso (tempo relativo; os da cidade estão
# em mundo/cidade.gd etapas())]
const ETAPAS_JOGO := {
	"colisao": ["Chão firme e colisão", 7.0],
	"jogador": ["O seu sobrevivente", 6.0],
	"hud": ["Vida, fome, sede e munição", 20.0],
	"mapa": ["Desenhando o mapa da cidade", 6.0],
	"clima": ["Céu, clima e dia/noite", 10.0],
	"infectados": ["Acordando os infectados", 2.0],
	"mato": ["Mato e fumaça", 2.0],
	"base": ["Base militar e estande de tiro", 2.0],
	"loot": ["Espalhando o loot", 2.0],
	"interiores": ["Prédios por dentro e locais especiais", 2.0],
	"carros": ["Carros que ainda funcionam", 1.5],
	"sobreviventes": ["Missões, base e hospitais", 1.5],
	"sons": ["Sons da cidade", 7.0],
	"vista": ["Preparando a vista", 30.0],
}

var cidade: Node3D
var jogo: Node3D                            # tudo do jogo em andamento (apagado ao voltar ao menu)
var jogador: CharacterBody3D
var controles: CanvasLayer
var mundo: Node3D
var chunks: Node                            # mundo/chunks.gd (só os chunks de 500 m perto da câmera ficam na cena)
var hud: CanvasLayer
var estande: Node3D
var tela_inventario: CanvasLayer
var voo: Camera3D
var cena_menu: Node3D
var menu: CanvasLayer
var opcoes: CanvasLayer
var pausa: CanvasLayer
var aplicador: Node
var loot_mundo                              # mundo/loot_mundo.gd (o que tem em cada móvel/carro, guardado)
var interiores: Node                        # mundo/interiores.gd (prédios por dentro perto do jogador)
var locais: Node                            # mundo/locais.gd (postos, hospitais, supermercados e armazéns: zonas de PvP)
var veiculos: Node                          # 0.76: mundo/veiculos.gd (carros que funcionam: dirigir, gasolina)
var _t_info := 0.0
var missoes: Node = null                    # mundo/missoes.gd (suprimentos militares avisados pelo rádio)
var construcao: Node = null                 # 0.90: mundo/construcao.gd (a base que você constrói)
var hospitais: Node = null                  # 0.91: npc/hospitais.gd (zona neutra, Mônica, Lucas, Carlos, dinheiro)
var sentidos: Node = null                   # 0.95: jogador/sentidos.gd (farejar/escutar e o estalo do mutado)
var eventos: Node = null                    # mundo/eventos.gd (0.65: helicóptero caído, comboio, zona contaminada)
var hud_status: CanvasLayer                 # hud/hud_status.gd (vida, sangue, fome, sede, temperatura)
var tela_morte: CanvasLayer
var mapa: CanvasLayer                       # hud/mapa.gd (minimapa, mapa grande e bússola)
var clima: Node                             # mundo/clima.gd (dia/noite, chuva, temperatura, lanterna)
var vagos: Node                             # inimigos/vagos.gd (infectados)
var mato: Node3D                            # mundo/mato.gd (mato perto do jogador + sombra dos prédios no chão)
var roda_armas: CanvasLayer = null           # hud/roda_armas.gd (roda do botão ARMA)
var sessao_rede: Node = null                # rede/sessao_rede.gd (só na partida multijogador)
var tela_multi: CanvasLayer = null          # menu/tela_multijogador.gd
var tela_login: CanvasLayer = null          # menu/tela_login.gd (pede o login ao abrir o jogo)
var _login_perguntado := false
var tela_perfil: CanvasLayer = null         # menu/tela_perfil.gd (ícone de perfil no menu)
var abates := 0
var _tempo_jogo := 0.0
var _t_salvar := 0.0
var carregamento = null                     # 0.99: menu/tela_carregamento.gd enquanto o jogo é montado
var carregar_em_etapas := true              # falso nos testes automáticos (montam tudo de uma vez, como antes)

# Preview dentro do editor (não é salvo na cena; leva alguns segundos e pesa no celular)
@export var preview_no_editor := false:
	set(v):
		preview_no_editor = v
		if not (Engine.is_editor_hint() and is_inside_tree()):
			return
		if v and not _cidade().is_built:
			_cidade().construir()
		elif not v and cidade != null and cidade.is_built:
			cidade.limpar()

# Marque para gerar res://cidade.scn: a cidade vira uma cena de verdade, editável com as ferramentas da Godot
@export var gerar_cena_salva := false:
	set(v):
		if v and Engine.is_editor_hint() and is_inside_tree():
			_cidade().salvar_cena()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS          # main cuida das telas; o jogo em si pausa (nó "Jogo")
	get_tree().set_quit_on_go_back(false)             # Android: o botão VOLTAR fecha telas/pausa, não sai do jogo
	aplicador = AplicarOpcoesCls.new()
	aplicador.name = "AplicarOpcoes"
	aplicador.main = self
	add_child(aplicador)
	if ServidorCls.pedido():                         # 0.50: aberto como SERVIDOR do PC (rede/servidor.gd)
		var sv := ServidorCls.new()
		sv.name = "Servidor"
		add_child(sv)
		sv.iniciar.call_deferred(self)
		return
	Rede.caiu.connect(_rede_caiu)
	Conta.chamado.connect(_chamado)
	# 0.93: logo da produtora (Infinity Studio) antes de tudo; os testes (rodando um script com -s) pulam
	if "-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args():
		carregar_em_etapas = false
		_abrir_menu()
		return
	var logo := LogoProdutoraCls.new()
	logo.name = "LogoProdutora"
	add_child(logo)
	logo.acabou.connect(_abrir_menu, CONNECT_ONE_SHOT)

# nó "Cidade" (construções). No editor é criado sem dono, então não é salvo na cena.
func _cidade() -> Node3D:
	if cidade == null:
		cidade = CidadeCls.new()
		cidade.name = "Cidade"
		add_child(cidade)
	return cidade

# ---------- telas ----------
func _abrir_menu() -> void:
	_fechar_jogo()
	Rede.sair()                              # voltou ao menu: sai da partida em rede (se estava)
	if cidade != null:
		cidade.visible = false
	cena_menu = CenaMenuCls.new()
	cena_menu.name = "CenaMenu"
	add_child(cena_menu)
	menu = MenuPrincipalCls.new()
	menu.name = "MenuPrincipal"
	add_child(menu)
	menu.jogar.connect(_jogar)
	menu.continuar.connect(func(): _jogar(true))
	menu.opcoes.connect(_abrir_opcoes)
	menu.multijogador.connect(_abrir_multijogador)
	menu.perfil.connect(_abrir_perfil)
	Musica.definir_modo("menu")
	if not _login_perguntado:
		_login_perguntado = true
		_pedir_login()

# AO ABRIR O JOGO: pede para entrar com a conta Google (rede/conta.gd), se o Firebase estiver configurado.
# Quem já entrou antes volta logado sozinho e só recebe um "Olá".
func _pedir_login() -> void:
	if not Conta.configurado:
		return
	while Conta.entrando and tela_login == null:      # recuperando a sessão salva
		await get_tree().process_frame
	if menu == null:
		return
	if Conta.logado:
		menu.avisar("Olá, %s!" % Conta.nome)
		return
	_abrir_login()

func _abrir_login() -> void:
	if tela_login != null or not Conta.configurado:
		return
	tela_login = TelaLoginCls.new()
	tela_login.name = "TelaLogin"
	add_child(tela_login)
	tela_login.fechar.connect(func():
		tela_login = null
		if Conta.logado and menu != null:
			menu.avisar("Olá, %s! Toque no seu ícone para ver o perfil e os amigos." % Conta.nome))

# PERFIL (ícone no canto do menu e botão na tela Multijogador)
func _abrir_perfil() -> void:
	if tela_perfil != null:
		return
	tela_perfil = TelaPerfilCls.new()
	tela_perfil.name = "TelaPerfil"
	add_child(tela_perfil)
	tela_perfil.fechar.connect(func(): tela_perfil = null)
	tela_perfil.pedir_login.connect(func():
		tela_perfil.queue_free()
		tela_perfil = null
		_abrir_login())

# um amigo me CHAMOU para a sala dele (rede/conta.gd): aviso por cima de tudo
func _chamado(c: Dictionary) -> void:
	if Rede.ligado or get_node_or_null("AvisoChamado") != null:
		return
	var a := AvisoChamadoCls.new()
	a.name = "AvisoChamado"
	a.convite = c
	add_child(a)
	a.aceitou.connect(_aceitar_chamado)

func _aceitar_chamado(c: Dictionary) -> void:
	if jogo != null:                        # estava jogando sozinho: salva e volta ao menu
		salvar_jogo()
		_continuar()
		_abrir_menu()
	for t in [tela_perfil, tela_login]:
		if t != null and is_instance_valid(t):
			t.queue_free()
	tela_perfil = null
	tela_login = null
	_abrir_multijogador()
	tela_multi.entrar_na_sala(c)

func _jogar(carregar_salvo := false) -> void:
	if carregamento != null:
		return
	if carregar_em_etapas:
		await _abrir_carregamento("CONTINUANDO O JOGO SALVO" if carregar_salvo else ("MULTIJOGADOR · NOVA YORK" if Rede.ligado else "MUNDO LIVRE · NOVA YORK"))
	else:
		menu.mostrar_carregando()
		await get_tree().process_frame          # deixa o "CARREGANDO" aparecer antes de montar a cidade
		await get_tree().process_frame
	if menu != null:
		menu.queue_free()
		menu = null
	if cena_menu != null:
		cena_menu.queue_free()
		cena_menu = null
	var etapas_cidade: Array = [] if _cidade().is_built else cidade.etapas()
	if carregamento != null:
		for e in etapas_cidade:
			carregamento.total += float(e[1])
		if carregar_salvo:
			carregamento.total += 2.0
		if Rede.ligado:
			carregamento.total += 1.0
	cidade.fatiar = carregamento != null    # 0.99.1: as partes pesadas param de vez em quando (a tela não congela)
	for e in etapas_cidade:
		await _etapa_texto(e[0], e[1])
		await e[2].call()
	cidade.fatiar = false
	cidade.visible = true
	await _criar_jogo()
	if carregar_salvo:
		await _etapa_texto("Abrindo o jogo salvo", 2.0)
		var d := Salvamento.ler()
		if not d.is_empty():
			Salvamento.carregar(self, d)
			if d.get("morto", false):                # morreu e saiu: volta já renascido, longe das coisas
				jogador.morto = true
				_renascer()
	jogador.usar_sobrevivente()             # o personagem do jogador: jogador/modelo_sobrevivente.gd
	if Rede.ligado:
		await _etapa_texto("Entrando na partida", 1.0)
	_ligar_rede()
	await _fim_carregamento()
	Sons.tocar("partida/entrada", -3.0)        # 0.49: entrada da partida (pancada grave + eco + coração)

# ---------- 0.99: tela de carregamento (menu/tela_carregamento.gd) ----------
# 0.99.1: arquivos grandes lidos do disco EM SEGUNDO PLANO (outra thread) assim que a tela aparece, na ordem em que o
# jogo vai precisar: quando a montagem chega neles, já estão na memória (na 1ª vez que o jogo abre, ler o boneco do
# disco travava a tela por segundos)
const PRE_CARREGAR := ["res://mundo/cenario/", "res://jogador/sobrevivente/", "res://inimigos/infectados/",
	"res://armas/modelos/", "res://equipamentos/modelos/", "res://inventario/modelos/"]
static func _pre_carregar() -> void:
	for pasta in PRE_CARREGAR:
		for f in DirAccess.get_files_at(pasta):           # no jogo exportado vêm como "x.glb.import"/"x.scn.remap"
			var nome := str(f).trim_suffix(".remap").trim_suffix(".import")
			if not (nome.get_extension() in ["glb", "scn", "res", "tscn"]):
				continue
			var p: String = pasta + nome
			if ResourceLoader.exists(p) and not ResourceLoader.has_cached(p):
				ResourceLoader.load_threaded_request(p)

# entre partes pesadas do _criar_jogo: deixa a tela de carregamento desenhar um quadro (sem a tela: nada)
func _respiro() -> void:
	if carregamento != null:
		await get_tree().process_frame

# esconde o menu, tira a "foto" da tela para o fundo e espera a tela de carregamento aparecer por inteiro
func _abrir_carregamento(modo: String) -> void:
	var escondidas: Array = []              # menu, pausa, HUD...: um quadro sem eles, para a foto do fundo
	for n in find_children("*", "CanvasLayer", true, false):
		if n.visible:
			n.visible = false
			escondidas.append(n)
	await get_tree().process_frame
	carregamento = TelaCarregamentoCls.new()
	carregamento.name = "TelaCarregamento"
	carregamento.modo = modo
	for k in ETAPAS_JOGO:
		carregamento.total += float(ETAPAS_JOGO[k][1])
	carregamento.fonte_progresso = func() -> float: return float(cidade.progresso) if cidade != null else -1.0
	add_child(carregamento)                 # a foto é tirada aqui
	_pre_carregar()
	for n in escondidas:                    # o que continua (um aviso de convite, por exemplo) volta, por baixo da tela
		if is_instance_valid(n):
			n.visible = true
	while is_instance_valid(carregamento) and carregamento._alfa < 1.0:
		await get_tree().process_frame
	# 0.99.1: com a tela cobrindo tudo, o 3D não é desenhado (cada quadro desenhando a cidade por baixo compilava
	# shaders e travava a animação); volta na "Preparando a vista" (_fim_carregamento)
	get_viewport().disable_3d = true

# antes de cada parte da montagem: mostra o texto e deixa a tela ser desenhada (sem tela: segue direto, como antes)
func _etapa(chave: String) -> void:
	await _etapa_texto(ETAPAS_JOGO[chave][0], ETAPAS_JOGO[chave][1])

func _etapa_texto(texto: String, peso: float) -> void:
	if carregamento != null:
		await carregamento.etapa(texto, peso)
		if cidade != null:
			cidade.progresso = -1.0             # quanto da etapa já foi (mundo/cidade.gd respirar)
			cidade.t_fatia = Time.get_ticks_msec()

# tudo montado: o jogo volta a andar, desenha alguns quadros por baixo e a tela some devagar
func _fim_carregamento() -> void:
	if carregamento == null:
		if jogo != null:
			jogo.process_mode = Node.PROCESS_MODE_PAUSABLE
		return
	carregamento.peso_vista = ETAPAS_JOGO["vista"][1]
	await carregamento.etapa(ETAPAS_JOGO["vista"][0], ETAPAS_JOGO["vista"][1])
	# 0.99.1: a VISTA APARECE AOS POUCOS (ainda debaixo da tela): o 3D volta com tudo escondido e cada quadro mostra
	# mais um lote; assim os shaders e as texturas vão para a placa de vídeo em vários quadros curtos, não num só
	# (na 1ª vez que o jogo abre, esse quadro único travava a tela por quase 2 s)
	var lotes: Array = []
	for no in (cidade.get_children() if cidade != null else []) + jogo.get_children():
		if no is Node3D and no.visible:
			no.visible = false
			lotes.append(no)
	get_viewport().disable_3d = false
	const N_LOTES := 12
	for i in N_LOTES:
		for k in range(lotes.size() * i / N_LOTES, lotes.size() * (i + 1) / N_LOTES):
			if is_instance_valid(lotes[k]):
				lotes[k].visible = true
		if cidade != null:
			cidade.progresso = float(i + 1) / N_LOTES * 0.8
		await get_tree().process_frame
	jogo.process_mode = Node.PROCESS_MODE_PAUSABLE   # o jogo volta a andar (os quadros finais trazem os prédios perto)
	var c = carregamento
	carregamento = null                     # o jogo já pode ser pausado/salvo enquanto a tela some
	await c.terminar()

# ---------- multijogador (rede/rede.gd) ----------
func _abrir_multijogador() -> void:
	if tela_multi != null:
		return
	tela_multi = TelaMultiCls.new()
	tela_multi.name = "TelaMultijogador"
	add_child(tela_multi)
	tela_multi.fechar.connect(func():
		tela_multi.queue_free()
		tela_multi = null
		if pausa != null:
			pausa.visible = true)
	tela_multi.comecar.connect(func():
		tela_multi.queue_free()
		tela_multi = null
		if jogo == null:
			_jogar())
	tela_multi.abrir_perfil.connect(_abrir_perfil)
	tela_multi.pedir_login.connect(_abrir_login)
	if pausa != null:                        # host chamando amigos de dentro do jogo
		pausa.visible = false

# partida em rede: mesma semente de loot do host, nasce perto dos outros e liga a sessão (rede/sessao_rede.gd)
func _ligar_rede() -> void:
	if not Rede.ligado or jogo == null:
		return
	loot_mundo.semente = int(Rede.mundo.get("semente", loot_mundo.semente))
	loot_mundo.sorteia_cartoes = not Rede.eh_cliente()      # 0.83: em rede só o host sorteia os cartões dos bunkers
	loot_mundo.verifica_perdidos = false
	var voltou := Salvamento.carregar_rede(self)        # 0.77: personagem (e, no host, o mundo) da última partida em rede
	if voltou != "" and hud != null:
		hud.mostrar_aviso(voltou, 5.0)
	if Rede.eh_cliente():
		var a := randf() * TAU
		var p := SPAWN + Vector2(cos(a), sin(a)) * randf_range(2.0, 5.0)
		jogador.teleportar(Vector3(p.x, mundo.altura(p.x, p.y) + 0.05, p.y), PI)
	sessao_rede = SessaoRedeCls.new()
	sessao_rede.name = "SessaoRede"
	jogo.add_child(sessao_rede)
	sessao_rede.ligar(self)

func _rede_caiu(motivo: String) -> void:
	if jogo == null:
		return
	_continuar()
	_abrir_menu()
	if menu != null:
		menu.avisar(motivo)

func salvar_jogo() -> void:
	if carregamento != null:                 # 0.99: o jogo ainda está sendo montado
		return
	if Rede.ligado:
		if jogo != null and jogador != null:  # 0.77: partida em rede salva no arquivo dela (não estraga o jogo salvo sozinho)
			_t_salvar = 0.0
			Salvamento.salvar_rede(self)
		return
	if jogo != null and jogador != null:
		_t_salvar = 0.0
		Salvamento.salvar(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar()
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not Engine.is_editor_hint():
			salvar_jogo()

# botão VOLTAR do Android (e Esc): fecha a tela de cima; no jogo, pausa; no menu, sai
func _voltar() -> void:
	if carregamento != null:                 # 0.99: carregando: o Voltar espera
		return
	var ed = get_node_or_null("EditorHud")
	if ed != null:
		ed._concluir()                          # 0.97.1: Voltar/Esc no editor da HUD = Concluir (antes fechava as Opções por trás)
		return
	if tela_perfil != null:
		tela_perfil._sair()
	elif tela_login != null:
		if Conta.entrando:
			Conta.cancelar_login()                # volta para os botões da tela de login
		else:
			tela_login._sair()
	elif tela_multi != null:
		tela_multi._sair()
	elif opcoes != null:
		_fechar_opcoes()
	elif pausa != null:
		_continuar()
	elif tela_morte != null:
		return
	elif mapa != null and bool(mapa.aberto):
		mapa.fechar_mapa()
	elif tela_inventario != null and tela_inventario.aberto:
		tela_inventario.fechar()
	elif jogo != null:
		_pausar()
	elif menu != null:
		get_tree().quit()

func _abrir_opcoes() -> void:
	if opcoes != null:
		return
	opcoes = OpcoesCls.new()
	opcoes.name = "Opcoes"
	add_child(opcoes)
	opcoes.fechar.connect(_fechar_opcoes)
	opcoes.editar_hud.connect(_editar_hud)
	if pausa != null:
		pausa.visible = false

func _fechar_opcoes() -> void:
	if opcoes != null:
		opcoes.queue_free()
		opcoes = null
	if pausa != null:
		pausa.visible = true

func _editar_hud() -> void:
	opcoes.visible = false
	if pausa != null:
		pausa.visible = false
	var ed = EditorHudCls.new()
	ed.name = "EditorHud"
	add_child(ed)
	ed.abrir(controles)
	ed.concluido.connect(func():
		if opcoes != null:
			opcoes.visible = true
			opcoes.mensagem("Posições da HUD salvas."))

func _pausar() -> void:
	if pausa != null or jogo == null:
		return
	if tela_inventario != null and tela_inventario.aberto:
		tela_inventario.fechar()
	salvar_jogo()
	get_tree().paused = not Rede.ligado          # em rede o mundo não para (os outros continuam jogando)
	if Rede.ligado:
		controles.set_bloqueado(true)
	Sons.ui("abrir")
	pausa = PausaCls.new()
	pausa.name = "Pausa"
	pausa.estatisticas = _estatisticas()
	add_child(pausa)
	pausa.continuar.connect(_continuar)
	pausa.chamar_amigos.connect(_abrir_multijogador)
	pausa.opcoes.connect(_abrir_opcoes)
	pausa.reiniciar.connect(_recomecar)
	pausa.menu_principal.connect(func():
		salvar_jogo()
		_continuar()
		_abrir_menu())

# pausa › Voltar ao início: monta o jogo de novo (com a tela de carregamento)
func _recomecar() -> void:
	_continuar()
	if carregar_em_etapas:
		await _abrir_carregamento("RECOMEÇANDO · MUNDO LIVRE" if not Rede.ligado else "RECOMEÇANDO · MULTIJOGADOR")
	_fechar_jogo()
	await _criar_jogo()
	jogador.usar_sobrevivente()
	_ligar_rede()
	await _fim_carregamento()

func _continuar() -> void:
	if opcoes != null:
		return
	if pausa != null:
		pausa.queue_free()
		pausa = null
	get_tree().paused = false
	if Rede.ligado and controles != null and is_instance_valid(controles) and tela_morte == null:
		controles.set_bloqueado(false)

func _estatisticas() -> Array:
	var s := int(_tempo_jogo)
	var r := [["tempo de jogo", "%d:%02d" % [s / 60, s % 60]], ["infectados abatidos", str(abates)]]
	if clima != null:
		r.append(["dia de sobrevivência", str(int(clima.dia))])
	if missoes != null:
		r.append(["suprimentos achados", str(missoes.encontrados)])
	if Rede.ligado:
		r.append(["jogadores na partida" + (" (você é o host)" if Rede.eh_host() else ""), str(Rede.jogadores.size())])
	var rt := int(float(Config.valor("rec_tempo")))
	r.append(["recorde vivo", "%d:%02d" % [rt / 60, rt % 60]])
	if estande != null and int(estande.get("acertos")) > 0:
		r.append(["acertos no estande", str(estande.get("acertos"))])
		r.append(["tiros na cabeça", str(estande.get("cabecas"))])
		r.append(["alvos derrubados", str(estande.get("abates"))])
	return r

# ---------- jogo: colisão do mundo + jogador + controles + HUD + inventário ----------
func _criar_jogo() -> void:
	_tempo_jogo = 0.0
	jogo = Node3D.new()
	jogo.name = "Jogo"
	# 0.99: montando com a tela de carregamento, nada do jogo anda entre uma parte e outra (_fim_carregamento liga)
	jogo.process_mode = Node.PROCESS_MODE_DISABLED if carregamento != null else Node.PROCESS_MODE_PAUSABLE
	add_child(jogo)
	await _etapa("colisao")
	controles = ControlesCls.new()
	controles.name = "Controles"
	jogo.add_child(controles)
	controles.pausa_pedida.connect(_pausar)
	await _respiro()
	mundo = ColisaoMundoCls.new()
	mundo.name = "ColisaoMundo"
	jogo.add_child(mundo)
	mundo.configurar(cidade.dados_cidade, cidade.predios)
	mundo.configurar_lotes(cidade.lote, cidade.W, cidade.H, cidade.CELL, cidade.WORLD, cidade.RAMPA_LOTE)   # chão dos quarteirões
	mundo.configurar_locais(LocaisCls.volumes_mundo(cidade.Y_CALCADA))   # 0.74: tiro de longe para nos locais especiais
	await _respiro()
	chunks = ChunksCls.new()
	chunks.name = "Chunks"
	jogo.add_child(chunks)
	chunks.configurar(cidade, AplicarOpcoesCls.raio_chunks())
	if cidade.abandono != null:
		mundo.configurar_obstaculos(cidade.abandono.obstaculos)
	await _etapa("jogador")
	jogador = JOGADOR_CENA.instantiate()
	jogador.name = "Jogador"
	jogador.mundo = mundo
	jogo.add_child(jogador)
	jogador.ligar_controles(controles)
	await _etapa("hud")
	hud = HudCls.new()
	hud.name = "HudCombate"
	jogo.add_child(hud)
	hud.ligar(jogador.armas, jogador)
	hud_status = HudStatusCls.new()
	hud_status.name = "HudStatus"
	jogo.add_child(hud_status)
	hud_status.ligar(jogador)
	await _etapa("mapa")
	mapa = MapaCls.new()
	mapa.name = "Mapa"
	jogo.add_child(mapa)
	mapa.ligar(cidade, jogador, controles)
	await _etapa("clima")
	clima = ClimaCls.new()
	clima.name = "Clima"
	jogo.add_child(clima)
	clima.ligar(cidade, jogador)
	jogador.sobrevivencia.clima = clima
	await _etapa("infectados")
	vagos = VagosCls.new()
	vagos.name = "Vagos"
	jogo.add_child(vagos)
	vagos.ligar(cidade, mundo, jogador, jogador.armas)
	vagos.clima = clima
	await _etapa("mato")
	mato = MatoCls.new()
	mato.name = "Mato"
	jogo.add_child(mato)
	mato.ligar(cidade, mundo, jogador)
	vagos.mato = mato
	var fumaca := FumacaCls.new()
	fumaca.name = "Fumaca"
	jogo.add_child(fumaca)
	fumaca.montar(cidade)
	vagos.abatido.connect(func(_c): abates += 1)
	jogador.sobrevivencia.tossiu.connect(func(p): vagos.barulho(p, 18.0, true))   # tosse e vômito fazem barulho
	jogador.sobrevivencia.morreu.connect(_morreu)
	jogador.sobrevivencia.aviso.connect(func(t): hud.mostrar_aviso(t))
	abates = 0
	await _etapa("base")
	estande = EstandeCls.new()
	estande.name = "EstandeTiro"
	estande.mundo = mundo
	jogo.add_child(estande)
	estande.montar(SPAWN + Vector2(0.0, 40.0), SPAWN)   # alvos ao sul do ponto de partida (para onde o jogador olha)
	var y: float = mundo.altura(SPAWN.x, SPAWN.y)
	mundo.forcar(SPAWN)
	jogador.teleportar(Vector3(SPAWN.x, y + 0.05, SPAWN.y), PI)   # virado para o sul (+Z), como no jogo em HTML
	mundo.alvo = jogador
	tela_inventario = TelaInventarioCls.new()
	tela_inventario.name = "TelaInventario"
	jogo.add_child(tela_inventario)
	tela_inventario.ligar(jogador.inventario, controles)
	roda_armas = RodaArmasCls.new()                   # 0.56: botão ARMA abre a roda (hud/roda_armas.gd)
	roda_armas.name = "RodaArmas"
	jogo.add_child(roda_armas)
	roda_armas.ligar(controles, jogador.inventario)
	roda_armas.aviso.connect(func(t): hud.mostrar_aviso(t))
	await _etapa("loot")
	LootCls.espalhar(jogo, mundo, SPAWN)
	await _respiro()
	loot_mundo = LootMundoCls.new()
	loot_mundo.semente = randi()                      # cada jogo novo tem o loot em lugares diferentes
	# 0.72: o loot volta pelo relógio do jogo (horas desde o 1º dia; na rede a hora é a do host)
	loot_mundo.relogio = func() -> float: return (float(clima.dia) - 1.0) * 24.0 + float(clima.hora) if clima != null else 0.0
	# 0.83: cartões dos bunkers: um só de cada (o loot procura se ele ainda existe no chão ou com o jogador)
	loot_mundo.procurar_item = _item_existe
	# 0.73: portas (mundo/porta.gd): o estado mexido fica no loot (jogo salvo e rede); abrir/fechar/martelar faz barulho
	PortaCls.ao_mudar = func(pt) -> void: loot_mundo.mudar_porta(pt.id, pt.estado())
	PortaCls.barulho = func(pos: Vector3, raio: float) -> void:
		if vagos != null:
			vagos.barulho(pos, raio, true)
	await _etapa("interiores")
	interiores = InterioresCls.new()
	interiores.name = "Interiores"
	jogo.add_child(interiores)
	interiores.ligar(cidade, mundo, jogador, loot_mundo)
	interiores.vagos = vagos
	locais = LocaisCls.new()
	locais.name = "Locais"
	jogo.add_child(locais)
	locais.ligar(cidade, jogador, loot_mundo)
	locais.vagos = vagos
	locais.mundo = mundo
	locais.clima = clima
	locais.hud = hud
	await _etapa("carros")
	veiculos = VeiculosCls.new()
	veiculos.name = "Veiculos"
	jogo.add_child(veiculos)
	veiculos.ligar(cidade, mundo, jogador, loot_mundo, vagos)
	jogador.veiculos_mgr = veiculos
	await _etapa("sobreviventes")
	missoes = MissoesCls.new()
	missoes.name = "Missoes"
	jogo.add_child(missoes)
	missoes.ligar(self)
	construcao = ConstrucaoCls.new()
	construcao.name = "Construcao"
	jogo.add_child(construcao)
	construcao.ligar(self)
	jogador.construcao = construcao
	vagos.construcao = construcao
	hospitais = HospitaisCls.new()
	hospitais.name = "Hospitais"
	jogo.add_child(hospitais)
	hospitais.ligar(self)
	jogador.hospitais = hospitais
	sentidos = SentidosCls.new()
	sentidos.name = "Sentidos"
	jogo.add_child(sentidos)
	sentidos.ligar(self)
	eventos = EventosCls.new()
	eventos.name = "Eventos"
	jogo.add_child(eventos)
	eventos.ligar(self)
	await _etapa("sons")
	var amb := AmbienteCls.new()
	amb.name = "AmbienteCidade"
	jogo.add_child(amb)
	amb.ligar(self)
	voo = CameraVooCls.new()
	voo.name = "CameraVoo"
	jogo.add_child(voo)
	voo.ligar(jogador, controles, mundo, tela_inventario)
	jogador.camera.make_current()
	await _respiro()
	aplicador.aplicar()
	# música: tiros e acertos aumentam a tensão (ela desce sozinha)
	Musica.definir_modo("jogo")
	jogador.armas.disparou.connect(func(_a): Musica.adicionar_tensao(0.05))
	jogador.armas.acertou.connect(func(_c, matou): Musica.adicionar_tensao(0.12 if matou else 0.03))

# 0.83: o item "id" está no chão do mundo (largado, em qualquer lugar aberto) ou com o jogador?
func _item_existe(id: String) -> bool:
	for n in get_tree().get_nodes_in_group("itens_chao"):
		var it = n.get("item")
		if it != null and (it.id == id or _tem_dentro(it, id)):
			return true
	if jogador != null and jogador.inventario != null:
		for s in jogador.inventario.slots:
			var it = jogador.inventario.slots[s]
			if it != null and (it.id == id or _tem_dentro(it, id)):
				return true
	return false

func _tem_dentro(it, id: String) -> bool:
	if not it.has_method("grades"):
		return false
	for g in it.grades():
		if LootMundoCls._grade_tem(g, id):
			return true
	return false

# ---------- morte e renascimento ----------
func _morreu(causa: String) -> void:
	if jogador == null:
		return
	# 0.94 · MUTAÇÃO: morto pelos infectados, 1% de chance de levantar MUTADO (jogador/mutacao.gd)
	if Mutacao.sorteia(causa, jogador.sobrevivencia.mutacao):
		_mutar()
		return
	Sons.tocar("partida/morte", -2.0)
	# tudo o que ele carregava cai no chão, junto do corpo
	var p := jogador.global_position
	for it in jogador.inventario.esvaziar():
		var a := randf() * TAU
		var r := randf_range(0.3, 1.1)
		ItemMundoCls.soltar(jogo, it, p + Vector3(cos(a) * r, 0.02, sin(a) * r))
	if not Rede.ligado:
		Salvamento.salvar(self, true)                 # a morte vale: sair agora não desfaz
	else:
		Salvamento.salvar_rede(self, true)            # 0.77: em rede também (o personagem volta do zero)
	Musica.adicionar_tensao(1.0)
	# 0.89 · quem morre pelo VÍRUS levanta como infectado no mesmo lugar (Project Zomboid / lore: a Forma Comum)
	if causa == "o vírus" and vagos != null and not vagos.espelho:
		get_tree().create_timer(8.0).timeout.connect(func():
			if vagos != null and is_instance_valid(vagos):
				var v = vagos._criar(p + Vector3(0.6, 0.0, 0.0), Vector3.INF)
				if v != null:
					v._tocar("rosnado", 0.9, 4.0))
	await get_tree().create_timer(2.5).timeout
	if jogador == null or not jogador.morto or tela_morte != null:
		return
	tela_morte = TelaMorteCls.new()
	tela_morte.causa = causa
	tela_morte.tempo_vivo = jogador.sobrevivencia.tempo_vivo
	tela_morte.abates = abates
	tela_morte.suprimentos = missoes.encontrados if missoes != null else 0
	add_child(tela_morte)
	controles.set_bloqueado(true)
	tela_morte.renascer.connect(_renascer)
	tela_morte.menu_principal.connect(func():
		_fechar_morte()
		_abrir_menu())

# 0.94: o corpo fica no chão, a tela escurece em vermelho e ele LEVANTA MUTADO no mesmo lugar, com tudo o que tinha
func _mutar() -> void:
	Sons.tocar("partida/morte", -2.0)
	Musica.adicionar_tensao(1.0)
	var j = jogador
	var veu := CanvasLayer.new()
	veu.layer = 60
	var cor := ColorRect.new()
	cor.set_anchors_preset(Control.PRESET_FULL_RECT)
	cor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cor.color = Color(0.0, 0.0, 0.0, 0.0)
	veu.add_child(cor)
	add_child(veu)
	var tw := veu.create_tween()
	tw.tween_property(cor, "color", Color(0.02, 0.0, 0.0, 0.94), 1.6)
	tw.tween_interval(Mutacao.TEMPO_LEVANTAR - 2.6)
	tw.tween_callback(_grito_mutado)
	tw.tween_property(cor, "color", Color(0.35, 0.0, 0.0, 0.6), 0.5)
	tw.tween_property(cor, "color", Color(0.25, 0.0, 0.0, 0.0), 1.8)
	tw.tween_callback(veu.queue_free)
	await get_tree().create_timer(Mutacao.TEMPO_LEVANTAR).timeout
	if jogador == null or jogador != j or not jogador.morto:
		return
	var s = jogador.sobrevivencia
	s.mutacao = 1
	s.vida = 100.0
	s.sangue = 5000.0
	s.sangramentos = 0
	s.infeccao = 0.0
	s.virus = -1.0
	s.perna_quebrada = false
	s.desmaiado = 0.0
	s.causa = ""
	jogador.morto = false
	if hud != null:
		hud.mostrar_aviso("VOCÊ NÃO MORREU... O VÍRUS MUDOU O SEU CORPO · VOCÊ É UM MUTADO\nOS INFECTADOS NÃO TE ATACAM · ARMA DE FOGO VOCÊ NÃO CONSEGUE USAR", 9.0)
	salvar_jogo()

func _grito_mutado() -> void:
	Sons.tocar("infectados/grito", -4.0, 0.8)

func _fechar_morte() -> void:
	if tela_morte != null:
		tela_morte.queue_free()
		tela_morte = null

func _renascer() -> void:
	_fechar_morte()
	var morte := Vector2(jogador.global_position.x, jogador.global_position.z)
	var p := _ponto_renascer(morte)
	# 0.90: tem uma CAMA na base: renasce nela
	var pc = construcao.ponto_cama() if construcao != null else null
	if pc != null:
		p = Vector2(pc.x, pc.z)
	jogador.morto = false
	Sons.tocar("partida/entrada", -8.0)
	jogador.sobrevivencia.reiniciar()
	jogador.inventario.equipamento_renascer()
	mundo.forcar(p)
	jogador.teleportar(Vector3(p.x, mundo.altura(p.x, p.y) + 0.1, p.y), randf() * TAU)
	controles.set_bloqueado(false)
	abates = 0
	salvar_jogo()

# ponto numa rua a 800-2500 m de onde morreu (como no DayZ: renasce longe das suas coisas)
func _ponto_renascer(longe_de: Vector2) -> Vector2:
	var r := RandomNumberGenerator.new()
	r.randomize()
	for tentativa in 400:
		var c := r.randi_range(0, cidade.W - 1)
		var l := r.randi_range(0, cidade.H - 1)
		if cidade.road[l * cidade.W + c] != 1:
			continue
		var p := Vector2((c + 0.5) * cidade.CELL - cidade.WORLD.x, (l + 0.5) * cidade.CELL - cidade.WORLD.y)
		var d := p.distance_to(longe_de)
		if d > 800.0 and d < 2500.0:
			return p
	return SPAWN

func _fechar_jogo() -> void:
	_fechar_morte()
	if construcao != null and is_instance_valid(construcao):
		construcao.fechar_menu()
	construcao = null
	if interiores != null and is_instance_valid(interiores):
		interiores.fechar_todos()           # devolve os blocos dos prédios para a cidade
	interiores = null
	if locais != null and is_instance_valid(locais):
		locais.fechar_todos()               # a casca de longe volta para a cidade
	locais = null
	if jogo != null:
		jogo.queue_free()
	jogo = null
	chunks = null
	jogador = null
	controles = null
	mundo = null
	hud = null
	estande = null
	tela_inventario = null
	voo = null
	hud_status = null
	mapa = null
	clima = null
	vagos = null
	missoes = null
	eventos = null
	sessao_rede = null

func _process(dt: float) -> void:
	if Engine.is_editor_hint() or controles == null or not is_instance_valid(controles) or get_tree().paused or carregamento != null:
		return
	_tempo_jogo += dt
	_t_salvar += dt
	if _t_salvar >= AUTOSALVAR:
		salvar_jogo()
	if jogador.vel_horizontal > 5.0:
		Musica.adicionar_tensao(dt * 0.045)            # correndo: a música aperta
	if is_instance_valid(clima):
		Musica.noite = clima.hora < 5.5 or clima.hora > 20.0   # de noite toca a "Noite sem Luz"
	if voo.ativo:
		return
	_t_info -= dt
	if _t_info <= 0.0 and controles.info.visible:     # trocar o texto refaz a fonte: 2 vezes por segundo basta
		_t_info = 0.5
		var p := jogador.global_position
		controles.info.text = "FPS %d · x %d z %d · %d km/h" % [Engine.get_frames_per_second(), int(p.x), int(p.z), int(jogador.vel_horizontal * 3.6)]

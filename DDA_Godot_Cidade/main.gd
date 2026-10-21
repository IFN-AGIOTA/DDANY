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
const MatoCls := preload("res://mundo/mato.gd")
const FumacaCls := preload("res://mundo/fumaca.gd")
const HudStatusCls := preload("res://hud/hud_status.gd")
const MapaCls := preload("res://hud/mapa.gd")
const ClimaCls := preload("res://mundo/clima.gd")
const Salvamento := preload("res://menu/salvamento.gd")
const MissoesCls := preload("res://mundo/missoes.gd")
const AmbienteCls := preload("res://audio/ambiente.gd")
const HistoriaCls := preload("res://historia/historia.gd")
const VagosCls := preload("res://inimigos/vagos.gd")
const CompanheirosCls := preload("res://npc/companheiros.gd")
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
const JOGADOR_CENA := preload("res://jogador/jogador.tscn")
const SessaoRedeCls := preload("res://rede/sessao_rede.gd")
const TelaMultiCls := preload("res://menu/tela_multijogador.gd")
const TelaLoginCls := preload("res://menu/tela_login.gd")
const TelaPerfilCls := preload("res://menu/tela_perfil.gd")
const AvisoChamadoCls := preload("res://menu/aviso_chamado.gd")

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
var _t_info := 0.0
var missoes: Node = null                    # mundo/missoes.gd (suprimentos militares avisados pelo rádio)
var hud_status: CanvasLayer                 # hud/hud_status.gd (vida, sangue, fome, sede, temperatura)
var tela_morte: CanvasLayer
var mapa: CanvasLayer                       # hud/mapa.gd (minimapa, mapa grande e bússola)
var clima: Node                             # mundo/clima.gd (dia/noite, chuva, temperatura, lanterna)
var historia: CanvasLayer                   # historia/historia.gd (Ato 1)
var vagos: Node                             # inimigos/vagos.gd (infectados)
var companheiros: Node                      # npc/companheiros.gd (Greg e Mavie, depois do encontro)
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
	_abrir_menu()

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
	menu.historia.connect(func(): _jogar(false, true))
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

func _jogar(carregar_salvo := false, modo_historia := false) -> void:
	menu.mostrar_carregando()
	await get_tree().process_frame          # deixa o "CARREGANDO" aparecer antes de montar a cidade
	await get_tree().process_frame
	menu.queue_free()
	menu = null
	cena_menu.queue_free()
	cena_menu = null
	if not _cidade().is_built:
		cidade.construir()
	cidade.visible = true
	_criar_jogo()
	if carregar_salvo:
		var d := Salvamento.ler()
		if not d.is_empty():
			Salvamento.carregar(self, d)
			if d.get("morto", false):                # morreu e saiu: volta já renascido, longe das coisas
				jogador.morto = true
				_renascer()
	elif modo_historia:
		historia.iniciar(self)
	if not modo_historia:
		Sons.tocar("partida/entrada", -3.0)        # 0.49: entrada da partida (pancada grave + eco + coração)
	jogador.usar_sobrevivente()             # o personagem do jogador (livre e história): jogador/modelo_sobrevivente.gd
	_ligar_rede()

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
	if Rede.ligado:
		return                               # partida em rede ainda não salva (não estraga o jogo salvo sozinho)
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
	pausa.reiniciar.connect(func():
		_continuar()
		_fechar_jogo()
		_criar_jogo()
		jogador.usar_sobrevivente()
		_ligar_rede())
	pausa.menu_principal.connect(func():
		salvar_jogo()
		_continuar()
		_abrir_menu())

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
	jogo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(jogo)
	controles = ControlesCls.new()
	controles.name = "Controles"
	jogo.add_child(controles)
	controles.pausa_pedida.connect(_pausar)
	mundo = ColisaoMundoCls.new()
	mundo.name = "ColisaoMundo"
	jogo.add_child(mundo)
	mundo.configurar(cidade.dados_cidade, cidade.predios)
	mundo.configurar_lotes(cidade.lote, cidade.W, cidade.H, cidade.CELL, cidade.WORLD, cidade.RAMPA_LOTE)   # chão dos quarteirões
	chunks = ChunksCls.new()
	chunks.name = "Chunks"
	jogo.add_child(chunks)
	chunks.configurar(cidade, AplicarOpcoesCls.raio_chunks())
	if cidade.abandono != null:
		mundo.configurar_obstaculos(cidade.abandono.obstaculos)
	jogador = JOGADOR_CENA.instantiate()
	jogador.name = "Jogador"
	jogador.mundo = mundo
	jogo.add_child(jogador)
	jogador.ligar_controles(controles)
	hud = HudCls.new()
	hud.name = "HudCombate"
	jogo.add_child(hud)
	hud.ligar(jogador.armas, jogador)
	hud_status = HudStatusCls.new()
	hud_status.name = "HudStatus"
	jogo.add_child(hud_status)
	hud_status.ligar(jogador)
	mapa = MapaCls.new()
	mapa.name = "Mapa"
	jogo.add_child(mapa)
	mapa.ligar(cidade, jogador, controles)
	clima = ClimaCls.new()
	clima.name = "Clima"
	jogo.add_child(clima)
	clima.ligar(cidade, jogador)
	jogador.sobrevivencia.clima = clima
	vagos = VagosCls.new()
	vagos.name = "Vagos"
	jogo.add_child(vagos)
	vagos.ligar(cidade, mundo, jogador, jogador.armas)
	vagos.clima = clima
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
	companheiros = CompanheirosCls.new()
	companheiros.name = "Companheiros"
	jogo.add_child(companheiros)
	companheiros.ligar(jogador, mundo, vagos)
	historia = HistoriaCls.new()
	historia.name = "Historia"
	historia.main = self
	jogo.add_child(historia)
	jogador.sobrevivencia.morreu.connect(_morreu)
	jogador.sobrevivencia.aviso.connect(func(t): hud.mostrar_aviso(t))
	abates = 0
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
	LootCls.espalhar(jogo, mundo, SPAWN)
	loot_mundo = LootMundoCls.new()
	loot_mundo.semente = randi()                      # cada jogo novo tem o loot em lugares diferentes
	interiores = InterioresCls.new()
	interiores.name = "Interiores"
	jogo.add_child(interiores)
	interiores.ligar(cidade, mundo, jogador, loot_mundo)
	interiores.vagos = vagos
	missoes = MissoesCls.new()
	missoes.name = "Missoes"
	jogo.add_child(missoes)
	missoes.ligar(self)
	var amb := AmbienteCls.new()
	amb.name = "AmbienteCidade"
	jogo.add_child(amb)
	amb.ligar(self)
	voo = CameraVooCls.new()
	voo.name = "CameraVoo"
	jogo.add_child(voo)
	voo.ligar(jogador, controles, mundo, tela_inventario)
	jogador.camera.make_current()
	aplicador.aplicar()
	# música: tiros e acertos aumentam a tensão (ela desce sozinha)
	Musica.definir_modo("jogo")
	jogador.armas.disparou.connect(func(_a): Musica.adicionar_tensao(0.05))
	jogador.armas.acertou.connect(func(_c, matou): Musica.adicionar_tensao(0.12 if matou else 0.03))

# ---------- morte e renascimento ----------
func _morreu(causa: String) -> void:
	if jogador == null:
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
	Musica.adicionar_tensao(1.0)
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

func _fechar_morte() -> void:
	if tela_morte != null:
		tela_morte.queue_free()
		tela_morte = null

func _renascer() -> void:
	_fechar_morte()
	var morte := Vector2(jogador.global_position.x, jogador.global_position.z)
	var p := _ponto_renascer(morte)
	jogador.morto = false
	Sons.tocar("partida/entrada", -8.0)
	jogador.sobrevivencia.reiniciar()
	jogador.inventario.equipamento_renascer()
	mundo.forcar(p)
	jogador.teleportar(Vector3(p.x, mundo.altura(p.x, p.y) + 0.1, p.y), randf() * TAU)
	controles.set_bloqueado(false)
	abates = 0
	if companheiros != null:
		companheiros.reagrupar()
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
	if interiores != null and is_instance_valid(interiores):
		interiores.fechar_todos()           # devolve os blocos dos prédios para a cidade
	interiores = null
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
	historia = null
	vagos = null
	missoes = null
	companheiros = null
	sessao_rede = null

func _process(dt: float) -> void:
	if Engine.is_editor_hint() or controles == null or not is_instance_valid(controles) or get_tree().paused:
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

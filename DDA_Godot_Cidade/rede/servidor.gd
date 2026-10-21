extends Node
# SERVIDOR DEDICADO (0.50): o jogo rodando no PC (Windows) SEM tela, só cuidando do mundo. Os celulares entram
# nele como numa partida normal ("Entrar" com o IP do PC). Abra com o servidor.bat (pasta servidor_windows/):
#   DiasDeUmApocalipse_Servidor.exe --headless -- --servidor --nome="Servidor do PC"
# O que ele faz:
#   · monta a cidade e abre a partida na porta UDP 24560 (rede/rede.gd, servidor_dedicado = true): já começa
#     aberta, quem entra vai direto para a cidade; anuncia no Wi-Fi e tenta abrir a porta no roteador (UPnP)
#   · manda nos infectados, no tempo/clima, na semente do loot e nos itens (igual ao host de antes), mas NÃO é
#     jogador: não aparece, não leva dano, não manda posição
#   · o "jogador" invisível dele acompanha um dos amigos (FOCO): é em volta dele que o servidor monta o chão e os
#     prédios com física (infectados entram nos prédios atrás de quem está em foco). Com vários amigos, o foco passa
#     de um para o outro a cada TROCA_FOCO segundos
#   · sem ninguém conectado, nenhum infectado nasce (o PC fica leve)
#   · escreve no console: endereços para entrar, quem entrou/saiu e, a cada minuto, um resumo
# Mexa AQUI para: nome padrão, FPS do servidor, troca de foco, resumo.

const NOME_PADRAO := "Servidor do PC"
const RtcCls := preload("res://rede/rtc.gd")
const FPS := 60
const TROCA_FOCO := 8.0
const RESUMO_A_CADA := 60.0

var main: Node
var _t_foco := 0.0
var _i_foco := 0
var _t_resumo := RESUMO_A_CADA
var _inicio := 0.0

# o jogo foi aberto como servidor? (argumento --servidor depois do "--")
static func pedido() -> bool:
	return "--servidor" in OS.get_cmdline_user_args() or "--servidor" in OS.get_cmdline_args()

static func _arg(nome: String, padrao: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nome + "="):
			return a.substr(nome.length() + 3).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return padrao

func iniciar(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inicio = Time.get_ticks_msec() / 1000.0
	Engine.max_fps = FPS                         # sem isso, sem tela, ele gira o processador a 100%
	var nome := _arg("nome", NOME_PADRAO)
	_log("Dias de um Apocalipse %s · SERVIDOR \"%s\" · montando a cidade..." % [Config.VERSAO, nome])
	main._cidade().construir()
	main._criar_jogo()
	var j = main.jogador
	j.servidor = true
	j.visible = false
	j.process_mode = Node.PROCESS_MODE_DISABLED  # não anda, não tem fome, não morre
	main.vagos.sem_jogador = true
	if main.missoes != null:
		main.missoes.process_mode = Node.PROCESS_MODE_DISABLED   # missões do rádio são de cada jogador
	Engine.max_fps = FPS
	Rede.servidor_dedicado = true
	Rede.internet.connect(_internet)
	Rede.jogador_entrou.connect(func(id, nm): _log("ENTROU: %s (id %d) · %d na partida" % [nm, id, Rede.jogadores.size()]))
	Rede.jogador_saiu.connect(func(id): _log("SAIU: id %d · %d na partida" % [id, Rede.jogadores.size()]))
	Rede.falhou.connect(func(motivo): _log("ERRO: " + motivo))
	Rede.rtc.diagnostico.connect(_log)          # 0.53: cada tentativa de conexão pela internet aparece aqui
	_log("retransmissor (TURN): %s" % ("configurado" if Rede.rtc.tem_turn else "NÃO configurado (rede/turn.cfg)"))
	await _entrar_na_conta(nome)
	Rede.criar_partida(nome, randi())
	if not Rede.ligado:
		_log("Não deu para abrir a partida. Feche outro jogo/servidor que esteja usando a porta %d e tente de novo." % Rede.PORTA)
		return
	main._ligar_rede()
	_log("PRONTO. Para entrar: no celular, Multijogador > Entrar e digite um destes endereços:")
	for ip in Rede.meus_ips():
		var tipo := "Tailscale" if ip.begins_with("100.") else "mesmo Wi-Fi"
		_log("   %s   (%s)" % [ip, tipo])
	if Rede.aceita_rtc():
		Conta._t_publicar = 0.0                  # aparece na lista agora (depois a cada 45 s)
		_log("PELA INTERNET (técnica do WhatsApp, sem abrir porta): no celular, Multijogador > Entrar > SERVIDORES >")
		_log("   \"%s\". Funciona de qualquer lugar (Wi-Fi de outra casa, 4G)." % nome)
	else:
		_log("   (pela internet: o IP da internet aparece abaixo se o roteador abrir a porta sozinho)")
	_log("Para desligar o servidor: feche esta janela.")

# 0.51: entra como CONVIDADO no Firebase (a conta fica salva no PC: o servidor tem sempre o mesmo id) para
# aparecer na lista de SERVIDORES e aceitar conexões pela internet com WebRTC (rede/rtc.gd)
func _entrar_na_conta(nome: String) -> void:
	Conta.nome_servidor = nome
	if not Conta.configurado:
		_log("INTERNET (WebRTC): sem rede/firebase_config.cfg: só por IP.")
		return
	if not RtcCls.disponivel():
		_log("INTERNET (WebRTC): a biblioteca libwebrtc_native...dll não está junto do servidor: só por IP.")
		return
	if not Conta.logado:
		_log("entrando na conta do servidor (convidado)...")
		Conta.entrar_convidado()
		var t0 := Time.get_ticks_msec()
		while not Conta.logado and Time.get_ticks_msec() - t0 < 20000:
			await get_tree().create_timer(0.25).timeout
	if Conta.logado:
		_log("conta do servidor OK (id %s)." % Conta.uid.left(8))
	else:
		_log("INTERNET (WebRTC): não deu para entrar na conta (sem internet?). Continua só por IP.")

func _internet(ok: bool, ip: String, motivo: String) -> void:
	if ok:
		_log("INTERNET: porta %d aberta no roteador. Amigos de fora entram com  %s" % [Rede.PORTA, ip])
	else:
		_log("INTERNET: o roteador não abriu a porta sozinho (%s). Use o Tailscale ou abra a porta UDP %d à mão." % [motivo, Rede.PORTA])

func _process(dt: float) -> void:
	if Engine.max_fps != FPS:
		Engine.max_fps = FPS                     # as Opções (menu/aplicar_opcoes.gd) reaplicam e soltam o limite
	if main == null or main.jogador == null or main.sessao_rede == null:
		return
	# o "jogador" do servidor vai para perto de um amigo (chão e prédios com física em volta dele)
	_t_foco -= dt
	var vivos: Array = []
	for r in main.sessao_rede.remotos.values():
		if is_instance_valid(r) and r.visible:
			vivos.append(r)
	if not vivos.is_empty():
		if _t_foco <= 0.0:
			_t_foco = TROCA_FOCO
			_i_foco = (_i_foco + 1) % vivos.size()
		var alvo: Node3D = vivos[_i_foco % vivos.size()]
		main.jogador.global_position = alvo.global_position
	_t_resumo -= dt
	if _t_resumo <= 0.0:
		_t_resumo = RESUMO_A_CADA
		var minutos := int((Time.get_ticks_msec() / 1000.0 - _inicio) / 60.0)
		_log("resumo: %d jogador(es) · %d infectados · %d FPS · hora do jogo %02d:%02d · ligado há %d min" % [
			Rede.jogadores.size(), main.vagos.vivos.size(), Engine.get_frames_per_second(),
			int(main.clima.hora), int(fmod(main.clima.hora, 1.0) * 60.0), minutos])

func _log(t: String) -> void:
	print("[%s] %s" % [Time.get_time_string_from_system(), t])

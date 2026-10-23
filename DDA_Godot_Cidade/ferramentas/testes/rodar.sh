#!/usr/bin/env bash
# RODA OS TESTES AUTOMÁTICOS DO JOGO (0.74). Dentro da pasta DDA_Godot_Cidade:
#   GODOT=/caminho/do/godot ferramentas/testes/rodar.sh          (todos, menos rede)
#   GODOT=... ferramentas/testes/rodar.sh rede                     (só o teste de dois jogos conectados)
#   GODOT=... ferramentas/testes/rodar.sh teste_agua               (só um)
# Sem monitor (servidor/CI) usa xvfb-run. Cada teste imprime "falhas: N"; o script termina com erro se algum falhar.
# Os testes usam uma pasta de dados própria (não mexem no seu jogo salvo).
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../.."
DADOS="$(mktemp -d)"
TELA=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then TELA=(xvfb-run -a -s "-screen 0 1280x720x24"); fi
falhou=0
rodar() {   # nome, com_tela(0/1)
	local saida
	if [ "$2" = 1 ]; then
		saida=$(XDG_DATA_HOME="$DADOS/$1" timeout 600 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s "res://ferramentas/testes/$1.gd" 2>&1)
	else
		saida=$(XDG_DATA_HOME="$DADOS/$1" timeout 300 "$GODOT" --headless -s "res://ferramentas/testes/$1.gd" 2>&1)
	fi
	echo "$saida" | grep -E "FALHA|SCRIPT ERROR" | head -20
	local n
	n=$(echo "$saida" | grep -oE "falhas: [0-9]+" | tail -1 | grep -oE "[0-9]+")
	if [ -z "$n" ]; then echo "[$1] NÃO TERMINOU"; falhou=1; return; fi
	echo "[$1] falhas: $n"
	[ "$n" = 0 ] || falhou=1
}
alvo="${1:-todos}"
if [ "$alvo" = rede ]; then
	XDG_DATA_HOME="$DADOS/h" timeout 240 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_amigo_host.gd > "$DADOS/host.txt" 2>&1 &
	sleep 2
	XDG_DATA_HOME="$DADOS/c" timeout 240 "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_amigo_cliente.gd > "$DADOS/cli.txt" 2>&1
	wait
	grep -E "HOST:|SCRIPT ERROR" "$DADOS/host.txt"
	grep -E "CLI:|SCRIPT ERROR" "$DADOS/cli.txt"
	grep -q "com física: [1-9]" "$DADOS/host.txt" && grep -q "cópias de infectados perto: [1-9]" "$DADOS/cli.txt" || falhou=1
elif [ "$alvo" = todos ]; then
	rodar compilar_tudo 0
	rodar teste_loot_volta 0
	rodar teste_jogo 1
	rodar teste_agua 1
	rodar teste_portas 1
	rodar teste_tiro_locais 1
else
	rodar "$alvo" 1
fi
rm -rf "$DADOS"
[ $falhou = 0 ] && echo "TUDO CERTO" || echo "ALGUM TESTE FALHOU"
exit $falhou

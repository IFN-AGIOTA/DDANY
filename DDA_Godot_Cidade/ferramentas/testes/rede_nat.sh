#!/usr/bin/env bash
# TESTE DA LIGAÇÃO DIRETA (0.86) COM ROTEADORES DE MENTIRA (precisa de Linux, root e iproute2/iptables):
#   host (192.168.1.2) -- roteador A (NAT) -- "internet" (198.51.100.1: STUN/TURN de mentira) -- roteador B (NAT) -- amigo (192.168.2.2)
# Uso: GODOT=... sudo ferramentas/testes/rede_nat.sh [cone|simetrico]
#   cone ......... os dois roteadores comuns (Linux MASQUERADE: guarda a porta) -> espera LIGAÇÃO DIRETA
#   simetrico .... o roteador do AMIGO troca a porta a cada destino (como alguns 4G) -> espera o RETRANSMISSOR
set -u
GODOT="${GODOT:-godot}"
TIPO="${1:-cone}"
cd "$(dirname "$0")/../.."
DADOS="$(mktemp -d)"
TELA=(xvfb-run -a -s "-screen 0 1280x720x24")
limpar() { for n in dda_host dda_natA dda_inet dda_natB dda_cli; do ip netns del $n 2>/dev/null; done; }
limpar
for n in dda_host dda_natA dda_inet dda_natB dda_cli; do ip netns add $n; ip -n $n link set lo up; done
liga() { ip link add $1 type veth peer name $3; ip link set $1 netns $2; ip link set $3 netns $4; ip -n $2 link set $1 up; ip -n $4 link set $3 up; }
liga vA0 dda_host vA1 dda_natA
liga wA0 dda_natA wA1 dda_inet
liga wB0 dda_natB wB1 dda_inet
liga vB0 dda_cli vB1 dda_natB
ip -n dda_host addr add 192.168.1.2/24 dev vA0; ip -n dda_host route add default via 192.168.1.1
ip -n dda_natA addr add 192.168.1.1/24 dev vA1; ip -n dda_natA addr add 198.51.100.2/24 dev wA0; ip -n dda_natA route add default via 198.51.100.1
ip -n dda_inet addr add 198.51.100.1/24 dev wA1; ip -n dda_inet addr add 203.0.113.1/24 dev wB1
ip -n dda_natB addr add 203.0.113.2/24 dev wB0; ip -n dda_natB addr add 192.168.2.1/24 dev vB1; ip -n dda_natB route add default via 203.0.113.1
ip -n dda_cli addr add 192.168.2.2/24 dev vB0; ip -n dda_cli route add default via 192.168.2.1
for n in dda_natA dda_inet dda_natB; do ip netns exec $n sysctl -qw net.ipv4.ip_forward=1; done
ip netns exec dda_natA iptables -t nat -A POSTROUTING -o wA0 -j MASQUERADE
if [ "$TIPO" = simetrico ]; then
	ip netns exec dda_natB iptables -t nat -A POSTROUTING -o wB0 -j MASQUERADE --random-fully
else
	ip netns exec dda_natB iptables -t nat -A POSTROUTING -o wB0 -j MASQUERADE
fi
# os roteadores não deixam entrar nada que ninguém de dentro chamou
for n in dda_natA dda_natB; do
	ip netns exec $n iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	ip netns exec $n iptables -A FORWARD -i vA1 -j ACCEPT 2>/dev/null; ip netns exec $n iptables -A FORWARD -i vB1 -j ACCEPT 2>/dev/null
	ip netns exec $n iptables -P FORWARD DROP
	# firewall do roteador (como os de casa): pacote "novo" vindo da internet para o próprio roteador é jogado fora
	ip netns exec $n iptables -A INPUT -i wA0 -m conntrack --ctstate NEW -j DROP 2>/dev/null
	ip netns exec $n iptables -A INPUT -i wB0 -m conntrack --ctstate NEW -j DROP 2>/dev/null
done
TURN_FALSO_IP=198.51.100.1 TURN_FALSO_TEMPO=200 ip netns exec dda_inet python3 ferramentas/testes/turn_falso.py 3478 teste segredo > "$DADOS/turn.txt" 2>&1 &
sleep 1
export DDA_TURN="198.51.100.1:3478:teste:segredo" DDA_TROCA="$DADOS"
XDG_DATA_HOME="$DADOS/h" timeout 180 ip netns exec dda_host "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_direto_host.gd > "$DADOS/host.txt" 2>&1 &
sleep 2
XDG_DATA_HOME="$DADOS/c" timeout 180 ip netns exec dda_cli "${TELA[@]}" "$GODOT" --rendering-driver opengl3 -s res://ferramentas/testes/rede_direto_cliente.gd > "$DADOS/cli.txt" 2>&1
wait %2 2>/dev/null
kill %1 2>/dev/null
grep -E "HOST:|REDE:|SCRIPT ERROR" "$DADOS/host.txt"
grep -E "CLI:|REDE:|SCRIPT ERROR" "$DADOS/cli.txt"
limpar
ok=1
grep -q "amigo entrou: true" "$DADOS/host.txt" && grep -q "CLI: ligado true · semente 77" "$DADOS/cli.txt" || ok=0
if [ "$TIPO" = simetrico ]; then grep -q "CLI: via retransmissor" "$DADOS/cli.txt" || ok=0
else grep -q "CLI: via direta" "$DADOS/cli.txt" || ok=0; fi
echo "(registros em $DADOS)"
[ $ok = 1 ] && echo "TUDO CERTO ($TIPO)" || echo "ALGUM TESTE FALHOU ($TIPO)"

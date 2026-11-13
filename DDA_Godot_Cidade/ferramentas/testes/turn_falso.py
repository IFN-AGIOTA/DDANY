#!/usr/bin/env python3
# RETRANSMISSOR TURN DE MENTIRA para os testes (0.85): faz o papel da Metered no PC, sem internet.
# Só biblioteca padrão. Implementa o que rede/turn.gd usa (RFC 5766/5389): Binding, Allocate (com o desafio 401 e a
# senha de longo prazo: MESSAGE-INTEGRITY HMAC-SHA1, chave = MD5(usuario:realm:senha)), Refresh (o 1º responde 438
# "nonce velho" para testar a troca), CreatePermission, ChannelBind, Send/Data indication e ChannelData.
# Confere a senha de todo pedido. Uso: python3 turn_falso.py PORTA USUARIO SENHA [arquivo_log]
import socket, struct, hmac, hashlib, os, select, sys, time

MC = 0x2112A442
PORTA = int(sys.argv[1]) if len(sys.argv) > 1 else 3478
USUARIO = sys.argv[2] if len(sys.argv) > 2 else "teste"
SENHA = sys.argv[3] if len(sys.argv) > 3 else "segredo"
LOG = open(sys.argv[4], "a") if len(sys.argv) > 4 else None
REALM = b"teste.local"
nonce = [b"nonce-1"]
CHAVE = hashlib.md5(USUARIO.encode() + b":" + REALM + b":" + SENHA.encode()).digest()

def log(*a):
    s = " ".join(str(x) for x in a)
    print("TURN:", s, flush=True)
    if LOG:
        LOG.write(s + "\n"); LOG.flush()

def attr(t, v):
    return struct.pack("!HH", t, len(v)) + v + b"\0" * ((4 - len(v) % 4) % 4)

def xor_end(ip, porta):
    ipn = struct.unpack("!I", socket.inet_aton(ip))[0]
    return struct.pack("!BBHI", 0, 1, porta ^ (MC >> 16), ipn ^ MC)

def ler_xor(v):
    porta = struct.unpack("!H", v[2:4])[0] ^ (MC >> 16)
    ipn = struct.unpack("!I", v[4:8])[0] ^ MC
    return socket.inet_ntoa(struct.pack("!I", ipn)), porta

def parse(d):
    tp, ln, mc = struct.unpack("!HHI", d[:8])
    if mc != MC:
        return None
    a, ordem, i = {}, [], 20
    while i < 20 + ln:
        t, l = struct.unpack("!HH", d[i:i + 4])
        a.setdefault(t, d[i + 4:i + 4 + l]); ordem.append((t, i))
        i += 4 + l + ((4 - l % 4) % 4)
    return tp, d[8:20], a, ordem

def integridade_ok(d, ordem):
    for t, i in ordem:
        if t == 0x0008:
            cab = d[:2] + struct.pack("!H", i - 20 + 24) + d[4:20]
            esperado = hmac.new(CHAVE, cab + d[20:i], hashlib.sha1).digest()
            return esperado == d[i + 4:i + 24]
    return False

def resposta(tp, tid, attrs):
    corpo = b"".join(attrs)
    return struct.pack("!HHI", tp, len(corpo), MC) + tid + corpo

def erro(tp, tid, cod, motivo=b"erro", com_nonce=True):
    v = struct.pack("!HBB", 0, cod // 100, cod % 100) + motivo
    at = [attr(0x0009, v)]
    if com_nonce:
        at += [attr(0x0014, REALM), attr(0x0015, nonce[0])]
    return resposta(tp | 0x0110, tid, at)

ctl = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
IP_PUBLICO = os.environ.get("TURN_FALSO_IP", "127.0.0.1")    # 0.86: na rede de mentira (rede_nat.sh) é o IP da "internet"
ctl.bind((IP_PUBLICO, PORTA))
alocs = {}            # endereço do cliente -> {"relay": sock, "perm": set(ip), "canal": {n: (ip,p)}, "canal_de": {(ip,p): n}}
relay_de = {}         # sock -> endereço do cliente
refresh_438 = [True]
log("ouvindo em", PORTA)
fim = time.time() + float(os.environ.get("TURN_FALSO_TEMPO", "600"))
while time.time() < fim:
    socks = [ctl] + list(relay_de.keys())
    prontos, _, _ = select.select(socks, [], [], 0.5)
    for s in prontos:
        d, de = s.recvfrom(65535)
        if s is not ctl:                                    # chegou no endereço público: vai para o cliente
            cli = relay_de[s]; al = alocs[cli]
            if de[0] not in al["perm"]:
                log("descartado (sem permissão):", de); continue
            n = al["canal_de"].get(de)
            if n:
                m = struct.pack("!HH", n, len(d)) + d + b"\0" * ((4 - len(d) % 4) % 4)
            else:
                m = resposta(0x0017, os.urandom(12), [attr(0x0012, xor_end(*de)), attr(0x0013, d)])
            ctl.sendto(m, cli); continue
        if len(d) >= 4 and (d[0] & 0xC0) == 0x40:          # ChannelData do cliente
            n, l = struct.unpack("!HH", d[:4]); al = alocs.get(de)
            if al and n in al["canal"]:
                al["relay"].sendto(d[4:4 + l], al["canal"][n])
            continue
        p = parse(d)
        if not p:
            continue
        tp, tid, a, ordem = p
        if tp == 0x0001:                                    # Binding
            ctl.sendto(resposta(0x0101, tid, [attr(0x0020, xor_end(*de))]), de); continue
        if tp == 0x0016:                                    # Send indication
            al = alocs.get(de)
            if al and 0x0012 in a and 0x0013 in a:
                alvo = ler_xor(a[0x0012])
                if alvo[0] in al["perm"]:
                    al["relay"].sendto(a[0x0013], alvo)
            continue
        if 0x0008 not in a:
            ctl.sendto(erro(tp, tid, 401, b"Unauthorized"), de); log("401 (sem senha) tipo %04x" % tp); continue
        if a.get(0x0015) != nonce[0]:
            ctl.sendto(erro(tp, tid, 438, b"Stale Nonce"), de); log("438 tipo %04x" % tp); continue
        if a.get(0x0006, b"").decode() != USUARIO or not integridade_ok(d, ordem):
            ctl.sendto(erro(tp, tid, 401, b"senha errada"), de); log("SENHA ERRADA tipo %04x" % tp); continue
        if tp == 0x0003:                                    # Allocate
            if de not in alocs:
                r = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); r.bind((IP_PUBLICO, 0))
                alocs[de] = {"relay": r, "perm": set(), "canal": {}, "canal_de": {}}; relay_de[r] = de
            rp = alocs[de]["relay"].getsockname()
            log("ALLOCATE ok ->", rp)
            ctl.sendto(resposta(0x0103, tid, [attr(0x0016, xor_end(*rp)), attr(0x0020, xor_end(*de)), attr(0x000D, struct.pack("!I", 600))]), de)
        elif tp == 0x0004:                                  # Refresh
            if refresh_438[0]:
                refresh_438[0] = False; nonce[0] = b"nonce-2"
                ctl.sendto(erro(tp, tid, 438, b"Stale Nonce"), de); log("438 de propósito (nonce novo)"); continue
            log("REFRESH ok")
            ctl.sendto(resposta(0x0104, tid, [attr(0x000D, a.get(0x000D, struct.pack("!I", 600)))]), de)
        elif tp == 0x0008:                                  # CreatePermission
            ip = ler_xor(a[0x0012])[0]; alocs[de]["perm"].add(ip); log("PERMISSÃO para", ip)
            ctl.sendto(resposta(0x0108, tid, []), de)
        elif tp == 0x0009:                                  # ChannelBind
            n = struct.unpack("!H", a[0x000C][:2])[0]; pe = ler_xor(a[0x0012])
            alocs[de]["canal"][n] = pe; alocs[de]["canal_de"][pe] = n; alocs[de]["perm"].add(pe[0]); log("CANAL %x ->" % n, pe)   # o canal também libera o IP (RFC 5766)
            ctl.sendto(resposta(0x0109, tid, []), de)

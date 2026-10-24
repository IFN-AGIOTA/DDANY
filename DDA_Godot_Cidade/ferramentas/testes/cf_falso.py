#!/usr/bin/env python3
# API DA CLOUDFLARE DE MENTIRA para os testes (0.88): responde como .../turn/keys/{id}/credentials/generate.
# Só aceita a chave "abc" com o token "teste" e devolve o usuário/senha do retransmissor de mentira (turn_falso.py).
# Uso: python3 cf_falso.py PORTA USUARIO SENHA
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORTA = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
USUARIO = sys.argv[2] if len(sys.argv) > 2 else "teste"
SENHA = sys.argv[3] if len(sys.argv) > 3 else "segredo"

class Api(BaseHTTPRequestHandler):
    def do_POST(self):
        corpo = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        ok = self.path.rstrip("/").endswith("/abc") and self.headers.get("Authorization") == "Bearer teste"
        try:
            ok = ok and int(json.loads(corpo).get("ttl", 0)) > 0
        except Exception:
            ok = False
        print("CF: pedido %s -> %s" % (self.path, "ok" if ok else "recusado"), flush=True)
        r = json.dumps({"iceServers": {"urls": ["turn:127.0.0.1:3478?transport=udp"], "username": USUARIO, "credential": SENHA}} if ok
            else {"error": "unauthorized"}).encode()
        self.send_response(201 if ok else 401)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(r)))
        self.end_headers()
        self.wfile.write(r)
    def log_message(self, *a):
        pass

HTTPServer(("127.0.0.1", PORTA), Api).serve_forever()

// 1.20 · GERA AS ÁRVORES DO JOGO com o EZ-Tree (https://github.com/dgreenheck/ez-tree, licença MIT) num navegador sem tela.
// Uso (ferramentas/arvores_ez/LEIA-ME.txt):
//   cd <pasta com node_modules do @dgreenheck/ez-tree@1.1.0 e do three@0.170.0>
//   node <projeto>/ferramentas/arvores_ez/gerar.mjs <pasta com node_modules> <pasta de saída> [nomes,separados]
// Para cada variante de variantes.json grava <saída>/<nome>.glb (só a geometria) e, no fim, <saída>/variantes_geradas.json
// (tipo de casca/folha, cores e escala da textura de cada uma). Depois: ferramentas/preparar_arvores.gd.
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const { chromium } = createRequire(import.meta.url)('playwright');
const aqui = path.dirname(fileURLToPath(import.meta.url));
const raiz = path.resolve(process.argv[2]);
const saida = path.resolve(process.argv[3]);
const so = process.argv[4] ? process.argv[4].split(',') : null;
const cfg = JSON.parse(fs.readFileSync(path.join(aqui, 'variantes.json'), 'utf8'));
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript' };
const srv = http.createServer((q, r) => {
  const u = decodeURIComponent(q.url.split('?')[0]);
  const f = u === '/gerar.html' ? path.join(aqui, 'gerar.html') : path.join(raiz, u);
  if (!(f.startsWith(raiz) || f === path.join(aqui, 'gerar.html')) || !fs.existsSync(f)) { r.writeHead(404); r.end(); return; }
  r.writeHead(200, { 'Content-Type': tipos[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(r);
}).listen(8765);
const nav = await chromium.launch();
const pg = await nav.newPage();
pg.on('pageerror', e => console.log('erro na página:', e.message));
await pg.goto('http://127.0.0.1:8765/gerar.html');
await pg.waitForFunction('window.pronto === true', null, { timeout: 60000 });
fs.mkdirSync(saida, { recursive: true });
const arq_info = path.join(saida, 'variantes_geradas.json');
const geradas = fs.existsSync(arq_info) ? JSON.parse(fs.readFileSync(arq_info, 'utf8')) : {};
for (const v of cfg.variantes) {
  if (so && !so.includes(v.nome)) continue;
  const leve = Object.assign({}, cfg.leve, { alvo: v.alvo || cfg.leve.alvo });
  const r = await pg.evaluate(([a, b, c, d]) => window.gerar(a, b, c, d), [v.preset, v.ajuste || {}, leve, !!v.seca]);
  fs.writeFileSync(path.join(saida, v.nome + '.glb'), Buffer.from(r.glb, 'base64'));
  geradas[v.nome] = Object.assign({ altura: v.altura, tipo: v.tipo, seca: !!v.seca }, r.info);
  console.log('GEROU', v.nome, r.info.tris, 'triângulos');
}
fs.writeFileSync(arq_info, JSON.stringify(geradas, null, 1));
await nav.close();
srv.close();

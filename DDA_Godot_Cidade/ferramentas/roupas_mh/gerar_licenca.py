# jogador/roupas/LICENCA.txt: cada peça usada, autor e licença (do .mhclo; senão, da página dos asset packs)
import json, re, glob, os
from catalogo import I, pecas
idx = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roupas2", "idx.json"))) if os.path.exists("../roupas2/idx.json") else {}
usadas = sorted({p.split("__")[0] for it in I for p in pecas(it[5])})
linhas = []; autores_by = set(); autores_0 = set()
for nm in usadas:
    lic = None; autor = None
    for f in glob.glob("roupas/%s/*.mhclo" % nm):
        for l in open(f, encoding="utf-8", errors="ignore"):
            m = re.match(r"#\s*license:?\s*(.+)", l, re.I)
            if m and not lic: lic = m.group(1).strip()
            m = re.match(r"#\s*author:?\s*(.+)", l, re.I)
            if m and not autor: autor = m.group(1).strip()
            if "explicitly released as CC0" in l and not lic: lic = "CC0"
    d = idx.get(nm, {})
    autor = d.get("autor") or autor or "?"
    if autor == "makehuman_system": autor = "MakeHuman Team (Data Collection AB, Joel Palmius, Jonas Hauquier)"
    lic_p = d.get("lic", "")
    eh_by = "BY" in lic_p.upper() or (lic is not None and "BY" in lic.upper())   # na dúvida, dá o crédito
    if not eh_by:
        lic_f = "CC0 1.0 (domínio público)"; autores_0.add(autor)
    else:
        v = "3.0" if lic and "3.0" in lic else "4.0"
        lic_f = "CC BY %s (crédito ao autor)" % v; autores_by.add(autor)
    linhas.append("  %-40s %-32s %s" % (nm, autor, lic_f))
txt = """ROUPAS 3D (1.11) · MakeHuman community assets · http://www.makehumancommunity.org
(asset packs: https://static.makehumancommunity.org/assets/assetpacks.html)
Ajustadas ao corpo do jogo (homem e mulher do "Universal Base Characters") por ferramentas/roupas_mh/ e
ferramentas/preparar_roupas.gd; texturas reduzidas para 512 px. Nada mais foi mudado no desenho das peças.
Licenças: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) e CC BY 4.0 / 3.0
(https://creativecommons.org/licenses/by/4.0/ · https://creativecommons.org/licenses/by/3.0/): as peças CC BY são
usadas com crédito aos autores abaixo (e na tela de Créditos do jogo).

  PEÇA                                     AUTOR                            LICENÇA
""" + "\n".join(linhas) + "\n"
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "jogador", "roupas", "LICENCA.txt"), "w").write(txt)
print("CC-BY:", sorted(autores_by)); print("CC0:", sorted(autores_0))

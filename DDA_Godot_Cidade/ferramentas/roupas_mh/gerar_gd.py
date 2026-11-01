# gera: o bloco de itens novos (inventario/itens.gd), jogador/roupas_tabela.gd (PECAS + LOOT)
import json, sys
from catalogo import I
LOOT_TAB = {"casa": [("casa_quarto", 2)], "loja": [("loja_roupas", 3)], "escritorio": [("escritorio", 1), ("armazem_escritorio", 1)],
    "militar": [("quartel_alojamento", 2), ("bunker_alojamento", 2), ("guarita_acampamento", 1), ("comboio", 1)],
    "policia": [("delegacia_vestiario", 2)], "hospital": [("hospital_enfermaria", 1), ("ambulancia", 1)],
    "bombeiros": [("ambulancia", 1)], "oficina": [("posto_oficina", 1), ("deposito", 1)], "fazenda": [("deposito", 1)],
    "deposito": [("deposito", 1), ("armazem_carga", 1)], "academia": [("escola_armario", 1)]}
def gd(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list): return "[" + ", ".join(gd(x) for x in v) + "]"
    if isinstance(v, float): return ("%.3f" % v).rstrip("0").rstrip(".") if v != int(v) else "%.1f" % v
    return str(v)
itens = []; pecas = {}; loot = {}; vistos = set()
for num, iid, nome, sigla, slot, pc, ex in I:
    if iid not in pecas: pecas[iid] = pc
    if ex.get("existe") or iid in vistos: continue
    vistos.add(iid)
    d = {"nome": nome, "sigla": sigla, "w": ex["w"], "h": ex["h"], "peso": ex["peso"], "max": 1, "cat": "roupa", "slot": slot}
    if "grade" in ex: d["grade"] = ex["grade"]
    if "grade_nome" in ex: d["grade_nome"] = ex["grade_nome"]
    if "bolsos" in ex: d["bolsos"] = ex["bolsos"]
    for k in ("calor", "imperm", "protecao"):
        if ex.get(k): d[k] = float(ex[k])
    if ex.get("inteiro"): d["corpo_inteiro"] = True
    if ex.get("cobre_cabelo"): d["cobre_cabelo"] = True
    d["desc"] = ex["desc"]
    itens.append((iid, d))
    for cat in ex.get("loot", []):
        for tab, w in LOOT_TAB.get(cat, []):
            loot.setdefault(tab, []).append([iid, w, 1, 1])
linhas = ["	# ----- 1.11 · ROUPAS 3D DO MAKEHUMAN (geradas por ferramentas/roupas_mh/gerar_gd.py; visual em jogador/roupas_tabela.gd) -----"]
for iid, d in itens:
    linhas.append("	%s: {%s}," % (json.dumps(iid), ", ".join("%s: %s" % (json.dumps(k), gd(v)) for k, v in d.items())))
open("bloco_itens.txt", "w").write("\n".join(linhas) + "\n")
t = ['extends RefCounted',
 '# 1.11 · QUAL MODELO 3D CADA ROUPA USA NO CORPO: as roupas do MakeHuman (makehumancommunity.org, CC0/CC-BY), ajustadas',
 '# ao corpo masculino e ao feminino por ferramentas/roupas_mh/ (ajustar_roupas.py) + ferramentas/preparar_roupas.gd ->',
 '# jogador/roupas/<peça>_<m|f>.res. item -> peça (ou {"m": peça do homem, "f": peça da mulher}).',
 '# O que não está aqui não aparece no corpo (só no inventário). GERADO por ferramentas/roupas_mh/gerar_gd.py.',
 '# Mexa AQUI para: trocar o visual de uma roupa · LOOT: onde as roupas novas aparecem (somado a mundo/loot_mundo.gd).',
 'const PECAS := {']
for iid, pc in pecas.items():
    t.append("	%s: %s," % (json.dumps(iid), json.dumps(pc)))
t.append("}")
t.append("const LOOT := {")
for tab, l in sorted(loot.items()):
    t.append("	%s: %s," % (json.dumps(tab), json.dumps(l)))
t.append("}")
t.append("")
t.append("static func peca(id: String, sexo := \"m\") -> String:")
t.append("	var p = PECAS.get(id, \"\")")
t.append("	if p is Dictionary:")
t.append("		return str(p.get(sexo, p.get(\"m\", \"\")))")
t.append("	return str(p)")
open("roupas_tabela.gd", "w").write("\n".join(t) + "\n")
print(len(itens), "itens novos;", len(pecas), "com visual;", sum(len(v) for v in loot.values()), "entradas de loot em", len(loot), "tabelas")

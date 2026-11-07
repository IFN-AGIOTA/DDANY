import json, zipfile, glob, os
tab = json.load(open("../roupas2/tabela.json"))
nomes = {t[1] for t in tab}
achou = {}
os.makedirs("roupas", exist_ok=True)
for z in sorted(glob.glob("zips/*.zip")):
    try: zf = zipfile.ZipFile(z)
    except Exception as e:
        print("zip ruim", z, e); continue
    for i in zf.namelist():
        if i.endswith("/"): continue
        partes = i.split("/")
        for k in range(1, len(partes)-1):
            if partes[k] in nomes and partes[k-1] == "clothes":
                destino = "roupas/" + partes[k] + "/" + "/".join(partes[k+1:])
                os.makedirs(os.path.dirname(destino), exist_ok=True)
                with open(destino, "wb") as f: f.write(zf.read(i))
                achou.setdefault(partes[k], z)
                break
print(len(achou), "de", len(nomes))
print("faltam:", sorted(nomes - set(achou)))

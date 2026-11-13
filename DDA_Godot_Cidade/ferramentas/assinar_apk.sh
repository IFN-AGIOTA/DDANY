#!/bin/sh
# ASSINAR O APK com a CHAVE NOVA (rotação de chave do Android, APK Signature Scheme v3).
# Rode DEPOIS de exportar o APK pela Godot. A Godot assina com qualquer chave; este script assina de novo:
#   · chave nova (dda_nova.keystore) + "linhagem" (prova, assinada pela chave antiga, de que a nova é a sucessora):
#     o APK novo instala POR CIMA do antigo, sem desinstalar e sem perder o jogo salvo.
#   · a chave antiga (dda_antiga.keystore, que vazou no GitHub público) perde o poder: num aparelho que já tem o APK
#     com a linhagem, APK assinado só com a chave antiga NÃO instala por cima (rollback desligado).
#   · Android 8 ou mais velho não entende a rotação: lá continua valendo a assinatura antiga (v1/v2).
# As chaves ficam na pasta chaves_privadas/ (fora do GitHub: .gitignore). Guarde uma cópia com você.
# Uso:  sh ferramentas/assinar_apk.sh ../DiasDeUmApocalipse.apk
#   CHAVES=pasta das chaves (padrão ../chaves_privadas) · APKSIGNER=caminho do apksigner (Android SDK build-tools)
set -e
APK="${1:-../DiasDeUmApocalipse.apk}"
CHAVES="${CHAVES:-../chaves_privadas}"
APKSIGNER="${APKSIGNER:-apksigner}"
for f in dda_antiga.keystore dda_nova.keystore linhagem.bin senha_keystore.txt; do
	[ -f "$CHAVES/$f" ] || { echo "ERRO: falta $CHAVES/$f"; exit 1; }
done
"$APKSIGNER" sign --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
	--rotation-min-sdk-version 28 \
	--ks "$CHAVES/dda_antiga.keystore" --ks-pass pass:android \
	--next-signer --ks "$CHAVES/dda_nova.keystore" --ks-pass "file:$CHAVES/senha_keystore.txt" \
	--lineage "$CHAVES/linhagem.bin" "$APK"
rm -f "$APK.idsig"
"$APKSIGNER" verify -v --print-certs "$APK" | grep -E "Verified using v3|Signer #1 certificate SHA-256|Number of signers" || true
echo "APK assinado: $APK"

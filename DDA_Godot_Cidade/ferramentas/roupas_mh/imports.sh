# cria o .import (VRAM + mipmaps, igual às texturas do personagem) para cada png de jogador/roupas/texturas sem .import
cd "$(dirname "$0")/../.."
for p in jogador/roupas/texturas/*.png; do
  [ -e "$p.import" ] && continue
  cat > "$p.import" <<EOT
[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://$p"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
EOT
done

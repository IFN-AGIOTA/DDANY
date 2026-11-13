// 1.11 · ROUPA 3D (jogador/roupas/*.res, feitas por ferramentas/preparar_roupas.gd)
// corte_y: some o que fica ABAIXO dessa altura (em pé, metros) - a calça "entra" na bota (jogador/modelo_sobrevivente.gd)
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 cor : source_color = vec4(1.0);
uniform float corte_y = -10.0;
uniform bool alfa = false;
uniform float sujeira = 0.0;          // 0..1: deixa a roupa mais escura e gasta (estado do item)
// CAMADAS: "baixo" = espessura (mm/255) das roupas que estão POR BAIXO desta, em cada vértice do corpo (1 texel por
// vértice, 256 por linha). CUSTOM0 = (distância desta peça até a pele, vértice do corpo mais perto). Onde a de baixo
// passaria por fora, esta se afasta da pele o necessário (+5 mm): o colete fica por fora da jaqueta, a camisa por fora
// da calça (jogador/modelo_sobrevivente.gd _camadas).
uniform sampler2D baixo : filter_nearest;
uniform bool usa_baixo = false;
varying float y_rep;
void vertex() {
	y_rep = UV2.x;
	if (usa_baixo) {
		int ib = int(CUSTOM0.g + 0.5);
		float e = texelFetch(baixo, ivec2(ib % 256, ib / 256), 0).r * 0.255;
		VERTEX += NORMAL * clamp(e + 0.005 - CUSTOM0.r, 0.0, 0.07);
	}
}
void fragment() {
	if (y_rep < corte_y) { discard; }
	vec4 c = texture(textura, UV) * cor;
	if (alfa && c.a < 0.5) { discard; }
	ALBEDO = c.rgb * (1.0 - 0.35 * sujeira);
	ROUGHNESS = 0.9;
}

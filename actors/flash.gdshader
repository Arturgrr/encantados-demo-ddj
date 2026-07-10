shader_type canvas_item;
// Flash de dano: mistura a cor do pixel em direção ao vermelho conforme `flash`
// (0 = normal, 1 = totalmente vermelho). Preserva o alpha, então pixels
// transparentes continuam invisíveis. Serve para Polygon2D (placeholder) e
// para Sprite2D/AnimatedSprite2D (sprites reais) sem mudança.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.15, 0.15);

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color, flash);
}

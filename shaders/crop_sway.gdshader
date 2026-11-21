shader_type canvas_item;
// C14b P3 (c14b_03-03): crops in the field sway and part when walked through.
// The whole field is one CanvasItem (batched draw_texture_rect calls), so the
// per-plant phase can't come from MODEL_MATRIX: farm.gd encodes it in each
// quad's modulate alpha (0.5..1.0), restored to 1 here. Bend pinned at the
// plant's base (UV.y = 1). A touch point (the player) bends plants within
// ~12 px away from it with a damped swing. Time/wind on game time (Anim).
uniform float game_t = 0.0;
uniform float wind = 0.25;
uniform float strength = 1.0;
uniform vec4 touch = vec4(0.0, 0.0, 0.0, -10.0); // x, y (layer px), direction (+-1), start time
varying vec4 vcol;

void vertex() {
	float ph = (COLOR.a - 0.5) * 2.0 * 6.2831;
	vcol = vec4(COLOR.rgb, 1.0);
	float k = clamp(1.0 - UV.y, 0.0, 1.0);
	k = k * k;
	float spd = 1.1 + wind * 1.1;
	float s = sin(game_t * spd + ph) + 0.35 * sin(game_t * spd * 2.3 + ph * 1.7);
	float px = (0.4 + 1.2 * wind) * strength * (s * 0.7 + 0.4 * wind);
	float age = game_t - touch.w;
	if (age >= 0.0 && age < 0.8) {
		float d = distance(VERTEX, touch.xy + vec2(0.0, -6.0));
		float near = 1.0 - smoothstep(4.0, 14.0, d);
		px += touch.z * near * 3.0 * exp(-age * 5.0) * cos(age * 18.0);
	}
	VERTEX.x += px * k;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * vcol;
}

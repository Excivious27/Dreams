shader_type canvas_item;
// C14b shared wind sway (Anim.sway_material). Vertex bend pinned at the sprite's
// base (UV.y = 1), top moves most; phase from the node's world position so
// neighbours never move in lockstep and no per-node uniform is needed (one
// shared material per strength step keeps batching). Time and wind come from
// Anim.tick() on GAME time, so sway stops while paused. Fragment = the
// sharp_pixel sampling (CrispArt) so swaying art stays as crisp as the rest.
uniform float game_t = 0.0;
uniform float wind = 0.25;      // 0..1 (Anim.wind() * reduced-motion factor)
uniform float gust = 0.0;       // 0..1 (Anim.gust())
uniform float strength = 1.0;   // per kind: trees 1.0, bushes 0.6, grass/crops 1.3, cloth 1.8
uniform float crisp = 1.0;
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float ph = wp.x * 0.11 + wp.y * 0.07;
	float k = clamp(1.0 - UV.y, 0.0, 1.0);
	k = pow(k, 1.6);
	float spd = 0.9 + wind * 0.9;
	// lean with the wind plus two out-of-step sines (never a pure metronome);
	// a gust front rolls left to right across the map.
	float front = smoothstep(0.0, 1.0, 1.0 - abs(fract(game_t * 0.05 - wp.x * 0.002) - 0.5) * 4.0);
	float g = gust * front;
	float s = sin(game_t * spd + ph) + 0.35 * sin(game_t * spd * 2.3 + ph * 1.7);
	float px = (0.6 + 1.6 * wind) * strength * (s * 0.8 + 0.5 * wind + g * 1.2);
	float sc = max(length(MODEL_MATRIX[0].xy), 0.01);
	VERTEX.x += px * k / sc;
}

void fragment() {
	vec2 ts = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * ts;
	vec2 d = max(fwidth(px), vec2(1e-5));
	vec2 seam = floor(px + 0.5);
	vec2 sharp = seam + clamp((px - seam) / d, -0.5, 0.5);
	vec2 p = mix(sharp, px, smoothstep(vec2(0.8), vec2(1.0), d));
	p = mix(px, p, crisp);
	COLOR = texture(TEXTURE, p / ts) * vcol;
}

shader_type canvas_item;
// A whole body of water drawn in one rect: the cell mask (1 texel per cell,
// linear filtered) is blurred and broken up with noise, so shorelines curve
// instead of stepping cell by cell. Moving seamless water, a foam line just
// inside the edge and a bank band just outside it.
uniform sampler2D water_tex : repeat_enable, filter_linear;
uniform sampler2D mask_tex : filter_linear;
uniform vec2 origin;          // cell of the mask's first texel
uniform vec2 grid;            // mask size in cells
uniform vec2 drift = vec2(3.0, 1.2);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 bank : source_color = vec4(0.42, 0.29, 0.17, 0.85);
uniform vec4 foam : source_color = vec4(0.88, 0.96, 1.0, 0.7);
uniform float soft = 0.07;
uniform float wobble = 0.22;
varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float mask_at(vec2 cellf) {
	return texture(mask_tex, (cellf - origin) / grid).r;
}

void fragment() {
	vec2 cellf = wpos / 16.0;
	float d = 0.33;
	float m = (mask_at(cellf + vec2(d, d)) + mask_at(cellf + vec2(-d, d)) + mask_at(cellf + vec2(d, -d)) + mask_at(cellf + vec2(-d, -d))) * 0.25;
	float n = vnoise(wpos / 24.0) * 0.67 + vnoise(wpos / 9.0) * 0.33;
	float v = m + (n - 0.5) * wobble;
	float a = smoothstep(0.5 - soft, 0.5 + soft, v);
	vec2 uv = wpos / 128.0;
	vec4 w = texture(water_tex, uv + drift * TIME / 128.0);
	vec4 w2 = texture(water_tex, uv * 1.0 + vec2(-drift.y * 1.7, drift.x * 0.6) * TIME / 128.0 + vec2(0.31, 0.55));
	vec3 col = mix(w.rgb, w2.rgb, 0.35) * tint.rgb;
	float pulse = 0.65 + 0.35 * sin(TIME * 2.0 + n * 6.0);
	float f = (smoothstep(0.46, 0.52, v) - smoothstep(0.55, 0.66, v)) * foam.a * pulse;
	col = mix(col, foam.rgb, f);
	float b = (smoothstep(0.28, 0.40, v) - smoothstep(0.47, 0.52, v)) * bank.a;
	vec4 outside = vec4(bank.rgb, b);
	COLOR = mix(outside, vec4(col, tint.a), a);
}

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
uniform float wobble = 0.3;
// Deep water toward the middle of a big body (WATER_LOOK "deep": seamless/lake_deep).
uniform sampler2D deep_tex : repeat_enable, filter_linear;
uniform float deep_amt = 0.0;
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
	// Wider, rounder blur (3x3 tent over ~1.2 cells, plus a ring at 0.75 cells),
	// so corners curve instead of following the cell grid.
	float m = 0.0;
	float wsum = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			float wgt = (i == 0 && j == 0) ? 4.0 : ((i == 0 || j == 0) ? 2.0 : 1.0);
			m += mask_at(cellf + vec2(float(i), float(j)) * 0.6) * wgt;
			wsum += wgt;
		}
	}
	float r = 0.75;
	m += (mask_at(cellf + vec2(r, 0.0)) + mask_at(cellf - vec2(r, 0.0)) + mask_at(cellf + vec2(0.0, r)) + mask_at(cellf - vec2(0.0, r))) * 1.5;
	wsum += 6.0;
	m /= wsum;
	m = max(m, mask_at(cellf) * 0.75);  // a lone or 1-wide water cell keeps its middle
	// Far from any water (most of a soft_ground/path rect): neither water nor bank can
	// reach this pixel whatever the noise, so skip the noise and water fetches.
	if (m + 0.5 * wobble < min(0.28, 0.5 - soft)) {
		discard;
	}
	float n = vnoise(wpos / 24.0) * 0.67 + vnoise(wpos / 9.0) * 0.33;
	float v = m + (n - 0.5) * wobble;
	float a = smoothstep(0.5 - soft, 0.5 + soft, v);
	vec2 uv = wpos / 128.0;
	vec4 w = texture(water_tex, uv + drift * TIME / 128.0);
	vec4 w2 = texture(water_tex, uv * 1.0 + vec2(-drift.y * 1.7, drift.x * 0.6) * TIME / 128.0 + vec2(0.31, 0.55));
	vec3 col = mix(w.rgb, w2.rgb, 0.35) * tint.rgb;
	if (deep_amt > 0.0) {
		float md = (mask_at(cellf + vec2(2.5, 0.0)) + mask_at(cellf - vec2(2.5, 0.0)) + mask_at(cellf + vec2(0.0, 2.5)) + mask_at(cellf - vec2(0.0, 2.5))) * 0.25;
		col = mix(col, texture(deep_tex, uv + drift * TIME / 160.0).rgb * tint.rgb, smoothstep(0.85, 1.0, md) * deep_amt);
	}
	float pulse = 0.65 + 0.35 * sin(TIME * 2.0 + n * 6.0);
	float f = (smoothstep(0.46, 0.52, v) - smoothstep(0.55, 0.66, v)) * foam.a * pulse;
	col = mix(col, foam.rgb, f);
	float b = (smoothstep(0.28, 0.40, v) - smoothstep(0.47, 0.52, v)) * bank.a;
	vec4 outside = vec4(bank.rgb, b);
	COLOR = mix(outside, vec4(col, tint.a), a);
}

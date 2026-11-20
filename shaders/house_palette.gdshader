shader_type canvas_item;
// Farmhouse exterior styles (C10b P3): sharp-pixel sampling (as sharp_pixel.gdshader,
// so CrispArt's look is kept) + a palette swap per part. `parts` is the day picture's
// part mask (R = id * 32: 1 roof, 2 wood trim, 3 glass, 4 stonework, 5 broad wall
// planks; ramps recolour 2+5, wall textures only 5), sampled in UV
// space so it also fits the slightly scaled _night/_snow pictures. A part with
// use_N recolours by luminance onto its 5-stop ramp (dark -> light), keeping the
// painted shading; each part has a colour gate so snow, lit windows and outlines
// that drifted into a part's box are left alone.
uniform sampler2D parts : filter_nearest;
uniform bool crisp = true;
uniform bool use1 = false;
uniform bool use2 = false;
uniform bool use3 = false;
uniform bool use4 = false;
uniform vec3 ramp1[5];
uniform vec3 ramp2[5];
uniform vec3 ramp3[5];
uniform vec3 ramp4[5];
uniform vec2 lum1 = vec2(0.1, 0.6);
uniform vec2 lum2 = vec2(0.15, 0.7);
uniform vec2 lum3 = vec2(0.1, 0.7);
uniform vec2 lum4 = vec2(0.25, 0.9);
// Material siding (brick, fieldstone, logs): a seamless wall texture tiled in the
// picture's texel space, lit by the painted planks' light (half strength, so the
// plank stripes don't fight the pattern).
uniform bool use_wall = false;
uniform sampler2D wall : filter_nearest, repeat_enable;
uniform float wall_px = 64.0;
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

vec3 ramp_at(vec3 r[5], float t) {
	float x = clamp(t, 0.0, 1.0) * 4.0;
	int i = int(min(floor(x), 3.0));
	return mix(r[i], r[i + 1], x - float(i));
}

void fragment() {
	vec2 ts = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * ts;
	vec2 p = px;
	if (crisp) {
		vec2 d = max(fwidth(px), vec2(1e-5));
		vec2 seam = floor(px + 0.5);
		vec2 sharp = seam + clamp((px - seam) / d, -0.5, 0.5);
		p = mix(sharp, px, smoothstep(vec2(0.8), vec2(1.0), d));
	}
	vec4 c = texture(TEXTURE, p / ts);
	int id = int(texture(parts, UV).r * 255.0 / 32.0 + 0.5);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	bool warm = c.r > c.b + 0.06 && sat > 0.22;
	if (id == 1 && use1 && warm) {
		c.rgb = ramp_at(ramp1, (l - lum1.x) / max(lum1.y - lum1.x, 0.01));
	} else if (id == 5 && use_wall && warm) {
		float mid = (lum2.x + lum2.y) * 0.5;
		float sh = clamp(mix(1.0, l / max(mid, 0.05), 0.5), 0.35, 1.3);
		c.rgb = texture(wall, floor(p) / wall_px).rgb * sh;
	} else if ((id == 2 || id == 5) && use2 && warm) {
		c.rgb = ramp_at(ramp2, (l - lum2.x) / max(lum2.y - lum2.x, 0.01));
	} else if (id == 3 && use3 && c.b > c.r) {
		c.rgb = ramp_at(ramp3, (l - lum3.x) / max(lum3.y - lum3.x, 0.01));
	} else if (id == 4 && use4 && l < 0.93 && !(c.b > c.r + 0.08)) {
		c.rgb = ramp_at(ramp4, (l - lum4.x) / max(lum4.y - lum4.x, 0.01));
	}
	COLOR = c * vcol;
}

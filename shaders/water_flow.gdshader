shader_type canvas_item;
// C14b P2: living water on a STILL water-feature picture (WaterFeature).
// The fountain art is one frame (no more re-drawn frames popping); only the
// water pixels move: falling sheets carry highlight streaks downward, pools
// ripple outward from their centre and glint now and then. Continuous, so it
// is smooth at any frame rate. `t` is game time (PlayClock) wrapped at
// WaterFeature.LOOP; every frequency here is a multiple of 1/LOOP Hz, so the
// wrap is invisible (seamless). Sampling matches sharp_pixel.gdshader (crisp
// when the phone magnifies the 2x art).
uniform float t = 0.0;
uniform vec4 cell = vec4(0.0, 0.0, 1.0, 1.0);   // the frame's rect in UV (x, y, w, h)
uniform float fall_top = 0.26;                   // local y where falling water starts
uniform float fall_bottom = 0.55;                // ... and where the basin begins
uniform vec2 basin = vec2(0.5, 0.63);            // basin centre (local)
uniform vec2 bowl = vec2(0.5, 0.18);             // upper bowl centre (local)
uniform float phase = 0.0;                       // extra offset, 0..1 (the world-position phase is added)
uniform float amp = 1.0;                         // 1 normal, ~0.3 reduced motion
varying vec4 vcol;
varying float wph;  // per-fountain phase from its world position (one shared material per look)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vcol = COLOR;
	wph = hash(floor(MODEL_MATRIX[3].xy));
}

void fragment() {
	vec2 ts = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * ts;
	vec2 d = max(fwidth(px), vec2(1e-5));
	vec2 seam = floor(px + 0.5);
	vec2 sharp = seam + clamp((px - seam) / d, -0.5, 0.5);
	vec2 p = mix(sharp, px, smoothstep(vec2(0.8), vec2(1.0), d));
	vec4 col = texture(TEXTURE, p / ts);
	vec2 lc = (UV - cell.xy) / cell.zw;
	vec2 tx = floor(lc * cell.zw * ts);            // texel within the frame
	float h = cell.w * ts.y;                         // frame height in texels
	// water = clearly blue pixels (stone, leaves and flowers stay untouched)
	float w = smoothstep(0.10, 0.28, col.b - col.r) * col.a;
	float tt = t + fract(phase + wph) * 60.0;
	float lift = 0.0;
	if (lc.y > fall_top && lc.y < fall_bottom) {
		// falling sheets: bright bands slide down each 2-texel column at its own pace
		float cid = floor(tx.x / 2.0);
		float ph = hash(vec2(cid, 3.0));
		float v = fract(tx.y / 9.0 - tt * (1.5 + floor(ph * 2.0) * 0.5) + ph);
		lift = smoothstep(0.70, 0.95, v) * 0.32 - smoothstep(0.0, 0.35, v) * (1.0 - smoothstep(0.35, 0.6, v)) * 0.10;
	} else {
		vec2 c = lc.y <= fall_top ? bowl : basin;
		float r = length((lc - c) * vec2(1.0, 2.3)) * h;
		// two ripple trains, 0.5 Hz and 0.3 Hz
		float rip = sin(r * 0.55 - tt * 6.2831853 * 0.5) * 0.6 + sin(r * 0.9 - tt * 6.2831853 * 0.3 + 1.7) * 0.4;
		lift = smoothstep(0.55, 1.0, rip) * 0.16 - smoothstep(0.4, 1.0, -rip) * 0.05;
		// rare soft glints, each texel at its own phase (0.4 Hz)
		float g = hash(tx + vec2(7.0, 1.0));
		float tw = pow(max(0.0, sin(tt * 6.2831853 * 0.4 + g * 40.0)), 24.0) * step(0.86, g);
		lift += tw * 0.45;
	}
	col.rgb = mix(col.rgb, col.rgb + vec3(lift * 0.85, lift * 0.95, lift), w * amp);
	COLOR = col * vcol;
}

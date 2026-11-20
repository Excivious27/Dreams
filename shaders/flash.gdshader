shader_type canvas_item;
// White hit-flash for sprites: flash 0 = normal, 1 = solid white silhouette.
// Samples like sharp_pixel.gdshader (CrispArt), so the hero and foes stay as
// crisp as the buildings when the phone magnifies (c5_05 #4); 1:1 is bilinear.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform bool crisp = true;
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec2 ts = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * ts;
	vec2 d = max(fwidth(px), vec2(1e-5));
	vec2 seam = floor(px + 0.5);
	vec2 sharp = seam + clamp((px - seam) / d, -0.5, 0.5);
	vec2 p = crisp ? mix(sharp, px, smoothstep(vec2(0.8), vec2(1.0), d)) : px;
	vec4 c = texture(TEXTURE, p / ts) * vcol;
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}

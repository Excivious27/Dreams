shader_type canvas_item;
// Sharp-pixel sampling for 2x-detail art (CrispArt). When a texture is magnified
// (phones draw the 270x480 canvas at 3-4x), plain LINEAR smears every texel into
// its neighbours; here each texel stays a solid block and only the last screen
// pixel at a texel seam is blended. Minified/1:1 draws (desktop 540x960 window)
// keep ordinary bilinear. Needs the node's filter to be LINEAR (GameMap default).
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
	vec2 p = mix(sharp, px, step(vec2(0.9), d));
	COLOR = texture(TEXTURE, p / ts) * vcol;
}

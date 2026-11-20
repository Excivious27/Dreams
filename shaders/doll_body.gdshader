shader_type canvas_item;
// Paper-doll body (C10a P5): flash.gdshader plus skin tone. skin_mask is the sheet's
// body/<sheet>_skin.png (same size, so the same UV); masked pixels are recoloured to
// `tone` keeping their shading (luma relative to the painted tan). White hit-flash as flash.gdshader.
// Samples like sharp_pixel.gdshader (CrispArt), so the hero and foes stay as
// crisp as the buildings when the phone magnifies (c5_05 #4); 1:1 is bilinear.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform bool crisp = true;
uniform sampler2D skin_mask : filter_nearest;
uniform bool skin_on = false;
uniform vec3 tone = vec3(1.0, 0.84, 0.72);
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
	if (skin_on) {
		float m = texture(skin_mask, UV).a;
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = mix(c.rgb, clamp(tone * (l / 0.6), 0.0, 1.0), m);
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}

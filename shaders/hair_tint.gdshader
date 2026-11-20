shader_type canvas_item;
// Hair colour: the hair art is brown, so a plain modulate (multiply) can't make
// it silver, blonde or blue. This keeps the shading (luma) and recolours it.
// COLOR arrives as texture x modulate, so the modulate's alpha (hat fade) still applies.
// flash: hit flash in step with the body's flash.gdshader (Player._update_doll sets it).
uniform vec4 tint : source_color = vec4(1.0);
uniform bool on = false;
uniform float flash = 0.0;

void fragment() {
	vec4 c = COLOR;
	if (on) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = clamp(tint.rgb * l * 1.9, 0.0, 1.0);
	}
	c.rgb = mix(c.rgb, vec3(1.0), clamp(flash, 0.0, 1.0));
	COLOR = c;
}

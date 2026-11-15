// full-screen finishing touches: colour grade, soft vignette, and a cold look in slow-mo.
// done as a multiply over the picture (blend_mul), so it never has to copy the screen: copying
// the screen every frame was one of the most expensive things in the game, especially on the web.
shader_type canvas_item;
render_mode blend_mul;

uniform vec4 grade : source_color = vec4(1.0);
uniform float vignette = 0.2;
uniform float slowmo = 0.0;

void fragment() {
	vec3 tint = grade.rgb;
	// slow-mo: mix towards a bluer version of the normal tint.
	vec3 cold_tint = tint * vec3(0.8, 0.92, 1.15);
	float cold_amount = slowmo * 0.55;
	tint = mix(tint, cold_tint, cold_amount);
	// slightly darker corners.
	vec2 from_centre = UV - 0.5;
	float corner = length(from_centre * vec2(1.25, 1.0));
	float edge_fade = smoothstep(0.45, 0.95, corner);
	float darkness = vignette + slowmo * 0.25;
	tint *= 1.0 - edge_fade * darkness;
	COLOR = vec4(tint, 1.0);
}

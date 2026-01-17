shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Fin shader for shell fur system
// Optimized for single-card rendering to fill side-view gaps

// ===== BASIC FUR PARAMETERS =====

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fur_length : hint_range(0.0, 5.0) = 0.5;
uniform float alpha_boost : hint_range(0.5, 2.0) = 1.2;

// ===== FUR PATTERN =====

uniform sampler2D heightmap : hint_default_white;
uniform sampler2D turbulence_map : hint_default_white;
uniform float density : hint_range(0.0, 100.0) = 10.0;
uniform float thickness : hint_range(0.0, 5.0, 0.01) = 0.4;
uniform float scruffiness : hint_range(0.0, 1.0) = 0.35;

// ===== TEXTURE ATLAS =====

uniform bool use_texture_atlas = false;
uniform sampler2D texture_atlas : hint_default_white;
// Atlas layout: R=heightmap, G=turbulence, B=jitter, A=pattern

// ===== WIND AND MOVEMENT =====

uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.0;
uniform float wind_speed : hint_range(0.0, 10.0) = 1.0;

// ===== PHYSICS =====

uniform vec3 physics_pos_offset = vec3(0.0);
uniform mat3 physics_rot_offset = mat3(
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
);

// ===== LIGHTING =====

uniform float ambient_occlusion : hint_range(0.0, 1.0) = 0.3;
uniform float rim_light : hint_range(0.0, 2.0) = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ===== NOISE FUNCTIONS =====

// Gold Noise - fast pseudo-random
float gold_noise(vec2 xy, float seed) {
	return fract(tan(distance(xy * 1.61803398874989484820459, xy) * seed) * xy.x);
}

// Smooth noise
float smooth_noise(vec2 uv, float seed) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);

	float a = gold_noise(i, seed);
	float b = gold_noise(i + vec2(1.0, 0.0), seed);
	float c = gold_noise(i + vec2(0.0, 1.0), seed);
	float d = gold_noise(i + vec2(1.0, 1.0), seed);

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	// Apply physics offset
	VERTEX += physics_pos_offset * UV.y;  // More effect at tip

	// Apply physics rotation
	vec3 local_pos = VERTEX - vec3(0.0, 0.0, 0.0);
	local_pos = physics_rot_offset * local_pos;
	VERTEX = local_pos;

	// Apply wind (more effect at tip)
	float wind_effect = sin(TIME * wind_speed + VERTEX.x + VERTEX.z) * wind_strength;
	VERTEX += wind_direction * wind_effect * UV.y;
}

void fragment() {
	vec2 uv = UV;

	// Sample textures
	float strand_height;
	float turbulence_val;

	if (use_texture_atlas) {
		vec4 atlas_sample = texture(texture_atlas, uv);
		strand_height = atlas_sample.r;
		turbulence_val = atlas_sample.g;
	} else {
		strand_height = texture(heightmap, uv).r;
		turbulence_val = texture(turbulence_map, uv).r;
	}

	// Generate fur pattern
	float noise_val = gold_noise(uv * density, 1234.5);

	// Add scruffiness variation
	float scruffy = smooth_noise(uv * density * 0.3, 5678.9) * scruffiness;
	strand_height = clamp(strand_height + scruffy - scruffiness * 0.5, 0.0, 1.0);

	// Height threshold - fins represent mid-level fur
	float h = 0.5;  // Fins are at 50% fur height
	float threshold = strand_height * (1.0 - h);

	// Calculate alpha based on fur density pattern
	float alpha = 0.0;

	// Strand pattern
	if (noise_val > threshold) {
		// Calculate strand thickness
		float dist_to_strand = abs(noise_val - threshold - thickness * 0.5) / (thickness * 0.5);
		dist_to_strand = clamp(dist_to_strand, 0.0, 1.0);

		// Smooth falloff
		alpha = 1.0 - dist_to_strand;
		alpha = smoothstep(0.0, 1.0, alpha);

		// Boost alpha for fins
		alpha *= alpha_boost;
	}

	// Height gradient - fade towards tips
	alpha *= 1.0 - (UV.y * 0.3);  // Slight fade at tip

	// Apply turbulence for variation
	alpha *= mix(0.8, 1.0, turbulence_val);

	// Set albedo
	ALBEDO = color.rgb;
	ALPHA = alpha * color.a;

	// Ambient occlusion - darker near base
	float ao = mix(1.0 - ambient_occlusion, 1.0, UV.y);
	ALBEDO *= ao;

	// Rim lighting for better visibility
	float NdotV = dot(NORMAL, VIEW);
	float rim = pow(1.0 - abs(NdotV), rim_light);
	ALBEDO += rim_color.rgb * rim * rim_color.a;

	// Discard fully transparent pixels
	if (ALPHA < 0.01) {
		discard;
	}
}

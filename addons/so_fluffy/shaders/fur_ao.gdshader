// Ambient Occlusion Shader for Shell Fur
// Calculates self-shadowing based on shell depth and density
// Minimal performance impact - uses simple depth-based approximation

shader_type spatial;
render_mode cull_disabled;

// Include all parameters from outer shader
// Core parameters
uniform float height = 0.0;
uniform float normal_strength = 1.0;
uniform vec3 static_direction_local = vec3(0.0, 0.0, 0.0);
uniform vec3 static_direction_world = vec3(0.0, 0.0, 0.0);
uniform float h = 0.0;
uniform float density = 1.0;
uniform bool render_skin = true;
uniform int seed = 0;
uniform float scruffiness = 0.5;

// Texture atlas
uniform sampler2D texture_atlas : source_color, filter_linear;
uniform bool use_texture_atlas = false;

// Individual textures (fallback)
uniform sampler2D heightmap_texture : source_color, filter_nearest;
uniform bool use_heightmap_texture = false;
uniform sampler2D turbulence_texture : filter_linear;
uniform sampler2D jitter_texture : filter_linear;

uniform float turbulence_strength = 0.5;
uniform float jitter_strength = 0.0;

// Curls
uniform bool curls_enabled = true;
uniform float curls_twist = 24.0;
uniform float curls_fill = 0.7853981634;

// Thickness
uniform sampler2D thickness_curve;
uniform bool use_thickness_curve = false;
uniform float thickness_scale = 1.0;

// Appearance
uniform vec3 color : source_color;
uniform sampler2D height_gradient : source_color, filter_nearest;
uniform bool use_height_gradient = false;
uniform bool scale_height_gradient = true;
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture : source_color;

// Emission
uniform bool use_emission = false;
uniform vec3 emission_color : source_color;
uniform float emission_energy_multiplier = 1.0;
uniform bool use_emission_texture = false;
uniform sampler2D emission_texture : source_color;

// Physics
uniform vec3 physics_pos_offset = vec3(0.0, 0.0, 0.0);
uniform mat3 physics_rot_offset;

// ===== AMBIENT OCCLUSION PARAMETERS =====

uniform bool ao_enabled = true;
uniform float ao_strength = 0.7;  // How much AO darkens the fur
uniform float ao_density_influence = 0.5;  // How much density affects AO
uniform float ao_depth_falloff = 2.0;  // Exponential falloff (higher = darker at base)
uniform vec3 ao_color : source_color = vec3(0.3, 0.25, 0.2);  // Tint for shadowed areas

// Multi-sample AO (higher quality but more expensive)
uniform bool ao_multi_sample = false;
uniform int ao_samples = 4;  // Number of samples for AO calculation
uniform float ao_sample_radius = 0.05;  // Sampling radius in UV space

// Self-shadowing from above shells
uniform bool self_shadow_enabled = false;
uniform float self_shadow_strength = 0.5;
uniform float self_shadow_falloff = 3.0;

// Gold Noise
float gold_noise(vec2 p) {
	p = p + vec2(float(seed), float(seed));
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Fast atan2 approximation
float atan2_approximation2(float x, float y) {
	if (x == 0.0) {
		if (y > 0.0) return PI / 2.0;
		if (y == 0.0) return 0.0;
		return -PI / 2.0;
	}
	float atan_val;
	float z = y / x;
	if (abs(z) < 1.0) {
		atan_val = z / (1.0 + 0.28 * z * z);
		if (x < 0.0) {
			if (y < 0.0) return atan_val - PI;
			return atan_val + PI;
		}
	} else {
		atan_val = PI / 2.0 - z / (z * z + 0.28);
		if (y < 0.0) return atan_val - PI;
	}
	return atan_val;
}

// Calculate ambient occlusion factor
float calculate_ao(vec2 uv, float shell_h, float strand_density) {
	if (!ao_enabled) {
		return 1.0;
	}

	// Basic depth-based AO
	// Inner shells (h closer to 0) are more occluded
	float depth_ao = pow(shell_h, ao_depth_falloff);

	// Density influence - denser fur = more occlusion
	float density_factor = mix(1.0, 1.0 - strand_density * 0.3, ao_density_influence);

	// Multi-sample AO (optional, more expensive)
	float sample_ao = 1.0;
	if (ao_multi_sample) {
		float ao_sum = 0.0;
		float golden_angle = 2.399963; // Golden angle in radians

		for (int i = 0; i < ao_samples; i++) {
			float angle = float(i) * golden_angle;
			float radius = ao_sample_radius * sqrt(float(i) / float(ao_samples));

			vec2 offset = vec2(cos(angle), sin(angle)) * radius;
			vec2 sample_uv = uv + offset;

			// Sample heightmap to check occlusion
			float sample_height = 1.0;
			if (use_heightmap_texture) {
				if (use_texture_atlas) {
					sample_height = texture(texture_atlas, sample_uv).r;
				} else {
					sample_height = texture(heightmap_texture, sample_uv).r;
				}
			}

			// If there's fur above us, we're more occluded
			if (sample_height > shell_h) {
				ao_sum += (sample_height - shell_h) * 0.5;
			}
		}

		sample_ao = 1.0 - clamp(ao_sum / float(ao_samples), 0.0, 0.5);
	}

	// Self-shadowing from shells above
	float shadow_ao = 1.0;
	if (self_shadow_enabled) {
		// Simple approximation: shells closer to the surface receive less light
		shadow_ao = mix(
			pow(shell_h, self_shadow_falloff),
			1.0,
			1.0 - self_shadow_strength
		);
	}

	// Combine all AO factors
	float final_ao = depth_ao * density_factor * sample_ao * shadow_ao;

	// Apply AO strength
	return mix(1.0, final_ao, ao_strength);
}

void vertex() {
	// Physics offset in world space
	vec3 physics_pos_offset_world = (vec4(physics_pos_offset, 0.0) * MODEL_MATRIX).xyz * h * 0.2;

	// Growth direction blend
	vec3 direction = static_direction_local + (vec4(static_direction_world, 0.0) * MODEL_MATRIX).xyz;

	// Displace vertex
	VERTEX += (NORMAL * normal_strength + direction * (1.0 - normal_strength)) * height * h + physics_pos_offset_world;
	VERTEX = VERTEX * physics_rot_offset;
}

void fragment() {
	vec2 uv = UV * density;
	vec2 xy = uv;

	// Turbulence displacement
	if (turbulence_strength > 0.0) {
		vec2 turbulence;

		if (use_texture_atlas) {
			turbulence = texture(texture_atlas, uv).gg - vec2(0.5, 0.5);
		} else {
			turbulence = texture(turbulence_texture, uv).xy - vec2(0.5, 0.5);
		}

		vec2 displacement = turbulence * turbulence_strength * 0.1;
		xy = xy + displacement * pow((1.0 - h * 0.5), 1.0 * turbulence_strength) * 1.0;
	}

	// Jitter
	if (jitter_strength > 0.0) {
		vec2 jitter;

		if (use_texture_atlas) {
			jitter = texture(texture_atlas, UV).bb - vec2(0.5, 0.5);
		} else {
			jitter = texture(jitter_texture, UV).xy - vec2(0.5, 0.5);
		}

		xy = xy + jitter * jitter_strength / 200.0;
	}

	// Strand length variation
	float noise = 0.0;
	if (scruffiness > 0.0 || curls_enabled) {
		noise = gold_noise(floor(xy * 1024.0));
	}
	float len = scruffiness <= 0.0 ? 1.0 : pow(noise, scruffiness);

	// Heightmap
	if (use_heightmap_texture) {
		float heightmap_val;

		if (use_texture_atlas) {
			heightmap_val = texture(texture_atlas, UV).r;
		} else {
			heightmap_val = texture(heightmap_texture, UV).r;
		}

		len *= heightmap_val;
	}

	// Distance from strand center
	float ts = 1024.0;
	vec2 center_offset = fract(xy * ts) - vec2(0.5, 0.5);
	float relDist = length(center_offset) / thickness_scale * 2.0;

	// Thickness
	float thickness;
	if (use_thickness_curve) {
		thickness = texture(thickness_curve, vec2(clamp(h / len, 0.0, 0.99), 0.0)).r * len;
	} else {
		thickness = h;
	}

	// Curls calculation
	bool curl = true;
	if (curls_enabled) {
		float a = mod(atan2_approximation2(center_offset.y, center_offset.x) + h * curls_twist + noise * 1024.0, 2.0 * PI);
		curl = a > 0.0 && a < curls_fill;
	}

	// Render strand
	if (curl && (len - thickness >= relDist && h < len || (render_skin && h == 0.0))) {
		if (!FRONT_FACING) NORMAL = -NORMAL;

		vec3 col = color;

		// Height gradient
		float grad_h = h;
		if (scale_height_gradient) {
			grad_h /= len;
		}

		vec3 height_col;
		if (use_height_gradient) {
			height_col = texture(height_gradient, vec2(grad_h * 0.999, 0.0)).rgb;
		} else {
			float hg = pow(h, 0.9);
			height_col = vec3(hg, hg, hg);
		}
		col *= height_col;

		// Albedo texture
		if (use_albedo_texture) {
			col *= texture(albedo_texture, UV).rgb;
		}

		// ===== AMBIENT OCCLUSION =====
		float ao_factor = calculate_ao(UV, h, density);

		// Apply AO to color
		col = mix(col * ao_color, col, ao_factor);

		ALBEDO = col;

		// Emission (reduced by AO for realism)
		if (use_emission) {
			vec3 emission = emission_color;
			if (use_emission_texture) {
				emission += texture(emission_texture, UV).rgb;
			}
			EMISSION = emission * emission_energy_multiplier * ao_factor;
		}

		// Apply AO to roughness for more realistic look
		// (occluded areas appear slightly rougher)
		ROUGHNESS = mix(0.8, 1.0, ao_factor);

	} else {
		discard;
	}
}

void light() {
	// Enhanced lighting with AO consideration
	// Half-Lambert for softer lighting
	float d = dot(NORMAL, LIGHT) / 2.0 + 0.5;

	// AO affects diffuse lighting
	DIFFUSE_LIGHT += d * d * ATTENUATION * LIGHT_COLOR;
}
